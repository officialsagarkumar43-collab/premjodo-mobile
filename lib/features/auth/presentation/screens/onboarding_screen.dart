import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:prem_jodo_mobile/core/constants/api_endpoints.dart';
import 'package:prem_jodo_mobile/core/constants/app_colors.dart';
import 'package:prem_jodo_mobile/core/constants/app_constants.dart';
import 'package:prem_jodo_mobile/core/network/api_client.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_button.dart';
import 'package:prem_jodo_mobile/core/widgets/custom_text_field.dart';
import 'package:prem_jodo_mobile/core/models/option_item.dart';
import 'package:prem_jodo_mobile/core/utils/image_helper.dart';
import 'package:prem_jodo_mobile/core/utils/location_service.dart';
import 'package:prem_jodo_mobile/features/auth/data/models/user_model.dart';
import 'package:prem_jodo_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:prem_jodo_mobile/features/navigation/screens/main_navigation_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  final Set<int> _uploadingSlots = {};
  final Set<int> _deletingSlots = {};

  // Step 1: Basic Info & Mongoose Schema Fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController =
      TextEditingController(text: 'India');
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();

  String _selectedGender = 'female';
  bool _showGenderOnProfile = true;
  List<String> _interestedIn = ['men'];
  String _lookingFor = '';
  String _selectedEducation = AppConstants.educationOptions.first;
  String _selectedReligion = AppConstants.religionOptions.first;
  int _selectedMonth = 1; // 1 - 12 (MM)
  int _selectedDay = 15; // 1 - 31 (DD)
  int _selectedYear = 2000; // YYYY

  // Location Coordinates: [longitude, latitude]
  double _latitude = 0;
  double _longitude = 0;
  bool _isFetchingLocation = false;

  int get _calculatedAge {
    final now = DateTime.now();
    int age = now.year - _selectedYear;
    if (now.month < _selectedMonth ||
        (now.month == _selectedMonth && now.day < _selectedDay)) {
      age--;
    }
    return age > 0 ? age : 18;
  }

  // Step 2: Interests & Bio
  final TextEditingController _bioController = TextEditingController();
  List<OptionItem> _availableInterests = [];
  List<OptionItem> _lookingForOptions = [];
  bool _isLoadingOptions = true;
  final Set<String> _selectedInterests = {};

  // Step 3: Photos (6 Slots)
  final List<String> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      if (user.name.isNotEmpty && user.name != 'Prem Jodo User') {
        _nameController.text = user.name;
      }
      if (user.city != null && user.city!.isNotEmpty) {
        _cityController.text = user.city!;
      }
      if (user.state != null && user.state!.isNotEmpty) {
        _stateController.text = user.state!;
      }
      if (user.education != null &&
          AppConstants.educationOptions.contains(user.education)) {
        _selectedEducation = user.education!;
        _educationController.text = user.education!;
      }
      if (user.religion != null &&
          AppConstants.religionOptions.contains(user.religion)) {
        _selectedReligion = user.religion!;
        _religionController.text = user.religion!;
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
      if (user.interests.isNotEmpty) {
        _selectedInterests.addAll(user.interests);
      }
      if (user.photos.isNotEmpty) {
        _photos.addAll(user.photos);
      }
    }
    _loadOptions();
    _autoDetectLocationSilently();
  }

  Future<void> _autoDetectLocationSilently() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
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
              '📍 GPS Location set: (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() => _isFetchingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not fetch GPS. Please check location permissions.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadOptions() async {
    final apiClient = ApiClient();
    List<OptionItem> interestsList = [];
    List<OptionItem> lookingForList = [];

    try {
      final res = await apiClient.get(ApiEndpoints.getInterests);
      if (res.statusCode == 200 && res.data != null) {
        final resData = res.data;
        final list = (resData is Map && resData['data'] != null)
            ? resData['data']
            : (resData is Map && resData['interests'] != null
                ? resData['interests']
                : resData);
        if (list is List) {
          for (var item in list) {
            final opt = OptionItem.fromDynamic(item);
            if (opt.value.isNotEmpty &&
                !interestsList.any((it) => it.matches(opt.value))) {
              interestsList.add(opt);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final res = await apiClient.get(ApiEndpoints.getLookingForOptions);
      if (res.statusCode == 200 && res.data != null) {
        final resData = res.data;
        final list = (resData is Map && resData['data'] != null)
            ? resData['data']
            : (resData is Map && resData['options'] != null
                ? resData['options']
                : resData);
        if (list is List) {
          for (var item in list) {
            final opt = OptionItem.fromDynamic(item);
            if (opt.value.isNotEmpty &&
                !lookingForList.any((it) => it.matches(opt.value))) {
              lookingForList.add(opt);
            }
          }
        }
      }
    } catch (_) {}

    // Merge any existing selected interests
    for (final sel in _selectedInterests) {
      if (sel.trim().isNotEmpty &&
          !interestsList.any((it) => it.matches(sel))) {
        interestsList.add(OptionItem(label: sel, value: sel));
      }
    }

    if (mounted) {
      setState(() {
        _availableInterests = interestsList;
        _lookingForOptions = lookingForList;
        if (!_lookingForOptions.any((it) => it.matches(_lookingFor)) &&
            _lookingForOptions.isNotEmpty) {
          _lookingFor = _lookingForOptions.first.value;
        }
        _isLoadingOptions = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
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

    final apiClient = ApiClient();
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
          await apiClient.post(ApiEndpoints.uploadPhotos, data: formData);

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
                    ? (resData['data']['url'] ?? resData['data']['photoUrl'])
                    : null);
            if (single != null && single.toString().isNotEmpty) {
              uploadedUrls.add(ImageHelper.resolveImageUrl(single));
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
      debugPrint('Upload photo error: $e');
      setState(() {
        _uploadingSlots.removeAll(targetSlots);
        for (final x in toUpload) {
          if (_photos.length < 6) _photos.add(x.path);
        }
      });
    }
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
            (p.id.isNotEmpty &&
                (p.id == photoUrl ||
                    (index < user.photoObjects.length &&
                        user.photoObjects[index].id == p.id)))) {
          photoObj = p;
          break;
        }
      }
      photoObj ??=
          (index < user.photoObjects.length ? user.photoObjects[index] : null);
    }

    final photoId =
        (photoObj != null && photoObj.id.isNotEmpty) ? photoObj.id : null;
    final rawUrl = (photoObj != null && photoObj.rawUrl.isNotEmpty)
        ? photoObj.rawUrl
        : photoUrl;

    String relativeUrl = rawUrl;
    if (relativeUrl.startsWith('https://prem-jodo-backend.onrender.com')) {
      relativeUrl = relativeUrl.replaceFirst(
          'https://prem-jodo-backend.onrender.com', '');
    }

    final apiClient = ApiClient();
    try {
      final payload = <String, dynamic>{
        if (photoId != null && photoId.isNotEmpty) 'photoId': photoId,
        'photoUrl': rawUrl,
      };

      try {
        await apiClient.delete(
          ApiEndpoints.deletePhoto,
          data: payload,
          queryParameters: payload,
        );
      } catch (_) {
        if (relativeUrl != rawUrl) {
          await apiClient.delete(
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

  void _nextPage() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter your full name'),
              backgroundColor: AppColors.error),
        );
        return;
      }
      if (_calculatedAge < 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('You must be at least 18 years old to join Prem Jodo'),
              backgroundColor: AppColors.error),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _submitOnboarding();
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitOnboarding() async {
    setState(() => _isLoading = true);
    final apiClient = ApiClient();

    try {
      // 1. Upload any local/pending photos before calling onboarding API
      final localPhotos = _photos.where((p) {
        return !p.startsWith('http://') &&
            !p.startsWith('https://') &&
            !p.startsWith('data:');
      }).toList();

      if (localPhotos.isNotEmpty) {
        try {
          final formData = FormData();
          for (final lp in localPhotos) {
            final file = File(lp);
            if (file.existsSync()) {
              formData.files.add(MapEntry(
                'photos',
                await MultipartFile.fromFile(file.path,
                    filename: file.path.split(Platform.pathSeparator).last),
              ));
            }
          }

          if (formData.files.isNotEmpty) {
            final uploadRes =
                await apiClient.post(ApiEndpoints.uploadPhotos, data: formData);
            debugPrint(
                'Submit upload photos response: ${uploadRes.statusCode} ${uploadRes.data}');

            if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
              final resData = uploadRes.data;
              List<String> serverUrls = [];
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
                    if (resolved.isNotEmpty) serverUrls.add(resolved);
                  }
                } else {
                  final single = resData['photoUrl'] ??
                      resData['url'] ??
                      (resData['data'] is Map
                          ? (resData['data']['url'] ??
                              resData['data']['photoUrl'])
                          : null);
                  if (single != null && single.toString().isNotEmpty) {
                    serverUrls.add(ImageHelper.resolveImageUrl(single));
                  }
                }
              }

              if (serverUrls.isNotEmpty) {
                int sIdx = 0;
                for (int i = 0; i < _photos.length; i++) {
                  if (localPhotos.contains(_photos[i]) &&
                      sIdx < serverUrls.length) {
                    _photos[i] = serverUrls[sIdx++];
                  }
                }
              }
            }
          }
        } catch (uploadErr) {
          debugPrint('Upload photos during submit error: $uploadErr');
        }
      }

      final validUrls = _photos.where((p) {
        return p.startsWith('http://') ||
            p.startsWith('https://') ||
            p.startsWith('data:');
      }).toList();

      final dobDate = DateTime.utc(_selectedYear, _selectedMonth, _selectedDay);
      final dobStr = dobDate.toIso8601String();
      final safeLng = _longitude != 0 ? _longitude : 0;
      final safeLat = _latitude != 0 ? _latitude : 0;

      final payload = {
        // User Model
        'fullName': _nameController.text.trim(),
        'firstName': _nameController.text.trim().split(' ').first,
        'isOnboarded': true,

        // Profile Model
        'gender': _selectedGender.toLowerCase(),
        'showGenderOnProfile': _showGenderOnProfile,
        'dateOfBirth': dobStr,
        'age': _calculatedAge,
        'birthday': {
          'month': _selectedMonth,
          'day': _selectedDay,
          'year': _selectedYear,
        },
        'birthYear': _selectedYear,
        'birthMonth': _selectedMonth,
        'birthDay': _selectedDay,
        'interestedIn': _interestedIn,
        'lookingFor': _lookingFor,
        'bio': _bioController.text.trim(),
        'religion': _religionController.text.trim().isNotEmpty
            ? _religionController.text.trim()
            : _selectedReligion,
        'education': _selectedEducation,
        'interests': _selectedInterests.toList(),

        // Location & Coordinates (Clean fields without conflicting nested 'location' key)
        'city': _cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : 'New Delhi',
        'state': _stateController.text.trim().isNotEmpty
            ? _stateController.text.trim()
            : 'Delhi',
        'country': _countryController.text.trim().isNotEmpty
            ? _countryController.text.trim()
            : 'India',
        'latitude': safeLat,
        'longitude': safeLng,
        'coordinates': [safeLng, safeLat],

        'photos': validUrls.isNotEmpty
            ? validUrls.asMap().entries.map((entry) {
                return {
                  'url': entry.value,
                  'isPrimary': entry.key == 0,
                };
              }).toList()
            : _photos.asMap().entries.map((entry) {
                return {
                  'url': entry.value,
                  'isPrimary': entry.key == 0,
                };
              }).toList(),

        'partnerPreferences': {
          'maxDistanceKm': 50,
        },
      };

      debugPrint('Submitting onboarding payload: $payload');
      await apiClient.post(ApiEndpoints.onboarding, data: payload);

      // Refresh Auth Profile
      await ref.read(authProvider.notifier).checkAuthStatus();

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      String errorMessage = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          errorMessage = data['message'].toString();
        } else if (data is Map && data['error'] != null) {
          errorMessage = data['error'].toString();
        } else if (e.response?.statusMessage != null) {
          errorMessage =
              '${e.response?.statusMessage} (${e.response?.statusCode})';
        }
        debugPrint(
            'Onboarding backend error response: ${e.response?.statusCode} -> ${e.response?.data}');
      }
      debugPrint('Onboarding error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Onboarding failed: $errorMessage'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: _previousPage,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BasicInfo(),
                  _buildStep2InterestsAndBio(),
                  _buildStep3Photos(),
                ],
              ),
            ),
            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.all(24),
              child: CustomButton(
                text: _currentStep == 2 ? 'Get Started 💖' : 'Continue',
                isLoading: _isLoading,
                icon: _currentStep == 2
                    ? Icons.check_circle_outline
                    : Icons.arrow_forward_rounded,
                onPressed: _isLoading ? null : _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'About You 👤',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us about yourself to find matches curated for you.',
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
          ),
          const SizedBox(height: 24),
          CustomTextField(
            controller: _nameController,
            labelText: 'Full Name *',
            hintText: 'e.g. Priya Sharma',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 18),
          _buildDateOfBirthSelector(),
          const SizedBox(height: 18),

          // GPS Coordinates Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Coordinates',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Lat: ${_latitude.toStringAsFixed(3)}, Lng: ${_longitude.toStringAsFixed(3)}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: _isFetchingLocation
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.gps_fixed, size: 16),
                  label: const Text('Auto GPS',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed:
                      _isFetchingLocation ? null : _detectCurrentLocation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            controller: _cityController,
            labelText: 'City / Location *',
            hintText: 'e.g. Mumbai, Maharashtra',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 16),

          const Text(
            'Education Degree *',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedEducation,
                isExpanded: true,
                dropdownColor: AppColors.darkCard,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                items: AppConstants.educationOptions
                    .map(
                        (edu) => DropdownMenuItem(value: edu, child: Text(edu)))
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
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Religion *',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReligion,
                isExpanded: true,
                dropdownColor: AppColors.darkCard,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                items: AppConstants.religionOptions
                    .map(
                        (rel) => DropdownMenuItem(value: rel, child: Text(rel)))
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
            ),
          ),
          const SizedBox(height: 24),

          const Text('Gender *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildGenderChip('female', 'Female 👩', Icons.female),
              const SizedBox(width: 12),
              _buildGenderChip('male', 'Male 👨', Icons.male),
              const SizedBox(width: 12),
              _buildGenderChip('other', 'Other ✨', Icons.transgender),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Show Gender on Profile',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Switch(
                  value: _showGenderOnProfile,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) =>
                      setState(() => _showGenderOnProfile = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Interested In *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['men', 'women', 'everyone'].map((opt) {
              final isSelected = _interestedIn.contains(opt);
              return FilterChip(
                label: Text(opt.toUpperCase()),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.25),
                backgroundColor: AppColors.darkSurface,
                checkmarkColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primaryLight : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (!_interestedIn.contains(opt)) {
                        _interestedIn = [..._interestedIn, opt];
                      }
                    } else {
                      if (_interestedIn.length > 1) {
                        _interestedIn =
                            _interestedIn.where((e) => e != opt).toList();
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          const Text('Looking For *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          _isLoadingOptions
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _lookingForOptions.map((option) {
                    final isSelected = option.matches(_lookingFor);
                    return ChoiceChip(
                      label: Text(option.label),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.darkSurface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _lookingFor = option.value);
                        }
                      },
                    );
                  }).toList(),
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.white12,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.primary : Colors.white60,
                  size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2InterestsAndBio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Your Interests & Bio ✨',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pick 3 or more passions and write a catchy bio.',
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Text('Select Interests (Pick at least 3)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          _isLoadingOptions
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableInterests.map((interestOpt) {
                    final isSelected =
                        _selectedInterests.any((it) => interestOpt.matches(it));
                    return FilterChip(
                      label: Text(interestOpt.label),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      backgroundColor: AppColors.darkSurface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_selectedInterests
                                .any((it) => interestOpt.matches(it))) {
                              _selectedInterests.add(interestOpt.value);
                            }
                          } else {
                            _selectedInterests
                                .removeWhere((it) => interestOpt.matches(it));
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
          const SizedBox(height: 24),
          const Text('About Me (Bio)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText:
                  'Write a short description about yourself, your hobbies or what you enjoy...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppColors.darkSurface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Photos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Upload Photos (6 Slots) 📸',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add at least 1 clear photo. Profiles with photos get 10x more matches!',
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final isUploading = _uploadingSlots.contains(index);
              final isDeleting = _deletingSlots.contains(index);
              final hasPhoto = index < _photos.length;
              final isMain = index == 0 && hasPhoto;

              if (isUploading) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
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
                            color: AppColors.primary,
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
                final photoPath = _photos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          border: Border.all(
                            color: isMain
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.12),
                            width: isMain ? 2 : 1,
                          ),
                        ),
                        child: _buildSlotImage(photoPath),
                      ),
                    ),
                    if (isMain)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
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
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.black87, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                  ],
                );
              } else {
                return GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined,
                            color: AppColors.primaryLight, size: 28),
                        const SizedBox(height: 4),
                        Text(index == 0 ? 'Slot 1 (Main)' : 'Slot ${index + 1}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlotImage(String photoPath) {
    if (photoPath.trim().isEmpty) {
      return const Center(
        child:
            Icon(Icons.broken_image_rounded, color: Colors.white38, size: 24),
      );
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
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded,
                color: Colors.white38, size: 24),
          ),
        );
      }
      return const Center(
        child:
            Icon(Icons.broken_image_rounded, color: Colors.white38, size: 24),
      );
    }

    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child:
            Icon(Icons.broken_image_rounded, color: Colors.white38, size: 24),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateOfBirthSelector() {
    final months = [
      {'val': 1, 'label': '01 - Jan'},
      {'val': 2, 'label': '02 - Feb'},
      {'val': 3, 'label': '03 - Mar'},
      {'val': 4, 'label': '04 - Apr'},
      {'val': 5, 'label': '05 - May'},
      {'val': 6, 'label': '06 - Jun'},
      {'val': 7, 'label': '07 - Jul'},
      {'val': 8, 'label': '08 - Aug'},
      {'val': 9, 'label': '09 - Sep'},
      {'val': 10, 'label': '10 - Oct'},
      {'val': 11, 'label': '11 - Nov'},
      {'val': 12, 'label': '12 - Dec'},
    ];
    final currentYear = DateTime.now().year;
    final maxYear = currentYear - 18;
    final years = List.generate(65, (index) => maxYear - index);
    final days = List.generate(31, (index) => index + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Date of Birth (MM - DD - YYYY) *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$_calculatedAge Years',
                style: const TextStyle(
                  color: AppColors.primaryLight,
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
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    dropdownColor: AppColors.darkCard,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: months.map((m) {
                      return DropdownMenuItem<int>(
                        value: m['val'] as int,
                        child: Text(m['label'] as String),
                      );
                    }).toList(),
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
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedDay,
                    dropdownColor: AppColors.darkCard,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: days.map((d) {
                      return DropdownMenuItem<int>(
                        value: d,
                        child: Text(d.toString().padLeft(2, '0')),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDay = val);
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
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    dropdownColor: AppColors.darkCard,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: years.map((y) {
                      return DropdownMenuItem<int>(
                        value: y,
                        child: Text(y.toString()),
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
