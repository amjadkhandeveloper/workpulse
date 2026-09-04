import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/constants/app_constants.dart';
import '../data/models/company.dart';
import '../data/models/enums.dart';
import '../data/models/job.dart';
import '../data/models/profile.dart';
import '../data/models/records.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/company_repository.dart';
import '../data/repositories/job_repository.dart';
import '../data/repositories/ops_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/supabase/app_config.dart';
import '../services/location_service.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());
final profileRepositoryProvider = Provider((ref) => ProfileRepository());
final companyRepositoryProvider = Provider((ref) => CompanyRepository());
final jobRepositoryProvider = Provider((ref) => JobRepository());
final attendanceRepositoryProvider = Provider((ref) => AttendanceRepository());
final leaveRepositoryProvider = Provider((ref) => LeaveRepository());
final locationRepositoryProvider = Provider((ref) => LocationRepository());

final locationServiceProvider = Provider(
  (ref) => LocationService(ref.watch(locationRepositoryProvider)),
);

enum SessionStatus { loading, misconfigured, needsIntro, unauthenticated, authenticated }

class SessionState {
  const SessionState({
    required this.status,
    this.profile,
    this.error,
  });

  final SessionStatus status;
  final Profile? profile;
  final String? error;

  bool get isAdmin => profile?.isAdmin == true;
  bool get isClient => profile?.isClient == true;
  bool get isManager => profile?.isManager == true;
  String? get tenantClientId => isClient ? profile?.orgId : null;
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._auth, this._profiles, this._location)
      : super(const SessionState(status: SessionStatus.loading)) {
    _init();
  }

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final LocationService _location;

  Future<void> _init() async {
    if (!AppConfig.isConfigured) {
      state = const SessionState(status: SessionStatus.misconfigured);
      return;
    }
    _auth.authChanges().listen((event) {
      if (event.event == sb.AuthChangeEvent.signedOut) {
        _location.stop();
        _goUnauthenticated();
      } else if (event.session != null) {
        _loadProfile(event.session!.user.id);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final introSeen = prefs.getBool(AppConstants.introSeenKey) ?? false;
    final session = _auth.currentSession;
    if (session == null) {
      state = SessionState(
        status: introSeen ? SessionStatus.unauthenticated : SessionStatus.needsIntro,
      );
      return;
    }
    await _loadProfile(session.user.id);
  }

  Future<void> completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.introSeenKey, true);
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signIn(email, password);
    final user = _auth.currentUser;
    if (user != null) {
      await _loadProfile(user.id);
    }
  }

  Future<void> signOut() async {
    await _location.stop();
    await _auth.signOut();
    await _goUnauthenticated();
  }

  Future<void> refreshProfile() async {
    final id = _auth.currentUser?.id;
    if (id != null) await _loadProfile(id);
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final profile = await _profiles.getById(userId);
      if (profile == null) {
        state = const SessionState(
          status: SessionStatus.unauthenticated,
          error: 'Profile not found. Apply the database schema and try again.',
        );
        return;
      }
      state = SessionState(status: SessionStatus.authenticated, profile: profile);
      if (profile.isOnStandby || profile.role == UserRole.user) {
        // Tracking is started explicitly on standby/job; keep existing stream if any.
      }
    } catch (error) {
      state = SessionState(
        status: SessionStatus.unauthenticated,
        error: error.toString(),
      );
    }
  }

  Future<void> _goUnauthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final introSeen = prefs.getBool(AppConstants.introSeenKey) ?? false;
    state = SessionState(
      status: introSeen ? SessionStatus.unauthenticated : SessionStatus.needsIntro,
    );
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(
    ref.watch(authRepositoryProvider),
    ref.watch(profileRepositoryProvider),
    ref.watch(locationServiceProvider),
  );
});

final companiesProvider = FutureProvider<List<Company>>((ref) {
  final clientId = ref.watch(sessionControllerProvider).tenantClientId;
  return ref.watch(companyRepositoryProvider).list(clientId: clientId);
});

final fieldUsersProvider = FutureProvider<List<Profile>>((ref) {
  final clientId = ref.watch(sessionControllerProvider).tenantClientId;
  return ref.watch(profileRepositoryProvider).listUsers(clientId: clientId);
});

final clientsProvider = FutureProvider<List<Profile>>((ref) {
  return ref.watch(profileRepositoryProvider).listClients();
});

final adminJobsProvider = FutureProvider<List<Job>>((ref) {
  final clientId = ref.watch(sessionControllerProvider).tenantClientId;
  return ref.watch(jobRepositoryProvider).listAll(clientId: clientId);
});

final adminLeavesProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  final users = await ref.watch(fieldUsersProvider.future);
  final clientId = ref.watch(sessionControllerProvider).tenantClientId;
  return ref.watch(leaveRepositoryProvider).listAll(
        userIds: clientId == null ? null : users.map((u) => u.id).toSet(),
      );
});

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final clientId = ref.watch(sessionControllerProvider).tenantClientId;
  return ref.watch(profileRepositoryProvider).dashboardStats(clientId: clientId);
});

final liveUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final clientId = ref.watch(sessionControllerProvider).tenantClientId;
  return ref.watch(locationRepositoryProvider).latestByUser(clientId: clientId);
});

final userJobsProvider = StreamProvider<List<Job>>((ref) {
  final profile = ref.watch(sessionControllerProvider).profile;
  if (profile == null) return const Stream.empty();
  return ref.watch(jobRepositoryProvider).watchForUser(profile.id);
});

final userAttendanceProvider = FutureProvider<List<AttendanceRecord>>((ref) {
  final profile = ref.watch(sessionControllerProvider).profile;
  if (profile == null) return [];
  return ref.watch(attendanceRepositoryProvider).listForUser(profile.id);
});

final userLeavesProvider = FutureProvider<List<LeaveRequest>>((ref) {
  final profile = ref.watch(sessionControllerProvider).profile;
  if (profile == null) return [];
  return ref.watch(leaveRepositoryProvider).listForUser(profile.id);
});
