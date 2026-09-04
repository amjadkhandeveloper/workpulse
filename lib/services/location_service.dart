import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_constants.dart';
import '../data/models/enums.dart';
import '../data/models/job.dart';
import '../data/models/profile.dart';
import '../data/repositories/ops_repository.dart';

class LocationFix {
  const LocationFix({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.address,
  });

  final double lat;
  final double lng;
  final double? accuracy;
  final String? address;
}

class LocationService {
  LocationService(this._locations);

  final LocationRepository _locations;

  StreamSubscription<Position>? _sub;
  String? _userId;
  String _context = 'standby';
  String? _jobId;
  DateTime? _lastPingAt;

  bool get isTracking => _sub != null;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    if (Platform.isAndroid) {
      await Permission.locationWhenInUse.request();
      await Permission.notification.request();
    }
    return true;
  }

  Future<LocationFix?> currentFix() async {
    final ok = await ensurePermission();
    if (!ok) return null;
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    final position = await Geolocator.getCurrentPosition();
    String? address;
    try {
      final marks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        address = [
          m.street,
          m.subLocality,
          m.locality,
          m.administrativeArea,
          m.postalCode,
          m.country,
        ].where((e) => e != null && e.trim().isNotEmpty).join(', ');
      }
    } catch (_) {}
    return LocationFix(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      address: address,
    );
  }

  Future<void> start({
    required String userId,
    required String context,
    String? jobId,
  }) async {
    final ok = await ensurePermission();
    if (!ok) return;
    _userId = userId;
    _context = context;
    _jobId = jobId;
    await _sub?.cancel();

    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25,
            intervalDuration: AppConstants.locationPingInterval,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Work Pulse',
              notificationText: 'Sharing your live location',
              enableWakeLock: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.otherNavigation,
            distanceFilter: 25,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
    try {
      final first = await Geolocator.getCurrentPosition();
      await _onPosition(first);
    } catch (_) {}
  }

  Future<void> sync({required Profile profile, List<Job> jobs = const []}) async {
    final active = jobs.where((job) => job.status.isActive).firstOrNull;
    if (active != null) {
      if (isTracking && _userId == profile.id && _context == 'job' && _jobId == active.id) {
        return;
      }
      await start(userId: profile.id, context: 'job', jobId: active.id);
      return;
    }
    if (profile.isOnStandby) {
      if (isTracking && _userId == profile.id && _context == 'standby') return;
      await start(userId: profile.id, context: 'standby');
      return;
    }
    await stop();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _userId = null;
    _jobId = null;
  }

  Future<void> _onPosition(Position position) async {
    final userId = _userId;
    if (userId == null) return;
    final now = DateTime.now();
    if (_lastPingAt != null &&
        now.difference(_lastPingAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastPingAt = now;
    try {
      await _locations.updateLive(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        context: _context,
        jobId: _jobId,
      );
    } catch (error, stack) {
      debugPrint('Location ping failed: $error\n$stack');
    }
  }
}
