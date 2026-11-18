import 'package:flutter/foundation.dart';

import '../../../core/constants/store_categories.dart';
import '../../../data/models/merchant_model.dart';
import '../../../data/repositories/auth_repository.dart';

/// State for the multi-step merchant registration wizard, which runs after
/// the phone number was verified and saves the profile to `users/{uid}`.
class OnboardingViewModel extends ChangeNotifier {
  // Steps: 0 basic info, 1 category, 2 map location, 3 address,
  // 4 storefront photo, 5 inside photo, 6 done.
  static const int totalSteps = 6;
  static const int doneStep = 6;

  /// Map center before the merchant moves it or uses GPS (Cairo).
  static const double defaultLatitude = 30.0444;
  static const double defaultLongitude = 31.2357;

  int _currentStep = 0;
  int get currentStep => _currentStep;

  // Step 1: basic information
  String _fullName = '';
  String get fullName => _fullName;

  String _storeName = '';
  String get storeName => _storeName;

  // Step 2: store category
  String _selectedCategory = StoreCategories.list.first.name;
  String get selectedCategory => _selectedCategory;

  String _categorySearchQuery = '';
  String get categorySearchQuery => _categorySearchQuery;

  List<StoreCategory> get filteredCategories =>
      StoreCategories.search(_categorySearchQuery);

  // Step 3: store location (the map center when the merchant continues)
  double _latitude = defaultLatitude;
  double get latitude => _latitude;

  double _longitude = defaultLongitude;
  double get longitude => _longitude;

  // Step 4: address
  String? _governorate;
  String? get governorate => _governorate;

  String _city = '';
  String get city => _city;

  String _detailedAddress = '';
  String get detailedAddress => _detailedAddress;

  String _landmark = '';
  String get landmark => _landmark;

  // Steps 5-6: store photos (JPEG bytes, optional)
  Uint8List? _exteriorPhoto;
  Uint8List? get exteriorPhoto => _exteriorPhoto;

  Uint8List? _interiorPhoto;
  Uint8List? get interiorPhoto => _interiorPhoto;

  MerchantModel? _authenticatedMerchant;
  MerchantModel? get authenticatedMerchant => _authenticatedMerchant;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _stepError;
  String? get stepError => _stepError;

  // ----------------------------------------------------
  // Step actions
  // ----------------------------------------------------
  void setBasicInfo({required String fullName, required String storeName}) {
    _fullName = fullName.trim();
    _storeName = storeName.trim();
    _stepError = null;
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void updateCategorySearch(String query) {
    _categorySearchQuery = query;
    notifyListeners();
  }

  void setMapCoordinates(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
    notifyListeners();
  }

  void setAddressDetails({
    required String? governorate,
    required String city,
    required String address,
    String landmark = '',
  }) {
    _governorate = governorate;
    _city = city.trim();
    _detailedAddress = address.trim();
    _landmark = landmark.trim();
    _stepError = null;
    notifyListeners();
  }

  void setExteriorPhoto(Uint8List? bytes) {
    _exteriorPhoto = bytes;
    _stepError = null;
    notifyListeners();
  }

  void setInteriorPhoto(Uint8List? bytes) {
    _interiorPhoto = bytes;
    _stepError = null;
    notifyListeners();
  }

  /// Error shown on the current step, e.g. when the camera fails.
  void showStepError(String message) {
    _stepError = message;
    notifyListeners();
  }

  bool validateCurrentStep() {
    _stepError = null;
    final error = switch (_currentStep) {
      0 when _fullName.length < 3 => 'اكتب اسمك بالكامل (3 حروف على الأقل)',
      0 when _storeName.length < 2 => 'اكتب اسم المحل',
      1 when _selectedCategory.isEmpty => 'اختار نوع النشاط',
      3 when _governorate == null => 'اختار المحافظة',
      3 when _city.length < 2 => 'اكتب المدينة أو الحي',
      3 when _detailedAddress.length < 5 =>
        'اكتب العنوان بالتفصيل (5 حروف على الأقل)',
      _ => null,
    };
    if (error != null) {
      _stepError = error;
      notifyListeners();
      return false;
    }
    return true;
  }

  bool nextStep() {
    if (!validateCurrentStep()) return false;
    if (_currentStep < totalSteps) {
      _currentStep++;
      _stepError = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _stepError = null;
      notifyListeners();
    }
  }

  /// Uploads the photos, saves the merchant profile for the signed-in user
  /// and shows the success step. On failure keeps the current step and sets
  /// [stepError]. Pass [withPhotos] false to register without the photos.
  Future<bool> completeRegistration({bool withPhotos = true}) async {
    _isSubmitting = true;
    _stepError = null;
    notifyListeners();

    final draft = MerchantModel(
      id: '',
      merchantName: _fullName,
      storeName: _storeName,
      phone: '',
      category: _selectedCategory,
      governorate: _governorate ?? '',
      city: _city,
      address: _detailedAddress,
      landmark: _landmark.isNotEmpty ? _landmark : null,
      latitude: _latitude,
      longitude: _longitude,
      registeredAt: DateTime.now(),
    );

    try {
      _authenticatedMerchant = await AuthRepository.instance.registerMerchant(
        draft,
        exteriorPhoto: withPhotos ? _exteriorPhoto : null,
        interiorPhoto: withPhotos ? _interiorPhoto : null,
      );
    } on AuthFailure catch (e) {
      _stepError = e.message;
      _isSubmitting = false;
      notifyListeners();
      return false;
    }

    _currentStep = doneStep;
    _isSubmitting = false;
    notifyListeners();
    return true;
  }
}
