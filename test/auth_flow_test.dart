import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khazeen_app/data/models/merchant_model.dart';
import 'package:khazeen_app/data/repositories/auth_repository.dart';
import 'package:khazeen_app/features/auth/view_models/onboarding_view_model.dart';
import 'package:khazeen_app/features/auth/views/phone_login_screen.dart';
import 'package:khazeen_app/features/auth/views/registration/merchant_registration_screen.dart';
import 'package:khazeen_app/features/auth/views/signup/otp_verification_screen.dart';
import 'package:khazeen_app/features/auth/views/welcome_gateway_screen.dart';
import 'package:khazeen_app/features/home/views/merchant_home_screen.dart';
import 'package:khazeen_app/features/splash/views/splash_screen.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

const _uid = 'merchant-uid-1';
const _phoneE164 = '+201012345678';

MockUser _mockUser() => MockUser(uid: _uid, phoneNumber: _phoneE164);

Map<String, dynamic> _merchantDoc({String role = 'merchant'}) => {
  'uid': _uid,
  'role': role,
  'business_name': 'سوبر ماركت النور',
  'owner_name': 'أحمد عبد الله',
  'phone_number': _phoneE164,
  'store_category': 'سوبر ماركت',
  'governorate': 'القاهرة',
  'city': 'شبرا',
  'address': '15 شارع أحمد حلمي',
  'created_at': Timestamp.fromDate(DateTime(2026, 10, 1)),
};

