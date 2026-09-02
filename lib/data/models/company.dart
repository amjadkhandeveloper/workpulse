class Company {
  const Company({
    required this.id,
    required this.name,
    this.location,
    this.work,
    this.contactName,
    this.mobile,
    this.lat,
    this.lng,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? location;
  final String? work;
  final String? contactName;
  final String? mobile;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      location: map['location'] as String?,
      work: map['work'] as String?,
      contactName: map['contact_name'] as String?,
      mobile: map['mobile'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsert() => {
        'name': name,
        'location': location,
        'work': work,
        'contact_name': contactName,
        'mobile': mobile,
        'lat': lat,
        'lng': lng,
      };
}
