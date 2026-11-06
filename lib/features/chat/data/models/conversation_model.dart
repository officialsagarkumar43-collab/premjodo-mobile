import 'package:prem_jodo_mobile/core/utils/image_helper.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/features/chat/data/models/chat_message_model.dart';

class ConversationModel {
  final String id;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final List<String> partnerPhotos;
  final String partnerBio;
  final List<String> partnerInterests;
  final String partnerOccupation;
  final String partnerCity;
  final int? partnerAge;
  final String? partnerGender;
  final String? partnerEducation;
  final String? partnerLookingFor;
  final bool isVerified;
  final List<ChatMessageModel> messages;

  ConversationModel({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.partnerPhotos = const [],
    this.partnerBio = '',
    this.partnerInterests = const [],
    this.partnerOccupation = 'Member',
    this.partnerCity = 'India',
    this.partnerAge,
    this.partnerGender,
    this.partnerEducation,
    this.partnerLookingFor,
    this.isVerified = false,
    this.messages = const [],
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final myUserId = StorageService.getUserId() ?? '';

    String partnerId = json['partnerId']?.toString() ?? '';
    String partnerName = json['partnerName']?.toString() ?? '';
    List<String> photos = [];
    String bio = '';
    List<String> interests = [];
    String occupation = 'Member';
    String city = 'India';
    int? age;
    String? gender;
    String? education;
    String? lookingFor;
    bool isVerified = false;

    void parseProfileData(Map profileObj) {
      if (profileObj['bio'] != null && profileObj['bio'].toString().isNotEmpty) {
        bio = profileObj['bio'].toString();
      }
      if (profileObj['occupation'] != null && profileObj['occupation'].toString().isNotEmpty) {
        occupation = profileObj['occupation'].toString();
      } else if (profileObj['education'] != null && profileObj['education'].toString().isNotEmpty) {
        occupation = profileObj['education'].toString();
      }
      if (profileObj['education'] != null) {
        education = profileObj['education'].toString();
      }
      if (profileObj['lookingFor'] != null) {
        lookingFor = profileObj['lookingFor'].toString();
      }
      if (profileObj['gender'] != null) {
        gender = profileObj['gender'].toString();
      }

      if (profileObj['location'] is String) {
        city = profileObj['location'];
      } else if (profileObj['location'] is Map && profileObj['location']['city'] != null && profileObj['location']['city'].toString().isNotEmpty) {
        city = profileObj['location']['city'].toString();
      } else if (profileObj['city'] != null) {
        city = profileObj['city'].toString();
      }

      if (profileObj['age'] is int) {
        age = profileObj['age'];
      } else if (profileObj['birthday'] is Map && profileObj['birthday']['year'] != null) {
        final bYear = int.tryParse(profileObj['birthday']['year'].toString());
        if (bYear != null) age = DateTime.now().year - bYear;
      } else if (profileObj['dateOfBirth'] != null) {
        final dob = DateTime.tryParse(profileObj['dateOfBirth'].toString());
        if (dob != null) age = DateTime.now().year - dob.year;
      }

      // STRICTLY USE "photos"
      if (profileObj['photos'] is List) {
        for (var p in profileObj['photos']) {
          final resolved = ImageHelper.resolveImageUrl(p);
          if (resolved.isNotEmpty && !photos.contains(resolved)) {
            photos.add(resolved);
          }
        }
      }

      if (profileObj['interests'] is List) {
        for (var i in profileObj['interests']) {
          if (i is String && i.isNotEmpty) {
            interests.add(i);
          } else if (i is Map && i['name'] != null) {
            interests.add(i['name'].toString());
          }
        }
      }
    }

    void parseUserObj(Map userObj) {
      final uId = userObj['_id']?.toString() ?? userObj['id']?.toString() ?? '';
      if (uId.isNotEmpty) partnerId = uId;
      final uName = userObj['fullName']?.toString() ?? userObj['name']?.toString() ?? userObj['firstName']?.toString() ?? '';
      if (uName.isNotEmpty) partnerName = uName;
      if (userObj['isVerified'] == true || userObj['isFaceVerification'] == true) {
        isVerified = true;
      }

      // STRICTLY USE "photos"
      if (userObj['photos'] is List) {
        for (var p in userObj['photos']) {
          final r = ImageHelper.resolveImageUrl(p);
          if (r.isNotEmpty && !photos.contains(r)) photos.add(r);
        }
      }
      if (userObj['profile'] is Map) {
        parseProfileData(userObj['profile'] as Map);
      }
    }

    // Direct photos on json
    if (json['photos'] is List) {
      for (var p in json['photos']) {
        final r = ImageHelper.resolveImageUrl(p);
        if (r.isNotEmpty && !photos.contains(r)) photos.add(r);
      }
    }

    if (json['partner'] is Map) {
      parseUserObj(json['partner'] as Map);
    }

    if (json['partnerProfile'] is Map) {
      parseProfileData(json['partnerProfile'] as Map);
    }

    if (json['recipient'] is Map) {
      parseUserObj(json['recipient'] as Map);
    }

    // Check participants / members list and pick the other user
    final participantLists = [json['participants'], json['members'], json['users']];
    for (var listCandidate in participantLists) {
      if (listCandidate is List && listCandidate.isNotEmpty) {
        Map? chosenPartner;
        for (var pt in listCandidate) {
          if (pt is Map) {
            final pId = pt['_id']?.toString() ?? pt['id']?.toString() ?? '';
            // Skip current user
            if (myUserId.isNotEmpty && (pId.toLowerCase() == myUserId.toLowerCase())) {
              continue;
            }
            chosenPartner = pt;
            if (myUserId.isNotEmpty && pId.toLowerCase() != myUserId.toLowerCase()) {
              break;
            }
          }
        }
        if (chosenPartner != null) {
          parseUserObj(chosenPartner);
        }
      }
    }

    if (json['user'] is Map) {
      final u = json['user'] as Map;
      final uId = u['_id']?.toString() ?? u['id']?.toString() ?? '';
      if (myUserId.isEmpty || (uId.isNotEmpty && uId.toLowerCase() != myUserId.toLowerCase())) {
        parseUserObj(u);
      }
    }

    String partnerAvatar = photos.isNotEmpty ? photos.first : '';

    if (partnerAvatar.isNotEmpty && !photos.contains(partnerAvatar)) {
      photos.insert(0, partnerAvatar);
    }

    if (partnerName.isEmpty) {
      partnerName = 'Match';
    }

    DateTime parseToLocal(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val.toLocal();
      final str = val.toString().trim();
      if (str.isEmpty) return DateTime.now();
      try {
        String s = str;
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s}Z';
        }
        final parsed = DateTime.tryParse(s) ?? DateTime.tryParse(str) ?? DateTime.now();
        return parsed.toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    String lastMessageText = '';
    DateTime lastTime = DateTime.now();
    if (json['lastMessage'] is String) {
      lastMessageText = json['lastMessage'];
    } else if (json['lastMessage'] is Map) {
      lastMessageText = json['lastMessage']['content']?.toString() ??
          json['lastMessage']['message']?.toString() ??
          '';
      if (json['lastMessage']['createdAt'] != null) {
        lastTime = parseToLocal(json['lastMessage']['createdAt']);
      } else if (json['lastMessage']['timestamp'] != null) {
        lastTime = parseToLocal(json['lastMessage']['timestamp']);
      }
    }

    if (json['lastMessageTime'] != null) {
      lastTime = parseToLocal(json['lastMessageTime']);
    } else if (json['updatedAt'] != null) {
      lastTime = parseToLocal(json['updatedAt']);
    } else if (json['createdAt'] != null) {
      lastTime = parseToLocal(json['createdAt']);
    }

    List<ChatMessageModel> messagesList = [];
    if (json['messages'] is List) {
      for (var m in json['messages']) {
        if (m is Map<String, dynamic>) {
          messagesList.add(ChatMessageModel.fromJson(m));
        } else if (m is Map) {
          messagesList.add(ChatMessageModel.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }

    return ConversationModel(
      id: id,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerAvatar: partnerAvatar,
      lastMessage: lastMessageText,
      lastMessageTime: lastTime,
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount']
          : (int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0),
      isOnline: json['isOnline'] == true,
      partnerPhotos: photos,
      partnerBio: bio,
      partnerInterests: interests,
      partnerOccupation: occupation,
      partnerCity: city,
      partnerAge: age,
      partnerGender: gender,
      partnerEducation: education,
      partnerLookingFor: lookingFor,
      isVerified: isVerified,
      messages: messagesList,
    );
  }

  ConversationModel copyWith({
    String? id,
    String? partnerId,
    String? partnerName,
    String? partnerAvatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    List<String>? partnerPhotos,
    String? partnerBio,
    List<String>? partnerInterests,
    String? partnerOccupation,
    String? partnerCity,
    int? partnerAge,
    String? partnerGender,
    String? partnerEducation,
    String? partnerLookingFor,
    bool? isVerified,
    List<ChatMessageModel>? messages,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      partnerPhotos: partnerPhotos ?? this.partnerPhotos,
      partnerBio: partnerBio ?? this.partnerBio,
      partnerInterests: partnerInterests ?? this.partnerInterests,
      partnerOccupation: partnerOccupation ?? this.partnerOccupation,
      partnerCity: partnerCity ?? this.partnerCity,
      partnerAge: partnerAge ?? this.partnerAge,
      partnerGender: partnerGender ?? this.partnerGender,
      partnerEducation: partnerEducation ?? this.partnerEducation,
      partnerLookingFor: partnerLookingFor ?? this.partnerLookingFor,
      isVerified: isVerified ?? this.isVerified,
      messages: messages ?? this.messages,
    );
  }
}