void main() {
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore firestore;

  /// Store photo uploads seen by the fake uploader (path -> size).
  late Map<String, int> uploads;

  void useRepository({bool signedIn = false, bool uploadsFail = false}) {
    auth = MockFirebaseAuth(signedIn: signedIn, mockUser: _mockUser());
    firestore = FakeFirebaseFirestore();
    uploads = {};
    AuthRepository.instance = AuthRepository(
      auth: auth,
      firestore: firestore,
      uploadPhoto: (path, bytes) async {
        if (uploadsFail) {
          throw FirebaseException(plugin: 'storage', code: 'unauthorized');
        }
        uploads[path] = bytes.length;
        return 'https://storage.example.com/$path';
      },
    );
  }

  void useLargeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  setUp(useRepository);

  group('MerchantModel phone formats', () {
    test('converts between local and E.164 formats', () {
      expect(MerchantModel.toE164('01012345678'), '+201012345678');
      expect(MerchantModel.toE164('+201012345678'), '+201012345678');
      expect(MerchantModel.toE164('00201012345678'), '+201012345678');
      expect(MerchantModel.toLocal('+201012345678'), '01012345678');
    });
  });

  group('AuthRepository', () {
    test('sendOtp then verifyOtp signs the user in', () async {
      final verification = await AuthRepository.instance.sendOtp('01012345678');
      expect(verification.phone, '01012345678');
      expect(verification.autoVerified, isFalse);
      expect(auth.currentUser, isNull);

      await AuthRepository.instance.verifyOtp(verification, '123456');
      expect(auth.currentUser?.uid, _uid);
    });

    test('a wrong code throws AuthFailure with an Arabic message', () async {
      whenCalling(Invocation.method(#signInWithCredential, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

      final verification = await AuthRepository.instance.sendOtp('01012345678');
      await expectLater(
        AuthRepository.instance.verifyOtp(verification, '000000'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            'رمز التحقق غير صحيح',
          ),
        ),
      );
      expect(auth.currentUser, isNull);
    });

    test('loadCurrentMerchant returns null without a profile', () async {
      useRepository(signedIn: true);
      expect(await AuthRepository.instance.loadCurrentMerchant(), isNull);
    });

    test('loadCurrentMerchant maps users/{uid}', () async {
      useRepository(signedIn: true);
      await firestore.collection('users').doc(_uid).set(_merchantDoc());

      final merchant = await AuthRepository.instance.loadCurrentMerchant();
      expect(merchant?.id, _uid);
      expect(merchant?.storeName, 'سوبر ماركت النور');
      expect(merchant?.merchantName, 'أحمد عبد الله');
      expect(merchant?.phone, '01012345678');
      expect(AuthRepository.instance.currentMerchant?.id, _uid);
    });

    test('a non-merchant profile is rejected and signed out', () async {
      useRepository(signedIn: true);
      await firestore
          .collection('users')
          .doc(_uid)
          .set(_merchantDoc(role: 'admin'));

      await expectLater(
        AuthRepository.instance.loadCurrentMerchant(),
        throwsA(
          isA<AuthFailure>().having((e) => e.code, 'code', 'not-merchant'),
        ),
      );
      expect(auth.currentUser, isNull);
    });

    test(
      'registerMerchant writes the spec fields with the auth uid and phone',
      () async {
        useRepository(signedIn: true);
        final merchant = await AuthRepository.instance.registerMerchant(
          MerchantModel(
            id: 'ignored',
            merchantName: 'أحمد عبد الله',
            storeName: 'سوبر ماركت النور',
            phone: '01099999999',
            governorate: 'القاهرة',
            city: 'شبرا',
            address: '15 شارع أحمد حلمي',
            registeredAt: DateTime(2000),
          ),
        );

        expect(merchant.id, _uid);
        expect(merchant.phone, '01012345678');

        final doc = await firestore.collection('users').doc(_uid).get();
        final data = doc.data()!;
        expect(data['uid'], _uid);
        expect(data['role'], 'merchant');
        expect(data['business_name'], 'سوبر ماركت النور');
        expect(data['owner_name'], 'أحمد عبد الله');
        expect(data['phone_number'], _phoneE164);
        expect(data['governorate'], 'القاهرة');
        expect(data['city'], 'شبرا');
        expect(data['created_at'], isA<Timestamp>());
        expect(data.containsKey('password'), isFalse);
      },
    );

    test('registerMerchant without a signed-in user throws', () async {
      await expectLater(
        AuthRepository.instance.registerMerchant(
          MerchantModel(
            id: '',
            merchantName: 'أحمد',
            storeName: 'محل',
            phone: '',
            governorate: 'القاهرة',
            city: 'شبرا',
            address: 'شارع',
            registeredAt: DateTime(2026),
          ),
        ),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('signOut clears the user and cached merchant', () async {
      useRepository(signedIn: true);
      await firestore.collection('users').doc(_uid).set(_merchantDoc());
      await AuthRepository.instance.loadCurrentMerchant();

      await AuthRepository.instance.signOut();
      expect(auth.currentUser, isNull);
      expect(AuthRepository.instance.currentMerchant, isNull);
    });
  });

  group('OnboardingViewModel.completeRegistration', () {
    test('saves the profile and moves to the success step', () async {
      useRepository(signedIn: true);
      final vm = OnboardingViewModel()
        ..setBasicInfo(fullName: 'أحمد عبد الله', storeName: 'سوبر ماركت النور')
        ..setAddressDetails(
          address: '15 شارع أحمد حلمي',
          governorate: 'القاهرة',
          city: 'شبرا',
        );

      expect(await vm.completeRegistration(), isTrue);
      expect(vm.currentStep, 6);
      expect(vm.authenticatedMerchant?.id, _uid);
      final doc = await firestore.collection('users').doc(_uid).get();
      expect(doc.data()?['business_name'], 'سوبر ماركت النور');
    });

    test('reports an error and stays on the step when saving fails', () async {
      final vm = OnboardingViewModel()
        ..setBasicInfo(
          fullName: 'أحمد عبد الله',
          storeName: 'سوبر ماركت النور',
        );

      expect(await vm.completeRegistration(), isFalse);
      expect(vm.currentStep, 0);
      expect(vm.stepError, isNotNull);
      expect(vm.isSubmitting, isFalse);
    });

    OnboardingViewModel filledViewModel() => OnboardingViewModel()
      ..setBasicInfo(fullName: 'أحمد عبد الله', storeName: 'سوبر ماركت النور')
      ..setAddressDetails(
        governorate: 'الجيزة',
        city: 'الهرم',
        address: '15 شارع الهرم',
      )
      ..setExteriorPhoto(Uint8List.fromList([1, 2, 3]))
      ..setInteriorPhoto(Uint8List.fromList([4, 5]));

    test('uploads the store photos and saves their links', () async {
      useRepository(signedIn: true);
      final vm = filledViewModel();

      expect(await vm.completeRegistration(), isTrue);
      expect(uploads.keys, [
        'users/$_uid/store/exterior.jpg',
        'users/$_uid/store/interior.jpg',
      ]);
      final doc = (await firestore.collection('users').doc(_uid).get()).data()!;
      expect(doc['exterior_photo_url'], contains('exterior.jpg'));
      expect(doc['interior_photo_url'], contains('interior.jpg'));
      expect(doc['governorate'], 'الجيزة');
      expect(doc['city'], 'الهرم');
    });

    test('a failed upload saves nothing, and the merchant can skip photos', (
    ) async {
      useRepository(signedIn: true, uploadsFail: true);
      final vm = filledViewModel();

      expect(await vm.completeRegistration(), isFalse);
      expect(vm.stepError, contains('تعذر رفع صور المحل'));
      expect((await firestore.collection('users').doc(_uid).get()).exists,
          isFalse);

      expect(await vm.completeRegistration(withPhotos: false), isTrue);
      final doc = (await firestore.collection('users').doc(_uid).get()).data()!;
      expect(doc.containsKey('exterior_photo_url'), isFalse);
    });

    test('the address step requires a governorate, city and address', () {
      final vm = OnboardingViewModel()
        ..setBasicInfo(fullName: 'أحمد عبد الله', storeName: 'النور');
      vm
        ..nextStep() // to category
        ..nextStep() // to map
        ..nextStep(); // to address
      expect(vm.currentStep, 3);

      vm.setAddressDetails(governorate: null, city: 'الهرم', address: '15 شارع');
      expect(vm.nextStep(), isFalse);
      expect(vm.stepError, 'اختار المحافظة');

      vm.setAddressDetails(governorate: 'الجيزة', city: '', address: '15 شارع');
      expect(vm.nextStep(), isFalse);
      expect(vm.stepError, 'اكتب المدينة أو الحي');

      vm.setAddressDetails(
          governorate: 'الجيزة', city: 'الهرم', address: '15 شارع');
      expect(vm.nextStep(), isTrue);
    });
  });

  group('Phone login and OTP screens', () {
    testWidgets('an invalid phone number shows an error and sends nothing', (
      tester,
    ) async {
      useLargeView(tester);
      await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));

      await tester.enterText(find.byType(TextFormField), '0101234');
      await tester.pump();
      // The button stays disabled until the number is valid.
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'التالي'),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(OtpVerificationScreen), findsNothing);
    });

    testWidgets('a valid phone sends the code and opens the OTP screen', (
      tester,
    ) async {
      useLargeView(tester);
      await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));

      await tester.enterText(find.byType(TextFormField), '01012345678');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'التالي'));
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(
        find.textContaining('6 أرقام إلى الرقم 01012345678'),
        findsOneWidget,
      );
      // The old mock-OTP banner is gone.
      expect(find.textContaining('وضع التجربة'), findsNothing);
    });

    Future<void> pumpOtpScreen(
      WidgetTester tester, {
      OtpPurpose purpose = OtpPurpose.signUp,
    }) async {
      useLargeView(tester);
      final verification = await AuthRepository.instance.sendOtp('01012345678');
      await tester.pumpWidget(
        MaterialApp(
          home: OtpVerificationScreen(
            verification: verification,
            purpose: purpose,
          ),
        ),
      );
    }

    testWidgets('login with an unregistered number offers to create an account', (
      tester,
    ) async {
      await pumpOtpScreen(tester, purpose: OtpPurpose.login);

      await tester.enterText(
        find.byKey(const ValueKey('otp_code_field')),
        '123456',
      );
      await tester.pumpAndSettle();

      expect(find.text('الرقم ده مش مسجّل'), findsOneWidget);
      expect(find.byType(MerchantRegistrationScreen), findsNothing);

      await tester.tap(find.byKey(const ValueKey('create_account_button')));
      await tester.pumpAndSettle();

      expect(auth.currentUser?.uid, _uid);
      expect(find.byType(MerchantRegistrationScreen), findsOneWidget);
    });

    testWidgets('login with an unregistered number can go back and sign out', (
      tester,
    ) async {
      await pumpOtpScreen(tester, purpose: OtpPurpose.login);

      await tester.enterText(
        find.byKey(const ValueKey('otp_code_field')),
        '123456',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('رقم تاني'));
      await tester.pumpAndSettle();

      expect(auth.currentUser, isNull);
      expect(find.byType(MerchantRegistrationScreen), findsNothing);
    });

    testWidgets('login with a registered number goes to the home screen', (
      tester,
    ) async {
      await firestore.collection('users').doc(_uid).set(_merchantDoc());
      await pumpOtpScreen(tester, purpose: OtpPurpose.login);

      await tester.enterText(
        find.byKey(const ValueKey('otp_code_field')),
        '123456',
      );
      await tester.pumpAndSettle();

      expect(find.text('الرقم ده مش مسجّل'), findsNothing);
      expect(find.byType(MerchantHomeScreen), findsOneWidget);
    });

    testWidgets('a new number goes to merchant registration', (tester) async {
      await pumpOtpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('otp_code_field')),
        '123456',
      );
      await tester.pumpAndSettle();

      expect(auth.currentUser?.uid, _uid);
      expect(find.byType(MerchantRegistrationScreen), findsOneWidget);
    });

    testWidgets('a registered merchant goes to the home screen', (
      tester,
    ) async {
      await firestore.collection('users').doc(_uid).set(_merchantDoc());
      await pumpOtpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('otp_code_field')),
        '123456',
      );
      await tester.pumpAndSettle();

      expect(find.byType(MerchantHomeScreen), findsOneWidget);
      expect(find.text('سوبر ماركت النور'), findsWidgets);
    });

    testWidgets('a wrong code shows the error and stays on the screen', (
      tester,
    ) async {
      await pumpOtpScreen(tester);
      whenCalling(Invocation.method(#signInWithCredential, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

      await tester.enterText(
        find.byKey(const ValueKey('otp_code_field')),
        '000000',
      );
      await tester.pumpAndSettle();

      expect(find.text('رمز التحقق غير صحيح'), findsOneWidget);
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('an incomplete code is not submitted', (tester) async {
      await pumpOtpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('otp_code_field')),
        '123',
      );
      await tester.pump();
      await tester.tap(find.text('تأكيد الكود والمتابعة'));
      await tester.pump();

      expect(
        find.text('يرجى إدخال رمز التحقق المكون من 6 أرقام بالكامل'),
        findsOneWidget,
      );
      expect(auth.currentUser, isNull);
    });
  });

  group('SplashScreen session routing', () {
    Future<void> pumpSplash(WidgetTester tester) async {
      useLargeView(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(minimumDuration: Duration(milliseconds: 100)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
    }

    testWidgets('signed out goes to the welcome gateway', (tester) async {
      await pumpSplash(tester);
      expect(find.byType(WelcomeGatewayScreen), findsOneWidget);
    });

    testWidgets('signed in with a profile goes to the home screen', (
      tester,
    ) async {
      useRepository(signedIn: true);
      await firestore.collection('users').doc(_uid).set(_merchantDoc());
      await pumpSplash(tester);

      expect(find.byType(MerchantHomeScreen), findsOneWidget);
      expect(find.text('سوبر ماركت النور'), findsWidgets);
    });

    testWidgets('signed in without a profile resumes registration', (
      tester,
    ) async {
      useRepository(signedIn: true);
      await pumpSplash(tester);
      expect(find.byType(MerchantRegistrationScreen), findsOneWidget);
    });
  });
}
