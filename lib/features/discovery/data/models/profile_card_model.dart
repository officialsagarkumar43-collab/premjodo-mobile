import 'package:prem_jodo_mobile/core/utils/image_helper.dart';

class ProfileCardModel {
  final String id;
  final String name;
  final int age;
  final String occupation;
  final String city;
  final String bio;
  final double? distanceKm;
  final List<String> photos;
  final List<String> interests;
  final String? gender;
  final String? education;
  final String? lookingFor;
  final bool isVerified;
  final int compatibilityScore;

  ProfileCardModel({
    required this.id,
    required this.name,
    required this.age,
    required this.occupation,
    required this.city,
    required this.bio,
    this.distanceKm,
    required this.photos,
    this.interests = const [],
    this.gender,
    this.education,
    this.lookingFor,
    this.isVerified = false,
    this.compatibilityScore = 85,
  });

  static String formatInterest(String raw) {
    if (raw.isEmpty) return raw;
    final words = raw.replaceAll(RegExp(r'[_\-]+'), ' ').trim().split(RegExp(r'\s+'));
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  List<String> get formattedInterests =>
      interests.map(formatInterest).toList();

  String? get formattedDistance {
    if (distanceKm == null) return null;
    if (distanceKm! < 1) return '< 1 km away';
    if (distanceKm! == distanceKm!.roundToDouble()) {
      return '${distanceKm!.toInt()} km away';
    }
    return '${distanceKm!.toStringAsFixed(1)} km away';
  }

  factory ProfileCardModel.fromJson(Map<String, dynamic> json) {
    final userObj = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : json;
    final profileObj = (json['profile'] is Map<String, dynamic>)
        ? json['profile'] as Map<String, dynamic>
        : json;

    final id = json['_id']?.toString() ??
        userObj['_id']?.toString() ??
        profileObj['_id']?.toString() ??
        json['id']?.toString() ??
        '';

    final name = json['fullName'] ??
        userObj['fullName'] ??
        profileObj['fullName'] ??
        profileObj['firstName'] ??
        json['name'] ??
        userObj['name'] ??
        'Prem Jodo User';

    int age = 24;
    if (json['age'] is int) {
      age = json['age'];
    } else if (profileObj['age'] is int) {
      age = profileObj['age'];
    } else if (profileObj['birthYear'] != null) {
      final bYear = int.tryParse(profileObj['birthYear'].toString());
      if (bYear != null) age = DateTime.now().year - bYear;
    } else if (json['age'] != null) {
      age = int.tryParse(json['age'].toString()) ?? 24;
    }

    // STRICTLY USE "photos" key & avatar fallbacks
    List<String> photos = [];
    final rawPhotos = json['photos'] ?? profileObj['photos'] ?? userObj['photos'] ?? json['photoObjects'] ?? profileObj['photoObjects'];
    if (rawPhotos is List && rawPhotos.isNotEmpty) {
      for (var p in rawPhotos) {
        String? pUrl;
        if (p is String) {
          pUrl = p;
        } else if (p is Map) {
          pUrl = p['url']?.toString() ??
              p['secure_url']?.toString() ??
              p['path']?.toString() ??
              p['fileUrl']?.toString() ??
              p['photo']?.toString();
        }
        if (pUrl != null && pUrl.isNotEmpty) {
          final resolved = ImageHelper.resolveImageUrl(pUrl);
          if (resolved.isNotEmpty && !photos.contains(resolved)) {
            photos.add(resolved);
          }
        }
      }
    }

    final singlePhotoCandidates = [
      json['primaryPhoto'],
      profileObj['primaryPhoto'],
      userObj['primaryPhoto'],
      json['avatar'],
      profileObj['avatar'],
      userObj['avatar'],
      json['profilePhoto'],
      profileObj['profilePhoto'],
      userObj['profilePhoto'],
      json['photoUrl'],
      profileObj['photoUrl'],
      userObj['photoUrl'],
      json['photo'],
      profileObj['photo'],
      userObj['photo'],
    ];

    for (final candidate in singlePhotoCandidates) {
      if (candidate != null && candidate.toString().trim().isNotEmpty) {
        final res = ImageHelper.resolveImageUrl(candidate);
        if (res.isNotEmpty && !photos.contains(res)) {
          photos.insert(0, res);
          break;
        }
      }
    }

    List<String> interests = [];
    final rawInterests = json['interests'] ?? profileObj['interests'] ?? userObj['interests'];
    if (rawInterests is List) {
      for (var i in rawInterests) {
        if (i is String && i.trim().isNotEmpty) {
          interests.add(i.trim());
        } else if (i is Map && i['name'] != null) {
          interests.add(i['name'].toString().trim());
        }
      }
    }

    String city = 'India';
    if (json['city'] != null && json['city'].toString().isNotEmpty) {
      city = json['city'].toString();
    } else if (profileObj['city'] != null && profileObj['city'].toString().isNotEmpty) {
      city = profileObj['city'].toString();
    } else if (profileObj['location'] is String && (profileObj['location'] as String).isNotEmpty) {
      city = profileObj['location'];
    } else if (profileObj['location'] is Map && profileObj['location']['city'] != null) {
      city = profileObj['location']['city'].toString();
    }

    final double? distanceKm = (json['distance'] as num?)?.toDouble() ??
        (profileObj['distance'] as num?)?.toDouble() ??
        (json['distanceKm'] as num?)?.toDouble() ??
        (profileObj['distanceKm'] as num?)?.toDouble();

    return ProfileCardModel(
      id: id,
      name: name.toString(),
      age: age,
      occupation: json['occupation']?.toString() ??
          profileObj['occupation']?.toString() ??
          json['education']?.toString() ??
          profileObj['education']?.toString() ??
          'Member',
      city: city,
      bio: json['bio']?.toString() ?? profileObj['bio']?.toString() ?? 'Looking to connect on Prem Jodo ✨',
      distanceKm: distanceKm,
      photos: photos,
      interests: interests,
      gender: json['gender']?.toString() ?? profileObj['gender']?.toString() ?? userObj['gender']?.toString(),
      education: json['education']?.toString() ?? profileObj['education']?.toString(),
      lookingFor: json['lookingFor']?.toString() ?? profileObj['lookingFor']?.toString() ?? profileObj['intent']?.toString(),
      isVerified: json['isVerified'] == true || userObj['isVerified'] == true || profileObj['isVerified'] == true,
      compatibilityScore: json['compatibilityScore'] is int ? json['compatibilityScore'] : 90,
    );
  }
}
