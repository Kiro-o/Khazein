import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khazeen_app/core/constants/store_categories.dart';
import 'package:khazeen_app/core/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:khazeen_app/data/models/b2b_product_model.dart';

import 'fixtures/b2b_product_mock_data.dart';

import 'package:khazeen_app/data/models/merchant_model.dart';
import 'package:khazeen_app/data/repositories/auth_repository.dart';
import 'package:khazeen_app/features/auth/views/phone_login_screen.dart';
import 'package:khazeen_app/features/auth/views/signup/sign_up_setup_screen.dart';
import 'package:khazeen_app/features/auth/views/welcome_gateway_screen.dart';
import 'package:khazeen_app/features/home/views/merchant_home_screen.dart';
import 'package:khazeen_app/features/home/widgets/product_list_tile.dart';
import 'package:khazeen_app/features/cart/views/cart_screen.dart';
import 'package:khazeen_app/main.dart';

void main() {
  setUp(() {
    AuthRepository.instance = AuthRepository(
      auth: MockFirebaseAuth(),
      firestore: FakeFirebaseFirestore(),
    );
  });

  group('Egyptian Form Validators Test', () {
    test('Validates Egyptian phone numbers correctly', () {
      // Valid phone numbers
      expect(Validators.validateEgyptianPhone('01012345678'), isNull);
      expect(Validators.validateEgyptianPhone('01123456789'), isNull);
      expect(Validators.validateEgyptianPhone('01234567890'), isNull);
      expect(Validators.validateEgyptianPhone('01512345678'), isNull);
      expect(Validators.validateEgyptianPhone('+201012345678'), isNull);

      // Invalid phone numbers
      expect(Validators.validateEgyptianPhone(''), isNotNull);
      expect(Validators.validateEgyptianPhone('01312345678'), isNotNull);
      expect(Validators.validateEgyptianPhone('010123456'), isNotNull);
    });

    test('Validates store and merchant names', () {
      expect(Validators.validateMerchantName('أحمد علي'), isNull);
      expect(Validators.validateMerchantName('أح'), isNotNull);
      expect(Validators.validateStoreName('سوبر ماركت الإخوة'), isNull);
      expect(Validators.validateStoreName(''), isNotNull);
    });
  });

  group('Store Categories Test', () {
    test('Contains 8 FMCG store categories with search', () {
      expect(StoreCategories.list.length, 8);
      final searchResult = StoreCategories.search('سوبر');
      expect(searchResult.first.name, 'سوبر ماركت');
    });
  });

  group('Welcome Gateway Screen Test', () {
    testWidgets(
      'Renders all required elements matching design specifications',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(home: WelcomeGatewayScreen()),
        );

        // Brand: the logo image and the name.
        expect(find.bySemanticsLabel('خزين'), findsWidgets);
        expect(find.text('خزين'), findsOneWidget);
        expect(find.text('كل نواقص محلك في مكان واحد'), findsOneWidget);

        expect(find.text('أهلاً بيك في خزين'), findsOneWidget);
        expect(
          find.text('اطلب نواقص محلك بسعر الجملة من الشركات مباشرة'),
          findsOneWidget,
        );

        // Buttons
        expect(find.text('تسجيل الدخول'), findsOneWidget);
        expect(find.text('إنشاء حساب جديد'), findsOneWidget);
      },
    );

    testWidgets('Primary Button navigates to PhoneLoginScreen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: WelcomeGatewayScreen()));

      final loginBtn = find.widgetWithText(ElevatedButton, 'تسجيل الدخول');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PhoneLoginScreen), findsOneWidget);
    });

    testWidgets('Secondary Button navigates to SignUpSetupScreen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: WelcomeGatewayScreen()));

      final signupBtn = find.widgetWithText(OutlinedButton, 'إنشاء حساب جديد');
      expect(signupBtn, findsOneWidget);
      await tester.tap(signupBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SignUpSetupScreen), findsOneWidget);
    });
  });

  group('Khazeen Multi-Step App Smoke Test', () {
    testWidgets('Renders KhazeenApp without error', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const KhazeenApp());
      expect(find.bySemanticsLabel('خزين'), findsOneWidget);

      // Signed out: the splash continues to the welcome screen.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(WelcomeGatewayScreen), findsOneWidget);
    });
  });

  group('Product model', () {
    test('B2BProductModel calculated properties and serialization', () {
      final product = B2BProductMockData.sampleProducts[0];

      expect(product.piecePrice, equals(40.0));
      expect(product.hasDiscount, isTrue);
      expect(product.discountPercentage, equals(8));
      expect(product.formattedCartonPrice, equals('480 ج.م'));
      expect(product.formattedOldPrice, equals('520 ج.م'));
      expect(product.formattedPiecePrice, equals('40 ج.م'));
      expect(
        product.unitBreakdownText,
        equals('سعر القطعة: 40 ج.م | كرتونة 12 قطعة'),
      );
      expect(product.moqText, equals('أقل طلب: 2 كرتونة'));

      // Serialization test
      final json = product.toJson();
      final fromJson = B2BProductModel.fromJson(json);
      expect(fromJson.id, equals(product.id));
      expect(fromJson.name, equals(product.name));
      expect(fromJson.cartonPrice, equals(product.cartonPrice));
      expect(fromJson.piecesPerCarton, equals(product.piecesPerCarton));
      expect(fromJson.minOrderQuantity, equals(product.minOrderQuantity));
    });

    test('ProductListTile.nextQuantity respects the minimum order', () {
      // The first add jumps to the minimum order.
      expect(ProductListTile.nextQuantity(0, 3, increment: true), 3);
      expect(ProductListTile.nextQuantity(3, 3, increment: true), 4);
      // Going below the minimum removes the product.
      expect(ProductListTile.nextQuantity(4, 3, increment: false), 3);
      expect(ProductListTile.nextQuantity(3, 3, increment: false), 0);
      expect(ProductListTile.nextQuantity(1, 1, increment: false), 0);
    });
  });

  group('Home catalog', () {
    final merchant = MerchantModel(
      id: 'mer_ui_test',
      merchantName: 'محمود الصاوي',
      storeName: 'سوبرماركت التحرير',
      phone: '01011112222',
      governorate: 'القاهرة',
      city: 'التحرير',
      address: 'ميدان التحرير',
      registeredAt: DateTime(2026, 3, 1),
    );
    const oil = 'زيت عباد الشمس سلايت (750 مل)';
    const tea = 'شاي العروسة ناعم أصلي (250 جم)';

    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(480, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantHomeScreen(
            merchant: merchant,
            productsStream: Stream.value(B2BProductMockData.sampleProducts),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder tileOf(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byType(ProductListTile),
    );

    testWidgets('shows the store, search and products', (tester) async {
      await pumpHome(tester);

      expect(find.text('سوبرماركت التحرير'), findsOneWidget);
      expect(find.text('ابحث عن منتج أو شركة'), findsOneWidget);
      expect(find.text('كل المنتجات'), findsOneWidget);
      expect(find.text(oil), findsOneWidget);
      expect(find.byKey(const ValueKey('cart_bar')), findsNothing);
    });

    testWidgets('adding a product shows the cart bar at the minimum order', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(
        find.descendant(
          of: tileOf(oil),
          matching: find.byKey(const ValueKey('add_to_cart')),
        ),
      );
      await tester.pumpAndSettle();

      // Slite oil: minimum order 2 cartons x 480 EGP.
      expect(find.byKey(const ValueKey('cart_bar')), findsOneWidget);
      expect(find.text('عرض السلة'), findsOneWidget);
      expect(find.text('960 ج.م'), findsOneWidget);

      // One tap below the minimum removes it again.
      await tester.tap(
        find.descendant(
          of: tileOf(oil),
          matching: find.byKey(const ValueKey('decrement')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart_bar')), findsNothing);
    });

    testWidgets('search filters products by name', (tester) async {
      await pumpHome(tester);

      await tester.enterText(
        find.byKey(const ValueKey('catalog_search')),
        'شاي',
      );
      await tester.pumpAndSettle();

      expect(find.text('نتائج البحث'), findsOneWidget);
      expect(find.text(tea), findsOneWidget);
      expect(find.text(oil), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('catalog_search')),
        'مش موجود',
      );
      await tester.pumpAndSettle();
      expect(find.text('مفيش منتجات بالاسم ده'), findsOneWidget);
    });

    testWidgets('the cart bar opens the cart', (tester) async {
      await pumpHome(tester);

      await tester.tap(
        find.descendant(
          of: tileOf(tea),
          matching: find.byKey(const ValueKey('add_to_cart')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cart_bar')));
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
    });

    testWidgets('the account tab shows the store details and sign out', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('حسابي'));
      await tester.pumpAndSettle();

      expect(find.text('01011112222'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });
  });
}
