import 'enums.dart';

String? _nestedUserName(Map<String, dynamic> map) {
  for (final key in ['users', 'profiles']) {
    final nested = map[key];
    if (nested is Map<String, dynamic>) {
      return nested['name'] as String?;
    }
  }
  return null;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.at,
    this.lat,
    this.lng,
    this.userName,
  });

  final String id;
  final String userId;
  final AttendanceType type;
  final DateTime at;
  final double? lat;
  final double? lng;
  final String? userName;

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    String? userName = _nestedUserName(map);
    return AttendanceRecord(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: AttendanceTypeX.fromDb(map['type'] as String?),
      at: DateTime.tryParse('${map['at']}') ?? DateTime.now(),
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      userName: userName,
    );
  }
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.dayType,
    this.reason,
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.userName,
  });

  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveDayType dayType;
  final String? reason;
  final LeaveStatus status;
  final String? adminNote;
  final DateTime createdAt;
  final String? userName;

  int get dayCount => endDate.difference(startDate).inDays + 1;

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    String? userName = _nestedUserName(map);
    return LeaveRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      startDate: DateTime.parse(map['start_date'].toString()),
      endDate: DateTime.parse(map['end_date'].toString()),
      dayType: LeaveDayTypeX.fromDb(map['day_type'] as String?),
      reason: map['reason'] as String?,
      status: LeaveStatusX.fromDb(map['status'] as String?),
      adminNote: map['admin_note'] as String?,
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
      userName: userName,
    );
  }
}

class LocationPing {
  const LocationPing({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    this.accuracy,
    required this.recordedAt,
    required this.context,
    this.jobId,
    this.userName,
  });

  final String id;
  final String userId;
  final double lat;
  final double lng;
  final double? accuracy;
  final DateTime recordedAt;
  final String context;
  final String? jobId;
  final String? userName;

  factory LocationPing.fromMap(Map<String, dynamic> map) {
    String? userName = _nestedUserName(map);
    return LocationPing(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      recordedAt: DateTime.tryParse('${map['recorded_at']}') ?? DateTime.now(),
      context: (map['context'] as String?) ?? 'standby',
      jobId: map['job_id'] as String?,
      userName: userName,
    );
  }
}
