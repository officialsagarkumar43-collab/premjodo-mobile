import 'package:prem_jodo_mobile/core/utils/image_helper.dart';

class UserPhotoModel {
  final String id;
  final String url;
  final String rawUrl;
  final bool isPrimary;

  UserPhotoModel({
    this.id = '',
    required this.url,
    this.rawUrl = '',
    this.isPrimary = false,
  });

  factory UserPhotoModel.fromDynamic(dynamic item) {
    if (item is Map) {
      final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';
      final raw = (item['url'] ??
              item['secure_url'] ??
              item['path'] ??
              item['photoUrl'] ??
              '')
          .toString();
      final resolved = ImageHelper.resolveImageUrl(raw);
      return UserPhotoModel(
        id: id,
        url: resolved.isNotEmpty ? resolved : raw,
        rawUrl: raw,
        isPrimary: item['isPrimary'] == true,
      );
    } else if (item is String) {
      final resolved = ImageHelper.resolveImageUrl(item);
      return UserPhotoModel(
        id: '',
        url: resolved.isNotEmpty ? resolved : item,
        rawUrl: item,
      );
    }
    return UserPhotoModel(url: '');
  }
}

class UserModel {
  final String id;
  final String? phone;
  final String? email;
  final String name;
  final int? age;
  final String? gender;
  final bool showGenderOnProfile;
  final List<String> interestedIn;
  final String? lookingFor;
  final String? bio;
  final String? occupation;
  final String? education;
  final String? religion;
  final String? city;
  final String? state;
  final String? country;
  final List<double>? coordinates; // [longitude, latitude]
  final int? maxDistanceKm;
  final int? birthdayMonth;
  final int? birthdayDay;
  final int? birthdayYear;
  final List<String> photos;
  final List<UserPhotoModel> photoObjects;
  final bool isVerified;
  final bool isFaceVerification;
  final bool isOnboarded;
  final bool isPremium;
  final bool isVip;
  final String? planName;
  final String? subscriptionStatus;
  final Map<String, dynamic>? subscription;
  final int coins;
  final List<String> interests;

