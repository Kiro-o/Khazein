import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/merchant_model.dart';

/// Auth or profile failure carrying an Arabic, user-facing [message].
class AuthFailure implements Exception {
  final String code;
  final String message;

  const AuthFailure(this.code, this.message);

  factory AuthFailure.fromFirebase(FirebaseAuthException e) {
    debugPrint('FirebaseAuthException: ${e.code} ${e.message}');
    final message = switch (e.code) {
      'invalid-phone-number' => 'رقم الهاتف غير صحيح، تأكد منه وحاول مرة أخرى',
      'invalid-verification-code' => 'رمز التحقق غير صحيح',
      'invalid-verification-id' ||
      'session-expired' ||
      'code-expired' => 'انتهت صلاحية رمز التحقق، اطلب رمزاً جديداً',
      'too-many-requests' =>
        'محاولات كثيرة من هذا الجهاز، حاول مرة أخرى بعد قليل',
      'quota-exceeded' =>
        'تم تجاوز الحد المسموح لرسائل التحقق، حاول مرة أخرى لاحقاً',
      'network-request-failed' =>
        'تعذر الاتصال بالإنترنت، تأكد من الشبكة وحاول مرة أخرى',
      'user-disabled' => 'تم إيقاف هذا الحساب، تواصل مع خدمة العملاء',
      'operation-not-allowed' =>
        'تسجيل الدخول برقم الهاتف غير متاح حالياً، تواصل مع خدمة العملاء',
      _ => 'حدث خطأ أثناء التحقق، حاول مرة أخرى',
    };
    return AuthFailure(e.code, message);
  }

  @override
  String toString() => message;
}

/// An OTP request in progress, returned by [AuthRepository.sendOtp].
class PhoneVerification {
  /// Local Egyptian format, e.g. `01012345678`.
  final String phone;
  final String? _verificationId;
  final int? _resendToken;
  final ConfirmationResult? _webConfirmation;

  /// True when Android verified the number instantly (no SMS code needed):
  /// the user is already signed in when [AuthRepository.sendOtp] returns.
  final bool autoVerified;

  final Completer<void> _autoSignIn;

  PhoneVerification._({
    required this.phone,
    required this._autoSignIn,
    this._verificationId,
    this._resendToken,
    this._webConfirmation,
    this.autoVerified = false,
  });

  /// Completes if Android reads the SMS by itself after the code was sent
  /// and signs the user in, so the OTP screen can continue without input.
  Future<void> get autoSignedIn => _autoSignIn.future;
}

/// Uploads JPEG [bytes] to Firebase Storage at [path] and returns the
/// download URL.
typedef StorePhotoUploader = Future<String> Function(
  String path,
  Uint8List bytes,
);

