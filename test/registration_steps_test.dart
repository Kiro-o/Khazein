import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:khazeen_app/features/auth/view_models/onboarding_view_model.dart';
import 'package:khazeen_app/features/auth/views/registration/steps/step3_map_pin_step.dart';
import 'package:khazeen_app/features/auth/views/registration/steps/store_photo_step.dart';

/// A 1x1 transparent PNG, decodable by Image.memory.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> pumpStep(WidgetTester tester, Widget step) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: step),
        ),
      ),
    ),
  );
}

void main() {
  group('StorePhotoStep', () {
    testWidgets('next is enabled once a photo is picked', (tester) async {
      final vm = OnboardingViewModel();
      ImageSource? usedSource;
      await pumpStep(
        tester,
        StorePhotoStep(
          viewModel: vm,
          interior: false,
          pickPhoto: (source) async {
            usedSource = source;
            return _png;
          },
        ),
      );

      final next = find.widgetWithText(ElevatedButton, 'التالي');
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('take_photo')));
      await tester.pumpAndSettle();

      expect(usedSource, ImageSource.camera);
      expect(vm.exteriorPhoto, _png);
      expect(find.byKey(const ValueKey('store_photo_preview')), findsOneWidget);
      expect(tester.widget<ElevatedButton>(next).onPressed, isNotNull);
    });

    testWidgets('a camera failure shows a message instead of crashing', (
      tester,
    ) async {
      final vm = OnboardingViewModel();
      await pumpStep(
        tester,
        StorePhotoStep(
          viewModel: vm,
          interior: false,
          pickPhoto: (_) async => throw Exception('camera denied'),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('take_photo')));
      await tester.pumpAndSettle();

      expect(find.textContaining('مقدرناش نفتح الكاميرا'), findsOneWidget);
    });

    testWidgets('skip clears the photo and moves on', (tester) async {
      final vm = OnboardingViewModel()..setExteriorPhoto(_png);
      // Stand on the storefront step (index 4).
      for (var i = 0; i < 4; i++) {
        vm
          ..setBasicInfo(fullName: 'أحمد عبد الله', storeName: 'النور')
          ..setAddressDetails(
            governorate: 'الجيزة',
            city: 'الهرم',
            address: '15 شارع الهرم',
          )
          ..nextStep();
      }
      expect(vm.currentStep, 4);
      await pumpStep(tester, StorePhotoStep(viewModel: vm, interior: false));

      await tester.tap(find.byKey(const ValueKey('skip_photo')));
      await tester.pumpAndSettle();

      expect(vm.exteriorPhoto, isNull);
      expect(vm.currentStep, 5);
    });
  });

  group('Step3MapPinStep', () {
    testWidgets('confirming saves the map center and moves on', (
      tester,
    ) async {
      final vm = OnboardingViewModel()
        ..setBasicInfo(fullName: 'أحمد عبد الله', storeName: 'النور')
        ..nextStep()
        ..nextStep();
      expect(vm.currentStep, 2);

      await pumpStep(tester, Step3MapPinStep(viewModel: vm, tileUrl: ''));
      expect(find.text('استخدم موقعي الحالي'), findsOneWidget);

      await tester.tap(find.text('تأكيد المكان'));
      await tester.pumpAndSettle();

      expect(vm.currentStep, 3);
      expect(vm.latitude, closeTo(OnboardingViewModel.defaultLatitude, 1e-6));
      expect(vm.longitude, closeTo(OnboardingViewModel.defaultLongitude, 1e-6));
    });
  });
}
