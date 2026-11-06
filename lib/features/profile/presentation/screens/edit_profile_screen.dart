import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/constants/app_constants.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_text_field.dart';
import 'package:prem_jodo_mobile/core/utils/location_service.dart';
import 'package:prem_jodo_mobile/core/utils/image_helper.dart';
import 'package:prem_jodo_mobile/core/services/storage_service.dart';
import 'package:prem_jodo_mobile/core/models/option_item.dart';
import 'package:prem_jodo_mobile/features/auth/data/models/user_model.dart';
import 'package:prem_jodo_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/discovery/presentation/providers/discovery_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiClient _apiClient = ApiClient();
  final ImagePicker _picker = ImagePicker();

  // User & Profile Schema Controllers
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _educationController;
  late TextEditingController _religionController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;

  // Gender & Preferences
  String _gender = 'female';
  bool _showGenderOnProfile = true;
  List<String> _interestedIn = ['men'];
  String _lookingFor = '';
  String _selectedEducation = AppConstants.educationOptions.first;
  String _selectedReligion = AppConstants.religionOptions.first;
  double _maxDistanceKm = 50;

  // Birthday & Date of Birth (Schema: birthday: {month, day, year}, dateOfBirth)
  int _selectedMonth = 1;
  int _selectedDay = 15;
  int _selectedYear = 2000;

  int get _calculatedAge {
    final now = DateTime.now();
    int age = now.year - _selectedYear;
    if (now.month < _selectedMonth ||
        (now.month == _selectedMonth && now.day < _selectedDay)) {
      age--;
    }
    return age > 0 ? age : 18;
  }

  // Location Coordinates: [longitude, latitude] (GeoJSON Point format)
  double _latitude = 28.6139; // Default (e.g. New Delhi)
  double _longitude = 77.2090;
  bool _isFetchingLocation = false;

  // 6 Photos Slots (Web Pattern)
  List<String> _photos = [];
  List<String> _interests = [];

  // Dynamic API Data (Strictly from API, no dummy fallback)
  List<OptionItem> _apiLookingForOptions = [];
  List<OptionItem> _apiInterests = [];
  bool _isLoadingLookingFor = true;
  bool _isLoadingInterests = true;

  bool _isLoading = false;
  final Set<int> _uploadingSlots = {};
  final Set<int> _deletingSlots = {};

  final List<String> _genderOptions = ['female', 'male', 'other'];
  final List<String> _interestedInOptions = ['men', 'women', 'everyone'];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;

    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');

    final initialEdu = user?.education ?? user?.occupation ?? '';
    if (AppConstants.educationOptions.contains(initialEdu)) {
      _selectedEducation = initialEdu;
    } else if (initialEdu.isNotEmpty) {
      _selectedEducation = AppConstants.educationOptions.first;
    }
    _educationController = TextEditingController(text: _selectedEducation);

    final initialRel = user?.religion ?? '';
    if (AppConstants.religionOptions.contains(initialRel)) {
      _selectedReligion = initialRel;
    } else if (initialRel.isNotEmpty) {
      _selectedReligion = AppConstants.religionOptions.first;
    }
    _religionController = TextEditingController(text: _selectedReligion);
    _cityController = TextEditingController(text: user?.city ?? '');
    _stateController = TextEditingController(text: user?.state ?? '');
    _countryController =
        TextEditingController(text: user?.country ?? 'India');

    if (user != null) {
      if (user.gender != null && _genderOptions.contains(user.gender)) {
        _gender = user.gender!;
      }
      _showGenderOnProfile = user.showGenderOnProfile;

      if (user.interestedIn.isNotEmpty) {
        _interestedIn = List<String>.from(user.interestedIn);
      }

      if (user.lookingFor != null && user.lookingFor!.isNotEmpty) {
        _lookingFor = user.lookingFor!;
      }

      if (user.birthdayYear != null) {
        _selectedYear = user.birthdayYear!;
        _selectedMonth = user.birthdayMonth ?? 1;
        _selectedDay = user.birthdayDay ?? 15;
      } else if (user.age != null && user.age! >= 18) {
        _selectedYear = DateTime.now().year - user.age!;
      }

      if (user.coordinates != null && user.coordinates!.length >= 2) {
        _longitude = user.coordinates![0];
        _latitude = user.coordinates![1];
      }

      if (user.maxDistanceKm != null && user.maxDistanceKm! > 0) {
        _maxDistanceKm = user.maxDistanceKm!.toDouble();
      } else {
        final savedFilter = StorageService.getDiscoveryFilter();
        if (savedFilter != null && savedFilter['maxDistance'] != null) {
          final d = (savedFilter['maxDistance'] as num).toDouble();
          if (d > 0) _maxDistanceKm = d;
        }
      }

      _photos = List<String>.from(user.photos);
      if (_photos.isEmpty) {
        final cachedAvatar = StorageService.getUserAvatar();
        if (cachedAvatar != null && cachedAvatar.isNotEmpty) {
          _photos.add(cachedAvatar);
        }
      }
      _interests = List<String>.from(user.interests);
      for (final item in user.interests) {
        if (!_apiInterests.any((it) => it.matches(item))) {
          _apiInterests.add(OptionItem(label: item, value: item));
        }
      }
    } else {
      final savedFilter = StorageService.getDiscoveryFilter();
      if (savedFilter != null && savedFilter['maxDistance'] != null) {
        final d = (savedFilter['maxDistance'] as num).toDouble();
        if (d > 0) _maxDistanceKm = d;
      }
    }

    _fetchLookingForOptions();
    _fetchInterests();
    _loadFreshProfile();
  }

  Future<void> _loadFreshProfile() async {
    try {
      final fresh = await AuthRepository().getProfile();
      if (fresh != null && mounted) {
        setState(() {
          if (fresh.maxDistanceKm != null && fresh.maxDistanceKm! > 0) {
            _maxDistanceKm = fresh.maxDistanceKm!.toDouble();
          }
          if (_photos.isEmpty && fresh.photos.isNotEmpty) {
            _photos = List<String>.from(fresh.photos);
          }
          if (fresh.interests.isNotEmpty) {
            _interests = List<String>.from(fresh.interests);
            for (final item in fresh.interests) {
              if (item.trim().isNotEmpty &&
                  !_apiInterests.any((it) => it.matches(item))) {
                _apiInterests.add(OptionItem(label: item, value: item));
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchLookingForOptions() async {
    try {
      final res = await _apiClient.get(ApiEndpoints.getLookingForOptions);
      if (res.statusCode == 200 && res.data != null) {
        final resData = res.data;
        final list = (resData is Map && resData['data'] != null)
            ? resData['data']
            : (resData is Map && resData['options'] != null
                ? resData['options']
                : resData);
        if (list is List) {
          final result = <OptionItem>[];
          for (var item in list) {
            final opt = OptionItem.fromDynamic(item);
            if (opt.value.isNotEmpty &&
                !result.any((r) => r.matches(opt.value))) {
              result.add(opt);
            }
          }
          if (mounted) {
            setState(() {
              _apiLookingForOptions = result;
              if (_lookingFor.isEmpty && result.isNotEmpty) {
                _lookingFor = result.first.value;
              }
              _isLoadingLookingFor = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoadingLookingFor = false;
      });
    }
  }

  Future<void> _fetchInterests() async {
    try {
      final res = await _apiClient.get(ApiEndpoints.getInterests);
      if (res.statusCode == 200 && res.data != null) {
        final resData = res.data;
        final list = (resData is Map && resData['data'] != null)
            ? resData['data']
            : (resData is Map && resData['interests'] != null
                ? resData['interests']
                : resData);
        if (list is List) {
          final result = <OptionItem>[];
          for (var item in list) {
            final opt = OptionItem.fromDynamic(item);
            if (opt.value.isNotEmpty &&
                !result.any((r) => r.matches(opt.value))) {
              result.add(opt);
            }
          }

          // Always merge the user's currently selected interests so none are lost
          for (final userInt in _interests) {
            if (userInt.trim().isNotEmpty &&
                !result.any((r) => r.matches(userInt))) {
              result.add(OptionItem(label: userInt, value: userInt));
            }
          }

          if (mounted) {
            setState(() {
              _apiInterests = result;
              _isLoadingInterests = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        if (_apiInterests.isEmpty && _interests.isNotEmpty) {
          _apiInterests = _interests
              .map((e) => OptionItem(label: e, value: e))
              .toList();
        }
        _isLoadingInterests = false;
      });
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _isFetchingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '📍 GPS Location updated: (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() => _isFetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not fetch GPS. Please check location permissions.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _educationController.dispose();
    _religionController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Photo Picker & Slot Actions (6 Slots)
  // ---------------------------------------------------------------------------
  void _openPhotoOptionsModal(int slotIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161826),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Photo (Slot ${slotIndex + 1})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFFFB7185)),
                ),
                title: const Text('Take Photo from Camera',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickCameraImage(slotIndex);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFFA78BFA)),
                ),
                title: const Text('Choose from Gallery (Bulk)',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Select multiple photos at once',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickGalleryImages(slotIndex);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.link_rounded, color: Color(0xFF34D399)),
                ),
                title: const Text('Paste Image Web URL',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showImageUrlDialog(slotIndex);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCameraImage(int slotIndex) async {
    if (_photos.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 6 photos max')),
      );
      return;
    }
    final picked =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;

    final targetSlot =
        slotIndex < _photos.length ? slotIndex : _photos.length;
    setState(() => _uploadingSlots.add(targetSlot));

    try {
      final formData = FormData();
      formData.files.add(MapEntry(
        'photos',
        await MultipartFile.fromFile(picked.path,
            filename: picked.path.split(Platform.pathSeparator).last),
      ));

      final res =
          await _apiClient.post(ApiEndpoints.uploadPhotos, data: formData);

      String? uploadedUrl;
      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = res.data;
        if (resData is Map) {
          final rawList = resData['photos'] ??
              resData['photoUrls'] ??
              resData['urls'] ??
              (resData['data'] is Map
                  ? (resData['data']['photos'] ??
                      resData['data']['photoUrls'] ??
                      resData['data']['urls'])
                  : null);
          if (rawList is List && rawList.isNotEmpty) {
            uploadedUrl = ImageHelper.resolveImageUrl(rawList.first);
          } else {
            final single = resData['photoUrl'] ??
                resData['url'] ??
                (resData['data'] is Map
                    ? (resData['data']['url'] ??
                        resData['data']['photoUrl'])
                    : null);
            if (single != null && single.toString().isNotEmpty) {
              uploadedUrl = ImageHelper.resolveImageUrl(single);
            }
          }
        }
      }
      uploadedUrl ??= picked.path;

      setState(() {
        _uploadingSlots.remove(targetSlot);
        if (targetSlot < _photos.length) {
          _photos[targetSlot] = uploadedUrl!;
        } else if (_photos.length < 6) {
          _photos.add(uploadedUrl!);
        }
      });
      await ref.read(authProvider.notifier).checkAuthStatus();
    } catch (e) {
      debugPrint('Camera upload error: $e');
      setState(() {
        _uploadingSlots.remove(targetSlot);
        if (targetSlot < _photos.length) {
          _photos[targetSlot] = picked.path;
        } else if (_photos.length < 6) {
          _photos.add(picked.path);
        }
      });
    }
  }

  Future<void> _pickGalleryImages(int slotIndex) async {
    final remainingSlots = 6 - _photos.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 6 photos max')),
      );
      return;
    }

    final List<XFile> pickedList =
        await _picker.pickMultiImage(imageQuality: 85);
    if (pickedList.isEmpty) return;

    final toUpload = pickedList.take(remainingSlots).toList();
    final targetSlots =
        List.generate(toUpload.length, (i) => _photos.length + i);

    setState(() => _uploadingSlots.addAll(targetSlots));

    try {
      final formData = FormData();
      for (final xf in toUpload) {
        formData.files.add(MapEntry(
          'photos',
          await MultipartFile.fromFile(xf.path,
              filename: xf.path.split(Platform.pathSeparator).last),
        ));
      }

      final res =
          await _apiClient.post(ApiEndpoints.uploadPhotos, data: formData);

      List<String> uploadedUrls = [];
      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = res.data;
        if (resData is Map) {
          final rawList = resData['photos'] ??
              resData['photoUrls'] ??
              resData['urls'] ??
              (resData['data'] is Map
                  ? (resData['data']['photos'] ??
                      resData['data']['photoUrls'] ??
                      resData['data']['urls'])
                  : null);
          if (rawList is List) {
            for (var item in rawList) {
              final resolved = ImageHelper.resolveImageUrl(item);
              if (resolved.isNotEmpty) uploadedUrls.add(resolved);
            }
          } else {
            final single = resData['photoUrl'] ??
                resData['url'] ??
                (resData['data'] is Map
                    ? (resData['data']['url'] ??
                        resData['data']['photoUrl'])
                    : null);
            if (single != null && single.toString().isNotEmpty) {
              final uploadedUrl = ImageHelper.resolveImageUrl(single);
              uploadedUrls.add(uploadedUrl);
            }
          }
        }
      }

      if (uploadedUrls.isEmpty) {
        uploadedUrls = toUpload.map((e) => e.path).toList();
      }

      setState(() {
        _uploadingSlots.removeAll(targetSlots);
        for (final u in uploadedUrls) {
          if (_photos.length < 6) _photos.add(u);
        }
      });
      await ref.read(authProvider.notifier).checkAuthStatus();
    } catch (e) {
      debugPrint('Gallery bulk upload error: $e');
      setState(() {
        _uploadingSlots.removeAll(targetSlots);
        for (final x in toUpload) {
          if (_photos.length < 6) _photos.add(x.path);
        }
      });
    }
  }

  void _showImageUrlDialog(int slotIndex) {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181A26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Photo URL',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'https://images.unsplash.com/...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F101A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty && url.startsWith('http')) {
                setState(() {
                  if (slotIndex < _photos.length) {
                    _photos[slotIndex] = url;
                  } else {
                    _photos.add(url);
                  }
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add Photo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _removePhoto(int index) async {
    if (index < 0 || index >= _photos.length) return;
    final photoUrl = _photos[index];
    setState(() {
      _deletingSlots.add(index);
    });

    final user = ref.read(authProvider).user;
    UserPhotoModel? photoObj;
    if (user != null && user.photoObjects.isNotEmpty) {
      for (final p in user.photoObjects) {
        if (p.url == photoUrl ||
            p.rawUrl == photoUrl ||
            (p.id.isNotEmpty && (p.id == photoUrl || (index < user.photoObjects.length && user.photoObjects[index].id == p.id)))) {
          photoObj = p;
          break;
        }
      }
      photoObj ??= (index < user.photoObjects.length ? user.photoObjects[index] : null);
    }

    final photoId = (photoObj != null && photoObj.id.isNotEmpty) ? photoObj.id : null;
    final rawUrl = (photoObj != null && photoObj.rawUrl.isNotEmpty) ? photoObj.rawUrl : photoUrl;

    String relativeUrl = rawUrl;
    if (relativeUrl.startsWith('https://prem-jodo-backend.onrender.com')) {
      relativeUrl = relativeUrl.replaceFirst('https://prem-jodo-backend.onrender.com', '');
    }

    try {
      final payload = <String, dynamic>{
        if (photoId != null && photoId.isNotEmpty) 'photoId': photoId,
        'photoUrl': rawUrl,
      };

      try {
        await _apiClient.delete(
          ApiEndpoints.deletePhoto,
          data: payload,
          queryParameters: payload,
        );
      } catch (_) {
        if (relativeUrl != rawUrl) {
          await _apiClient.delete(
            ApiEndpoints.deletePhoto,
            data: {
              if (photoId != null && photoId.isNotEmpty) 'photoId': photoId,
              'photoUrl': relativeUrl,
            },
          );
        } else {
          rethrow;
        }
      }

      setState(() {
        _photos.removeAt(index);
        _deletingSlots.remove(index);
      });
      await ref.read(authProvider.notifier).checkAuthStatus();
    } catch (e) {
      debugPrint('Delete photo error: $e');
      setState(() {
        _photos.removeAt(index);
        _deletingSlots.remove(index);
      });
    }
  }

  void _makeMainPhoto(int index) {
    if (index == 0 || index >= _photos.length) return;
    setState(() {
      final selected = _photos.removeAt(index);
      _photos.insert(0, selected);
    });
  }

  // ---------------------------------------------------------------------------
  // Profile Submission (Exact Mongoose Schema Match)
  // ---------------------------------------------------------------------------
  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_calculatedAge < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 18 years old.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dobDate = DateTime.utc(_selectedYear, _selectedMonth, _selectedDay);
      final dobStr = dobDate.toIso8601String();

      // Photos array matching ProfileSchema: [{ url, isPrimary }]
      final photosPayload = _photos.asMap().entries.map((entry) {
        return {
          'url': entry.value,
          'isPrimary': entry.key == 0,
        };
      }).toList();

      final payload = {
        // User Schema
        'fullName': _nameController.text.trim(),
        'firstName': _nameController.text.trim().split(' ').first,

        // Profile Schema
        'gender': _gender,
        'showGenderOnProfile': _showGenderOnProfile,
        'dateOfBirth': dobStr,
        'birthday': {
          'month': _selectedMonth,
          'day': _selectedDay,
          'year': _selectedYear,
        },
        'interestedIn': _interestedIn,
        'lookingFor': _lookingFor,
        'bio': _bioController.text.trim(),
        'photos': photosPayload,
        'religion': _religionController.text.trim(),
        'education': _selectedEducation,
        'interests': _interests,

        // Location & Coordinates
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim().isNotEmpty
            ? _countryController.text.trim()
            : 'India',
        'latitude': _latitude,
        'longitude': _longitude,
        'coordinates': [_longitude, _latitude],

        // Partner Preferences & Max Distance (Support all backend schemas)
        'maxDistanceKm': _maxDistanceKm.toInt(),
        'maxDistance': _maxDistanceKm.toInt(),
        'partnerPreferences': {
          'maxDistanceKm': _maxDistanceKm.toInt(),
          'maxDistance': _maxDistanceKm.toInt(),
        },
      };

      final response =
          await _apiClient.put(ApiEndpoints.updateProfile, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Sync local discovery filter and storage
        final currentFilter = ref.read(discoveryProvider).filter;
        final updatedFilter = currentFilter.copyWith(maxDistance: _maxDistanceKm);
        await StorageService.saveDiscoveryFilter(updatedFilter.toJson());
        ref.read(discoveryProvider.notifier).updateFilter(updatedFilter);

        await ref.read(authProvider.notifier).checkAuthStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully! ✨'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI Builder
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0D14),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSaveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFFFB7185),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------------------
              // 1. Photos (6 Slots Grid)
              // ---------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Photos (6 Slots)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '${_photos.length}/6 Added',
                    style: const TextStyle(
                      color: Color(0xFFFB7185),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Slot 1 is your Primary profile photo. Tap any photo to set as Primary or remove.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 14),

              _buildSixPhotoSlotsGrid(),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // 2. User & Basic Details (fullName, bio)
              // ---------------------------------------------------------------
              _buildSectionHeader(
                icon: Icons.person_rounded,
                title: 'Basic Information',
                subtitle: 'Your full name and about yourself',
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _nameController,
                labelText: 'Full Name *',
                hintText: 'e.g. Priyanshu Sharma',
                prefixIcon: Icons.badge_rounded,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              _buildDateOfBirthSelector(),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _bioController,
                labelText: 'Bio (Max 500 characters)',
                hintText: 'Share a little about yourself, what you love and what you are looking for...',
                maxLines: 4,
                prefixIcon: Icons.edit_note_rounded,
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // 3. Gender & Partner Match Preferences
              // ---------------------------------------------------------------
              _buildSectionHeader(
                icon: Icons.favorite_rounded,
                title: 'Gender & Dating Preferences',
                subtitle: 'Matchmaking and dating filters',
              ),
              const SizedBox(height: 16),

              // Gender Dropdown
              _buildDropdownField(
                label: 'Gender *',
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _gender = v);
                },
              ),
              const SizedBox(height: 12),

              // Show Gender on Profile Switch
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F101A),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Show Gender on Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500),
                    ),
                    Switch(
                      value: _showGenderOnProfile,
                      activeThumbColor: const Color(0xFFF43F5E),
                      onChanged: (val) =>
                          setState(() => _showGenderOnProfile = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Interested In (Multi-select: Men, Women, Everyone)
              const Text(
                'Interested In *',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _interestedInOptions.map((opt) {
                  final isSelected = _interestedIn.contains(opt);
                  return FilterChip(
                    label: Text(opt.toUpperCase()),
                    selected: isSelected,
                    selectedColor:
                        const Color(0xFFF43F5E).withValues(alpha: 0.25),
                    backgroundColor: const Color(0xFF161826),
                    checkmarkColor: const Color(0xFFFB7185),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFFFB7185)
                          : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFF43F5E)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (!_interestedIn.contains(opt)) {
                            _interestedIn.add(opt);
                          }
                        } else {
                          if (_interestedIn.length > 1) {
                            _interestedIn.remove(opt);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Looking For (Strictly Loaded from API)
              const Text(
                'Looking For *',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _isLoadingLookingFor
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _apiLookingForOptions.isEmpty
                      ? CustomTextField(
                          controller:
                              TextEditingController(text: _lookingFor),
                          labelText: 'Looking For',
                          hintText: 'e.g. Long-term partner',
                          prefixIcon: Icons.search_rounded,
                          onChanged: (v) => _lookingFor = v,
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F101A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _apiLookingForOptions.any(
                                      (opt) => opt.matches(_lookingFor))
                                  ? _apiLookingForOptions
                                      .firstWhere(
                                          (opt) => opt.matches(_lookingFor))
                                      .value
                                  : (_apiLookingForOptions.isNotEmpty
                                      ? _apiLookingForOptions.first.value
                                      : null),
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1B1D2C),
                              icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white70),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13.5),
                              items: _apiLookingForOptions
                                  .map((opt) => DropdownMenuItem(
                                      value: opt.value,
                                      child: Text(opt.label)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _lookingFor = v);
                                }
                              },
                            ),
                          ),
                        ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // 4. Location & Geospatial Coordinates (Point: [lng, lat])
              // ---------------------------------------------------------------
              _buildSectionHeader(
                icon: Icons.location_on_rounded,
                title: 'Location & Match Radius',
                subtitle: 'GeoJSON Point coordinates for nearby discovery',
              ),
              const SizedBox(height: 16),

              // GPS Coordinates Status Banner with Refresh Button
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1F2238),
                      Color(0xFF131522),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: Color(0xFFFB7185), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPS Coordinates',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lat: ${_latitude.toStringAsFixed(4)}, Lng: ${_longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed:
                          _isFetchingLocation ? null : _detectCurrentLocation,
                      child: _isFetchingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Auto GPS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _cityController,
                labelText: 'City *',
                hintText: 'e.g. Mumbai, New Delhi',
                prefixIcon: Icons.location_city_rounded,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'City is required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _stateController,
                      labelText: 'State',
                      hintText: 'e.g. Maharashtra',
                      prefixIcon: Icons.map_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _countryController,
                      labelText: 'Country',
                      hintText: 'e.g. India',
                      prefixIcon: Icons.public_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Match Distance Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Max Distance Radius',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_maxDistanceKm.toInt()} km',
                    style: const TextStyle(
                      color: Color(0xFFFB7185),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _maxDistanceKm,
                min: 5,
                max: 200,
                divisions: 39,
                activeColor: const Color(0xFFF43F5E),
                inactiveColor: Colors.white12,
                onChanged: (val) => setState(() => _maxDistanceKm = val),
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // 5. Schema Details: Education & Religion
              // ---------------------------------------------------------------
              _buildSectionHeader(
                icon: Icons.school_rounded,
                title: 'Education & Religion',
                subtitle: 'Profile schema background information',
              ),
              const SizedBox(height: 16),

              _buildDropdownField(
                label: 'Highest Education *',
                value: _selectedEducation,
                items: AppConstants.educationOptions
                    .map((edu) => DropdownMenuItem(value: edu, child: Text(edu)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedEducation = v;
                      _educationController.text = v;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              _buildDropdownField(
                label: 'Religion *',
                value: _selectedReligion,
                items: AppConstants.religionOptions
                    .map((rel) => DropdownMenuItem(value: rel, child: Text(rel)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedReligion = v;
                      _religionController.text = v;
                    });
                  }
                },
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // 6. Interests (Strictly from API)
              // ---------------------------------------------------------------
              _buildSectionHeader(
                icon: Icons.interests_rounded,
                title: 'Interests & Passions',
                subtitle: 'Tags fetched from server',
              ),
              const SizedBox(height: 14),

              _isLoadingInterests
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _apiInterests.isEmpty
                      ? const Text(
                          'No interests available from server at the moment.',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _apiInterests.map((interestOpt) {
                            final isSelected = _interests.any(
                                (it) => interestOpt.matches(it));
                            return FilterChip(
                              label: Text(interestOpt.label),
                              selected: isSelected,
                              selectedColor: const Color(0xFFF43F5E)
                                  .withValues(alpha: 0.25),
                              backgroundColor: const Color(0xFF161826),
                              checkmarkColor: const Color(0xFFFB7185),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFFB7185)
                                    : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFFF43F5E)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    if (!_interests.any((it) =>
                                        interestOpt.matches(it))) {
                                      _interests.add(interestOpt.value);
                                    }
                                  } else {
                                    _interests.removeWhere((it) =>
                                        interestOpt.matches(it));
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFB7185), size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      ],
    );
  }

  /// 6 Photo Slots in 3x2 Grid matching web style
  Widget _buildSixPhotoSlotsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemCount: 6,
      itemBuilder: (context, slotIndex) {
        final isUploading = _uploadingSlots.contains(slotIndex);
        final isDeleting = _deletingSlots.contains(slotIndex);
        final hasPhoto = slotIndex < _photos.length;
        final isMain = slotIndex == 0 && hasPhoto;

        if (isUploading) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161826),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFFF43F5E),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (hasPhoto) {
          final photoPath = _photos[slotIndex];

          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161826),
                    border: Border.all(
                      color: isMain
                          ? const Color(0xFFF43F5E)
                          : Colors.white.withValues(alpha: 0.12),
                      width: isMain ? 2 : 1,
                    ),
                  ),
                  child: _buildSlotImage(photoPath),
                ),
              ),

              // Main Photo Badge
              if (isMain)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'MAIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Set as Main button
              if (!isMain && !isDeleting)
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: GestureDetector(
                    onTap: () => _makeMainPhoto(slotIndex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Set Main',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // Delete Photo / Deleting state
              if (isDeleting)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFF43F5E),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _removePhoto(slotIndex),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 13, color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        } else {
          return GestureDetector(
            onTap: () => _openPhotoOptionsModal(slotIndex),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141624),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  style: BorderStyle.solid,
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFF43F5E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_rounded,
                      color: Color(0xFFFB7185),
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    slotIndex == 0
                        ? 'Slot 1 (Main)'
                        : 'Slot ${slotIndex + 1}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSlotImage(String photoPath) {
    if (photoPath.trim().isEmpty) {
      return _buildImagePlaceholder();
    }

    final resolvedUrl = ImageHelper.resolveImageUrl(photoPath);
    final isNetwork = resolvedUrl.startsWith('http://') ||
        resolvedUrl.startsWith('https://') ||
        resolvedUrl.startsWith('data:');

    if (!isNetwork) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        );
      }
      return _buildImagePlaceholder();
    }

    final targetUrl = isNetwork ? resolvedUrl : photoPath;
    if (targetUrl.isEmpty) {
      return _buildImagePlaceholder();
    }

    return Image.network(
      targetUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final total = loadingProgress.expectedTotalBytes;
        final loaded = loadingProgress.cumulativeBytesLoaded;
        return Container(
          color: const Color(0xFF161826),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: (total != null && total > 0) ? loaded / total : null,
                strokeWidth: 2,
                color: const Color(0xFFF43F5E),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFF161826),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 24),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0F101A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.any((it) => it.value == value)
                  ? value
                  : items.first.value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1B1D2C),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70),
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateOfBirthSelector() {
    final months = [
      'January (01)',
      'February (02)',
      'March (03)',
      'April (04)',
      'May (05)',
      'June (06)',
      'July (07)',
      'August (08)',
      'September (09)',
      'October (10)',
      'November (11)',
      'December (12)',
    ];

    final currentYear = DateTime.now().year;
    final years =
        List.generate(65, (index) => (currentYear - 18) - index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Date of Birth (MM - DD - YYYY) *',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_calculatedAge Years Old',
                style: const TextStyle(
                  color: Color(0xFFFB7185),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F101A),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1B1D2C),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: List.generate(12, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(months[i]),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonth = val);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F101A),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedDay,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1B1D2C),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: List.generate(31, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'.padLeft(2, '0')),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F101A),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1B1D2C),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: years.map((y) {
                      return DropdownMenuItem(
                        value: y,
                        child: Text('$y'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedYear = val);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