/// Merchant authentication (Firebase phone OTP) and the merchant profile
/// stored in Firestore at `users/{uid}`.
///
/// Sessions are persisted by Firebase Auth itself; there is no local
/// user store or password.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    StorePhotoUploader? uploadPhoto,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _uploadOverride = uploadPhoto;

  static AuthRepository _instance = AuthRepository();
  static AuthRepository get instance => _instance;

  /// Replaces the shared instance (tests inject fake Firebase backends).
  @visibleForTesting
  static set instance(AuthRepository repository) => _instance = repository;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final StorePhotoUploader? _uploadOverride;

  // Resolved lazily so the repository can exist before Firebase.initializeApp.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static const Duration _writeTimeout = Duration(seconds: 20);

  /// Photos are larger than profile writes, so slow networks get longer.
  static const Duration _uploadTimeout = Duration(seconds: 90);

  Future<String> _uploadPhoto(String path, Uint8List bytes) {
    final upload = _uploadOverride;
    if (upload != null) return upload(path, bytes);
    return _uploadToStorage(path, bytes);
  }

  static Future<String> _uploadToStorage(String path, Uint8List bytes) async {
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  MerchantModel? _currentMerchant;

  /// Profile of the signed-in merchant, once [loadCurrentMerchant] or
  /// [registerMerchant] has run.
  MerchantModel? get currentMerchant => _currentMerchant;

  User? get currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// Sends an SMS code to [phone] (local format `01xxxxxxxxx`).
  ///
  /// Pass the previous [resendFrom] to request another code for the same
  /// number. Throws [AuthFailure].
  Future<PhoneVerification> sendOtp(
    String phone, {
    PhoneVerification? resendFrom,
  }) async {
    final e164 = MerchantModel.toE164(phone);
    final autoSignIn = Completer<void>();

    try {
      if (kIsWeb) {
        // Shows an invisible reCAPTCHA, then sends the SMS.
        final confirmation = await _auth.signInWithPhoneNumber(e164);
        return PhoneVerification._(
          phone: phone,
          autoSignIn: autoSignIn,
          webConfirmation: confirmation,
        );
      }

      final result = Completer<PhoneVerification>();
      await _auth.verifyPhoneNumber(
        phoneNumber: e164,
        forceResendingToken: resendFrom?._resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // Android only: instant verification or SMS auto-retrieval.
          try {
            await _auth.signInWithCredential(credential);
          } on FirebaseAuthException catch (e) {
            if (!result.isCompleted) {
              result.completeError(AuthFailure.fromFirebase(e));
            }
            return;
          }
          if (!result.isCompleted) {
            result.complete(
              PhoneVerification._(
                phone: phone,
                autoSignIn: autoSignIn,
                autoVerified: true,
              ),
            );
          } else if (!autoSignIn.isCompleted) {
            autoSignIn.complete();
          }
        },
        verificationFailed: (e) {
          if (!result.isCompleted) {
            result.completeError(AuthFailure.fromFirebase(e));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!result.isCompleted) {
            result.complete(
              PhoneVerification._(
                phone: phone,
                autoSignIn: autoSignIn,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return await result.future;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebase(e);
    }
  }

  /// Signs in with the SMS [code] for [verification]. Throws [AuthFailure].
  Future<void> verifyOtp(PhoneVerification verification, String code) async {
    try {
      final web = verification._webConfirmation;
      if (web != null) {
        await web.confirm(code);
        return;
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: verification._verificationId!,
        smsCode: code,
      );
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebase(e);
    }
  }

  /// Loads `users/{uid}` for the signed-in user.
  ///
  /// Returns null when nobody is signed in or the merchant has not finished
  /// registration yet. Signs out and throws [AuthFailure] (`not-merchant`)
  /// when the account belongs to another role.
  Future<MerchantModel?> loadCurrentMerchant() async {
    final user = _auth.currentUser;
    if (user == null) {
      _currentMerchant = null;
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _userDoc(user.uid).get();
    } on FirebaseException catch (e) {
      debugPrint('Loading users/${user.uid} failed: ${e.code} ${e.message}');
      throw const AuthFailure(
        'profile-load-failed',
        'تعذر تحميل بيانات حسابك، تأكد من الاتصال بالإنترنت وحاول مرة أخرى',
      );
    }

    final data = snapshot.data();
    if (data == null) {
      _currentMerchant = null;
      return null;
    }
    if (data['role'] != MerchantModel.role) {
      await signOut();
      throw const AuthFailure(
        'not-merchant',
        'هذا الرقم غير مسجل كحساب تاجر على خزين',
      );
    }

    _currentMerchant = MerchantModel.fromFirestore(user.uid, data);
    return _currentMerchant;
  }

  /// Creates `users/{uid}` for the signed-in user from the registration
  /// [draft]. The id and phone always come from Firebase Auth.
  ///
  /// [exteriorPhoto] and [interiorPhoto] (JPEG bytes, optional) are uploaded
  /// to Storage under `users/{uid}/store/` first; if an upload fails nothing
  /// is saved, so the merchant can retry or continue without photos.
  Future<MerchantModel> registerMerchant(
    MerchantModel draft, {
    Uint8List? exteriorPhoto,
    Uint8List? interiorPhoto,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        'not-signed-in',
        'انتهت جلسة التحقق، سجّل رقم هاتفك مرة أخرى',
      );
    }

    String? exteriorUrl;
    String? interiorUrl;
    try {
      if (exteriorPhoto != null) {
        exteriorUrl = await _uploadPhoto(
          'users/${user.uid}/store/exterior.jpg',
          exteriorPhoto,
        ).timeout(_uploadTimeout);
      }
      if (interiorPhoto != null) {
        interiorUrl = await _uploadPhoto(
          'users/${user.uid}/store/interior.jpg',
          interiorPhoto,
        ).timeout(_uploadTimeout);
      }
    } on FirebaseException catch (e) {
      debugPrint('Store photo upload failed: ${e.code} ${e.message}');
      throw const AuthFailure(
        'photo-upload-failed',
        'تعذر رفع صور المحل. حاول تاني، أو كمّل التسجيل من غير صور.',
      );
    } on TimeoutException {
      throw const AuthFailure(
        'photo-upload-timeout',
        'رفع الصور أخد وقت طويل. اتأكد من الإنترنت وحاول تاني، أو كمّل من غير صور.',
      );
    }

    final merchant = MerchantModel(
      id: user.uid,
      merchantName: draft.merchantName,
      storeName: draft.storeName,
      phone: MerchantModel.toLocal(user.phoneNumber ?? draft.phone),
      category: draft.category,
      governorate: draft.governorate,
      city: draft.city,
      address: draft.address,
      landmark: draft.landmark,
      commercialRegister: draft.commercialRegister,
      latitude: draft.latitude,
      longitude: draft.longitude,
      exteriorPhotoUrl: exteriorUrl,
      interiorPhotoUrl: interiorUrl,
      registeredAt: DateTime.now(),
    );

    try {
      await _userDoc(user.uid)
          .set({
            ...merchant.toFirestore(),
            'created_at': FieldValue.serverTimestamp(),
          })
          .timeout(_writeTimeout);
    } on FirebaseException catch (e) {
      debugPrint('Writing users/${user.uid} failed: ${e.code} ${e.message}');
      throw const AuthFailure(
        'profile-save-failed',
        'تعذر حفظ بيانات متجرك، حاول مرة أخرى',
      );
    } on TimeoutException {
      throw const AuthFailure(
        'profile-save-timeout',
        'الاتصال بطيء، تأكد من الإنترنت وحاول مرة أخرى',
      );
    }

    _currentMerchant = merchant;
    return merchant;
  }

  Future<void> signOut() async {
    _currentMerchant = null;
    await _auth.signOut();
  }
}
