import 'enums.dart';

class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.name,
    this.mobile,
    this.photoUrl,
    this.username,
    required this.role,
    this.clientId,
    required this.isActive,
    required this.standbyStatus,
    this.lastLat,
    this.lastLng,
    this.lastLocationAt,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String? mobile;
  final String? photoUrl;
  final String? username;
  final UserRole role;
  final String? clientId;
  final bool isActive;
  final StandbyStatus standbyStatus;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastLocationAt;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isClient => role == UserRole.client;
  bool get isManager => isAdmin || isClient;
  bool get isOnStandby => standbyStatus == StandbyStatus.in_;
  bool get hasLocation => lastLat != null && lastLng != null;

  /// Tenant org id (`clients.id`). Client logins and field users share this.
  String? get orgId => clientId ?? (isClient ? id : null);

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      email: (map['email'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      mobile: map['mobile'] as String?,
      photoUrl: map['photo_url'] as String?,
      username: map['username'] as String?,
      role: UserRoleX.fromDb(map['role'] as String?),
      clientId: map['client_id'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
      standbyStatus: StandbyStatusX.fromDb(map['standby_status'] as String?),
      lastLat: (map['last_lat'] as num?)?.toDouble(),
      lastLng: (map['last_lng'] as num?)?.toDouble(),
      lastLocationAt: map['last_location_at'] == null
          ? null
          : DateTime.tryParse(map['last_location_at'].toString()),
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
    );
  }

  Profile copyWith({
    String? name,
    String? mobile,
    String? photoUrl,
    String? username,
    String? clientId,
    bool? isActive,
    StandbyStatus? standbyStatus,
    double? lastLat,
    double? lastLng,
    DateTime? lastLocationAt,
  }) {
    return Profile(
      id: id,
      email: email,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      role: role,
      clientId: clientId ?? this.clientId,
      isActive: isActive ?? this.isActive,
      standbyStatus: standbyStatus ?? this.standbyStatus,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      createdAt: createdAt,
    );
  }
}
