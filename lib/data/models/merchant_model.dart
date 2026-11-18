import 'package:cloud_firestore/cloud_firestore.dart';

/// Merchant data model representing an FMCG retail grocery/kiosk merchant on Khazeen.
///
/// Stored in Firestore at `users/{uid}` with `role: 'merchant'`.
class MerchantModel {
  /// Firebase Auth uid (also the `users` document id).
  final String id;
  final String merchantName;
  final String storeName;

  /// Local Egyptian format, e.g. `01012345678`.
  final String phone;
  final String category;
  final String governorate;
  final String city;
  final String address;
  final String? landmark;
  final String? commercialRegister;
  final double? latitude;
  final double? longitude;

  /// Download URLs of the store photos (Firebase Storage), when taken.
  final String? exteriorPhotoUrl;
  final String? interiorPhotoUrl;
  final DateTime registeredAt;

  const MerchantModel({
    required this.id,
    required this.merchantName,
    required this.storeName,
    required this.phone,
    this.category = 'سوبر ماركت',
    required this.governorate,
    required this.city,
    required this.address,
    this.landmark,
    this.commercialRegister,
    this.latitude,
    this.longitude,
    this.exteriorPhotoUrl,
    this.interiorPhotoUrl,
    required this.registeredAt,
  });

  static const String role = 'merchant';

  /// Formatted location string
  String get fullLocation => '$governorate - $city';

  /// Fields written to `users/{uid}`. `created_at` is set by the repository
  /// with a server timestamp, so it is not included here.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': id,
      'role': role,
      'business_name': storeName,
      'owner_name': merchantName,
      'phone_number': toE164(phone),
      'store_category': category,
      'governorate': governorate,
      'city': city,
      'address': address,
      'landmark': landmark,
      'commercial_register': commercialRegister,
      'latitude': latitude,
      'longitude': longitude,
      if (exteriorPhotoUrl != null) 'exterior_photo_url': exteriorPhotoUrl,
      if (interiorPhotoUrl != null) 'interior_photo_url': interiorPhotoUrl,
    };
  }

  factory MerchantModel.fromFirestore(String uid, Map<String, dynamic> data) {
    final createdAt = data['created_at'];
    return MerchantModel(
      id: uid,
      merchantName: data['owner_name']?.toString() ?? '',
      storeName: data['business_name']?.toString() ?? '',
      phone: toLocal(data['phone_number']?.toString() ?? ''),
      category: data['store_category']?.toString() ?? 'سوبر ماركت',
      governorate: data['governorate']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      landmark: data['landmark']?.toString(),
      commercialRegister: data['commercial_register']?.toString(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      exteriorPhotoUrl: data['exterior_photo_url']?.toString(),
      interiorPhotoUrl: data['interior_photo_url']?.toString(),
      registeredAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.now(),
    );
  }

  /// `01012345678` -> `+201012345678`. Values already in E.164 are kept.
  static String toE164(String phone) {
    final p = phone.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('0020')) return '+${p.substring(2)}';
    if (p.startsWith('0')) return '+20${p.substring(1)}';
    return '+20$p';
  }

  /// `+201012345678` -> `01012345678`.
  static String toLocal(String phone) {
    final p = phone.trim();
    if (p.startsWith('+20')) return '0${p.substring(3)}';
    return p;
  }
}