  UserModel({
    required this.id,
    this.phone,
    this.email,
    required this.name,
    this.age,
    this.gender,
    this.showGenderOnProfile = true,
    this.interestedIn = const [],
    this.lookingFor,
    this.bio,
    this.occupation,
    this.education,
    this.religion,
    this.city,
    this.state,
    this.country,
    this.coordinates,
    this.maxDistanceKm = 50,
    this.birthdayMonth,
    this.birthdayDay,
    this.birthdayYear,
    this.photos = const [],
    this.photoObjects = const [],
    this.isVerified = false,
    this.isFaceVerification = false,
    this.isOnboarded = false,
    this.isPremium = false,
    this.isVip = false,
    this.planName,
    this.subscriptionStatus,
    this.subscription,
    this.coins = 0,
    this.interests = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rootData = (json['data'] is Map) ? (json['data'] as Map) : json;
    final userObj = (rootData['user'] is Map)
        ? (rootData['user'] as Map)
        : (json['user'] is Map ? (json['user'] as Map) : rootData);
    final profileObj = (rootData['profile'] is Map)
        ? (rootData['profile'] as Map)
        : (json['profile'] is Map
            ? (json['profile'] as Map)
            : (userObj['profile'] is Map ? (userObj['profile'] as Map) : rootData));

    final id = userObj['_id']?.toString() ??
        profileObj['_id']?.toString() ??
        rootData['_id']?.toString() ??
        json['_id']?.toString() ??
        json['id']?.toString() ??
        '';

    final name = userObj['fullName'] ??
        profileObj['fullName'] ??
        profileObj['firstName'] ??
        userObj['name'] ??
        rootData['name'] ??
        json['name'] ??
        'Prem Jodo User';

    int? age;
    int? bMonth;
    int? bDay;
    int? bYear;

    if (profileObj['birthday'] is Map) {
      bMonth = int.tryParse(profileObj['birthday']['month']?.toString() ?? '');
      bDay = int.tryParse(profileObj['birthday']['day']?.toString() ?? '');
      bYear = int.tryParse(profileObj['birthday']['year']?.toString() ?? '');
    }

    if (profileObj['age'] is int) {
      age = profileObj['age'];
    } else if (bYear != null) {
      age = DateTime.now().year - bYear;
    } else if (profileObj['dateOfBirth'] != null) {
      final dob = DateTime.tryParse(profileObj['dateOfBirth'].toString());
      if (dob != null) {
        age = DateTime.now().year - dob.year;
        bMonth ??= dob.month;
        bDay ??= dob.day;
        bYear ??= dob.year;
      }
    } else if (profileObj['birthYear'] != null) {
      final year = int.tryParse(profileObj['birthYear'].toString());
      if (year != null) {
        age = DateTime.now().year - year;
        bYear ??= year;
      }
    } else if (json['age'] != null) {
      age = int.tryParse(json['age'].toString());
    }

    // STRICTLY USE "photos" key
    List<UserPhotoModel> photoObjects = [];
    List<String> photos = [];
    final rawPhotos = profileObj['photos'] ?? userObj['photos'] ?? rootData['photos'] ?? json['photos'];
    if (rawPhotos is List) {
      for (var p in rawPhotos) {
        final obj = UserPhotoModel.fromDynamic(p);
        if (obj.url.isNotEmpty && !photos.contains(obj.url)) {
          photoObjects.add(obj);
          photos.add(obj.url);
        }
      }
    }

    final singleCandidates = [
      profileObj['avatar'],
      userObj['avatar'],
      profileObj['profilePhoto'],
      userObj['profilePhoto'],
      profileObj['photoUrl'],
      userObj['photoUrl'],
      profileObj['primaryPhoto'],
      userObj['primaryPhoto'],
      profileObj['photo'],
      userObj['photo'],
      rootData['avatar'],
      rootData['photoUrl'],
      json['avatar'],
    ];

    for (var candidate in singleCandidates) {
      if (candidate != null && candidate.toString().trim().isNotEmpty) {
        final obj = UserPhotoModel.fromDynamic(candidate);
        if (obj.url.isNotEmpty && !photos.contains(obj.url)) {
          photoObjects.add(obj);
          photos.add(obj.url);
        }
      }
    }

    List<String> interests = [];
    final rawInterests = profileObj['interests'] ?? userObj['interests'] ?? rootData['interests'];
    if (rawInterests is List) {
      for (var i in rawInterests) {
        if (i is String && i.isNotEmpty) {
          interests.add(i);
        } else if (i is Map && i['name'] != null) {
          interests.add(i['name'].toString());
        }
      }
    }

    // InterestedIn
    List<String> interestedIn = [];
    final rawInterestedIn = profileObj['interestedIn'] ?? userObj['interestedIn'];
    if (rawInterestedIn is List) {
      for (var item in rawInterestedIn) {
        if (item is String && item.isNotEmpty) {
          interestedIn.add(item);
        }
      }
    } else if (rawInterestedIn is String && rawInterestedIn.isNotEmpty) {
      interestedIn.add(rawInterestedIn);
    }

    String? city;
    String? state;
    String? country;
    List<double>? coordinates;

    final loc = profileObj['location'] ?? userObj['location'] ?? rootData['location'];
    if (loc is String) {
      city = loc;
    } else if (loc is Map) {
      if (loc['city'] != null) city = loc['city'].toString();
      if (loc['state'] != null) state = loc['state'].toString();
      if (loc['country'] != null) country = loc['country'].toString();
      if (loc['coordinates'] is List) {
        final coordsList = loc['coordinates'] as List;
        if (coordsList.length >= 2) {
          final lng = double.tryParse(coordsList[0].toString());
          final lat = double.tryParse(coordsList[1].toString());
          if (lng != null && lat != null) {
            coordinates = [lng, lat];
          }
        }
      }
    }

    if (city == null || city.isEmpty) {
      if (profileObj['city'] != null) city = profileObj['city'].toString();
      if (userObj['city'] != null) city = userObj['city'].toString();
    }

    int? maxDistanceKm;
    final rawDist = (profileObj['partnerPreferences'] is Map ? profileObj['partnerPreferences']['maxDistanceKm'] ?? profileObj['partnerPreferences']['maxDistance'] : null) ??
        (userObj['partnerPreferences'] is Map ? userObj['partnerPreferences']['maxDistanceKm'] ?? userObj['partnerPreferences']['maxDistance'] : null) ??
        profileObj['maxDistanceKm'] ??
        profileObj['maxDistance'] ??
        userObj['maxDistanceKm'] ??
        userObj['maxDistance'] ??
        rootData['maxDistanceKm'] ??
        rootData['maxDistance'] ??
        json['maxDistanceKm'] ??
        json['maxDistance'];
    if (rawDist != null) {
      maxDistanceKm = int.tryParse(rawDist.toString()) ?? (rawDist is num ? rawDist.toInt() : null);
    }

    final sub = (userObj['subscription'] is Map)
        ? Map<String, dynamic>.from(userObj['subscription'] as Map)
        : (json['subscription'] is Map
            ? Map<String, dynamic>.from(json['subscription'] as Map)
            : (rootData['subscription'] is Map
                ? Map<String, dynamic>.from(rootData['subscription'] as Map)
                : null));

    final isVip = userObj['isVip'] == true ||
        rootData['isVip'] == true ||
        json['isVip'] == true ||
        (sub != null &&
            sub['status'] == 'active' &&
            sub['perks']?['vipBadge'] == true);

    final isPremium = isVip ||
        userObj['isPremium'] == true ||
        rootData['isPremium'] == true ||
        json['isPremium'] == true ||
        (sub != null && sub['status'] == 'active') ||
        userObj['membership'] != null;

    final planName = sub?['planName']?.toString() ??
        (sub?['plan'] is Map
            ? sub!['plan']['name']?.toString()
            : sub?['plan']?.toString());

    final subStatus = sub?['status']?.toString();

    final isFaceVerification = userObj['isFaceVerification'] == true ||
        userObj['isFaceVerified'] == true ||
        json['isFaceVerification'] == true ||
        json['isFaceVerified'] == true ||
        (json['data'] is Map &&
            (json['data']['isFaceVerification'] == true ||
                json['data']['isFaceVerified'] == true)) ||
        profileObj['isFaceVerification'] == true ||
        profileObj['isFaceVerified'] == true;

    final isOnboarded = userObj['isOnboarded'] == true ||
        userObj['isProfileCompleted'] == true ||
        userObj['profileCompleted'] == true ||
        json['isOnboarded'] == true ||
        json['isProfileCompleted'] == true ||
        (json['data'] is Map &&
            (json['data']['isOnboarded'] == true ||
                json['data']['isProfileCompleted'] == true)) ||
        profileObj['isOnboarded'] == true ||
        profileObj['isProfileCompleted'] == true;

    final isVerified = userObj['isVerified'] == true ||
        profileObj['isVerified'] == true ||
        isFaceVerification;

    final showGender = profileObj['showGenderOnProfile'] != false &&
        userObj['showGenderOnProfile'] != false;

    return UserModel(
      id: id,
      phone: userObj['phone']?.toString() ?? json['phone']?.toString(),
      email: userObj['email']?.toString() ?? json['email']?.toString(),
      name: name.toString(),
      age: age,
      gender: profileObj['gender']?.toString() ?? userObj['gender']?.toString(),
      showGenderOnProfile: showGender,
      interestedIn: interestedIn,
      lookingFor: profileObj['lookingFor']?.toString() ??
          userObj['lookingFor']?.toString(),
      bio: profileObj['bio']?.toString() ?? '',
      occupation: profileObj['occupation']?.toString(),
      education: profileObj['education']?.toString(),
      religion: profileObj['religion']?.toString(),
      city: city,
      state: state,
      country: country ?? 'India',
      coordinates: coordinates,
      maxDistanceKm: maxDistanceKm ?? 50,
      birthdayMonth: bMonth,
      birthdayDay: bDay,
      birthdayYear: bYear,
      photos: photos,
      photoObjects: photoObjects,
      isVerified: isVerified,
      isFaceVerification: isFaceVerification,
      isOnboarded: isOnboarded,
      isPremium: isPremium,
      isVip: isVip,
      planName: planName,
      subscriptionStatus: subStatus,
      subscription: sub,
      coins: (userObj['coins'] as num?)?.toInt() ??
          (userObj['wallet']?['coins'] as num?)?.toInt() ??
          0,
      interests: interests,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'showGenderOnProfile': showGenderOnProfile,
      'interestedIn': interestedIn,
      'lookingFor': lookingFor,
      'bio': bio,
      'occupation': occupation,
      'education': education,
      'religion': religion,
      'city': city,
      'state': state,
      'country': country,
      'coordinates': coordinates,
      'maxDistanceKm': maxDistanceKm,
      'birthdayMonth': birthdayMonth,
      'birthdayDay': birthdayDay,
      'birthdayYear': birthdayYear,
      'photos': photos,
      'isVerified': isVerified,
      'isFaceVerification': isFaceVerification,
      'isOnboarded': isOnboarded,
      'isPremium': isPremium,
      'isVip': isVip,
      'planName': planName,
      'subscriptionStatus': subscriptionStatus,
      'subscription': subscription,
      'coins': coins,
      'interests': interests,
    };
  }
}
