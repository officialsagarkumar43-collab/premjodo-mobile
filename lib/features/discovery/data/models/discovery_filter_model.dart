class DiscoveryFilterModel {
  final double maxDistance;
  final int minAge;
  final int maxAge;
  final String gender; // 'everyone', 'female', 'male'
  final bool verifiedOnly;

  const DiscoveryFilterModel({
    this.maxDistance = 50.0,
    this.minAge = 18,
    this.maxAge = 40,
    this.gender = 'everyone',
    this.verifiedOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'maxDistance': maxDistance,
        'minAge': minAge,
        'maxAge': maxAge,
        'gender': gender,
        'verifiedOnly': verifiedOnly,
      };

  factory DiscoveryFilterModel.fromJson(Map<String, dynamic> json) {
    return DiscoveryFilterModel(
      maxDistance: (json['maxDistance'] as num?)?.toDouble() ??
          (json['distance'] as num?)?.toDouble() ??
          (json['maxDistanceKm'] as num?)?.toDouble() ??
          50.0,
      minAge: (json['minAge'] as num?)?.toInt() ?? 18,
      maxAge: (json['maxAge'] as num?)?.toInt() ?? 40,
      gender: json['gender']?.toString() ?? 'everyone',
      verifiedOnly: json['verifiedOnly'] == true,
    );
  }

  DiscoveryFilterModel copyWith({
    double? maxDistance,
    int? minAge,
    int? maxAge,
    String? gender,
    bool? verifiedOnly,
  }) {
    return DiscoveryFilterModel(
      maxDistance: maxDistance ?? this.maxDistance,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      gender: gender ?? this.gender,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  bool get isDefault =>
      maxDistance == 50.0 &&
      minAge == 18 &&
      maxAge == 40 &&
      gender == 'everyone' &&
      !verifiedOnly;
}
