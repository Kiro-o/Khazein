import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/b2b_product_mock_data.dart';
import 'package:khazeen_app/data/models/merchant_model.dart';
import 'package:khazeen_app/data/models/order_model.dart';
import 'package:khazeen_app/data/repositories/order_repository.dart';
import 'package:khazeen_app/data/repositories/product_repository.dart';
import 'package:khazeen_app/features/cart/views/cart_screen.dart';
import 'package:khazeen_app/features/home/views/merchant_home_screen.dart';
import 'package:khazeen_app/features/orders/views/merchant_orders_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMerchant = MerchantModel(
    id: 'mer_test_01',
    merchantName: 'محمود الصاوي',
    storeName: 'سوبرماركت التحرير',
    phone: '01012345678',
    governorate: 'القاهرة',
    city: 'التحرير',
    address: 'شارع قصر النيل، وسط البلد',
    registeredAt: DateTime(2026, 3, 1),
  );

  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    OrderRepository.instance = OrderRepository(firestore: db);
    ProductRepository.instance.registerAll(B2BProductMockData.sampleProducts);
    // Catalog documents the order transaction reads prices from.
    for (final p in B2BProductMockData.sampleProducts) {
      await db.collection('products').doc(p.id).set({
        'name': p.name,
        'carton_price': p.cartonPrice,
        'units_per_carton': p.piecesPerCarton,
        'min_order_qty': p.minOrderQuantity ?? 1,
        'is_available': true,
        'supplier_uid': p.supplierUid,
        'supplier_code': p.supplierCode,
        'image_url': p.imageUrl,
      });
    }
  });

  OrderItemModel itemFor(String productId, int quantity) {
    final p = B2BProductMockData.sampleProducts.firstWhere((p) => p.id == productId);
    return CartItem.fromProduct(p, quantity).toOrderItemModel();
  }

  Future<MasterOrder> placeSampleOrder() => OrderRepository.instance.placeOrder(
        merchant: testMerchant,
        items: [
          itemFor('khazeen_prod_05', 2),
          itemFor('khazeen_prod_09', 1),
          itemFor('khazeen_prod_06', 3),
        ],
        deliveryAddress: testMerchant.address,
        deliveryNotes: 'الاستلام عند الباب الخلفي',
      );

  group('Module 1: Food-Only Horizontal Category Filter Tests', () {
    test('foodCategories contains all 7 food categories with zero detergents', () {
      expect(B2BProductMockData.foodCategories, [
        'الكل',
        'ألبان وأجبان',
        'مياه ومشروبات',
        'بقالة وزيوت',
        'بقوليات وحبوب',
        'معلبات وصلصات',
        'مستلزمات تصنيع وحلويات',
      ]);

      // Verify no detergent exists in catalog
      for (final product in B2BProductMockData.sampleProducts) {
        expect(product.category, isNot(contains('منظفات')));
        expect(product.name, isNot(contains('أريال')));
        expect(product.name, isNot(contains('برسيل')));
        expect(B2BProductMockData.foodCategories, contains(product.category));
      }
    });

    test('getProductsByCategory returns correct filtered items', () {
      final dairy = B2BProductMockData.getProductsByCategory('ألبان وأجبان');
      expect(dairy.length, greaterThanOrEqualTo(2));
      expect(dairy.any((p) => p.name.contains('جهينة')), isTrue);
      expect(dairy.any((p) => p.name.contains('دومتي')), isTrue);

      final beverages = B2BProductMockData.getProductsByCategory('مياه ومشروبات');
      expect(beverages.length, greaterThanOrEqualTo(2));
      expect(beverages.any((p) => p.name.contains('بيبسي')), isTrue);

      final all = B2BProductMockData.getProductsByCategory('الكل');
      expect(all.length, equals(B2BProductMockData.sampleProducts.length));
    });

    testWidgets('MerchantHomeScreen tapping category chip filters products feed in-place',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantHomeScreen(
            merchant: testMerchant,
            productsStream: Stream.value(B2BProductMockData.sampleProducts),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on "الكل"
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('زيت عباد الشمس سلايت (750 مل)'), findsOneWidget);

      // Tap on 'ألبان وأجبان' chip
      await tester.tap(find.text('ألبان وأجبان').first);
      await tester.pumpAndSettle();

      // In-place filtered: Slite oil is gone, Juhayna milk and Domty cheese are visible
      expect(find.text('زيت عباد الشمس سلايت (750 مل)'), findsNothing);
      expect(find.text('حليب جهينة كامل الدسم (1 لتر)'), findsOneWidget);
      // The circle label and the section title.
      expect(find.text('ألبان وأجبان'), findsNWidgets(2));

      // Tap back on "الكل"
      await tester.tap(find.text('الكل').first);
      await tester.pumpAndSettle();

      expect(find.text('زيت عباد الشمس سلايت (750 مل)'), findsOneWidget);
      expect(find.text('كل المنتجات'), findsOneWidget);
    });
  });

  group('Module 2: Consolidated Cart & Multi-Supplier Logistics Tests', () {
    test('CartItem and SupplierGroup calculate financials and partition by supplier', () {
      final item1 = const CartItem(
        productId: 'khazeen_prod_05',
        productName: 'حليب جهينة كامل الدسم (1 لتر)',
        imageUrl: '',
        cartonPrice: 420.0,
        piecesPerCarton: 12,
        quantity: 2,
        supplierId: '#12',
        supplierName: 'شركة جهينة للصناعات الغذائية',
        supplierSla: 'التوصيل غداً',
      );

      final item2 = const CartItem(
        productId: 'khazeen_prod_06',
        productName: 'كانز بيبسي كولا (320 مل)',
        imageUrl: '',
        cartonPrice: 360.0,
        piecesPerCarton: 24,
        quantity: 3,
        supplierId: '#14',
        supplierName: 'شركة بيبسي كولا مصر',
        supplierSla: 'التوصيل اليوم خلال 3 ساعات',
      );

      expect(item1.totalPrice, 840.0);
      expect(item1.piecePrice, 35.0);
      expect(item1.formattedTotalPrice, '840 ج.م');
      expect(item1.formattedCartonPrice, '420 ج.م');
      expect(item1.formattedPiecePrice, '35.00 ج.م');

      // Test SupplierGroup grouping
      final groups = SupplierGroup.fromCartItems([item1, item2]);
      expect(groups.length, 2);

      final juhaynaGroup = groups.firstWhere((g) => g.supplierId == '#12');
      expect(juhaynaGroup.totalCartons, 2);
      expect(juhaynaGroup.subtotal, 840.0);
      expect(juhaynaGroup.deliveryScheduleText, 'شحنة شركة جهينة للصناعات الغذائية: التوصيل غداً');

      final pepsiGroup = groups.firstWhere((g) => g.supplierId == '#14');
      expect(pepsiGroup.totalCartons, 3);
      expect(pepsiGroup.subtotal, 1080.0);
      expect(pepsiGroup.deliveryScheduleText, 'شحنة شركة بيبسي كولا مصر: التوصيل اليوم خلال 3 ساعات');
    });

    Future<void> pumpCart(
      WidgetTester tester,
      Map<String, int> quantities, {
      ValueChanged<CartResult?>? onClosed,
    }) async {
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<CartResult>(
                      MaterialPageRoute(
                        builder: (_) => CartScreen(
                          merchant: testMerchant,
                          initialQuantities: quantities,
                        ),
                      ),
                    );
                    onClosed?.call(result);
                  },
                  child: const Text('open cart'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open cart'));
      await tester.pumpAndSettle();
    }

    testWidgets('CartScreen groups items by supplier with address and total', (
      tester,
    ) async {
      // Juhayna milk 2 x 420 = 840, Pepsi 2 x 360 = 720.
      await pumpCart(tester, {'khazeen_prod_05': 2, 'khazeen_prod_06': 2});

      expect(find.text('شركة جهينة للصناعات الغذائية'), findsOneWidget);
      expect(find.text('التوصيل غداً'), findsOneWidget);
      expect(find.text('شركة بيبسي كولا مصر'), findsOneWidget);
      expect(find.text('التوصيل اليوم خلال 3 ساعات'), findsOneWidget);

      expect(find.textContaining('شارع قصر النيل'), findsOneWidget);
      expect(find.text('كاش عند الاستلام'), findsOneWidget);
      expect(find.text('المنتجات (4 كرتونة)'), findsOneWidget);
      expect(find.text('تأكيد الطلب · 1560 ج.م'), findsOneWidget);
    });

    testWidgets('changing quantities updates the total and empties the cart', (
      tester,
    ) async {
      await pumpCart(tester, {'khazeen_prod_05': 1});
      expect(find.text('تأكيد الطلب · 420 ج.م'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('increment')));
      await tester.pumpAndSettle();
      expect(find.text('تأكيد الطلب · 840 ج.م'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('decrement')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decrement')));
      await tester.pumpAndSettle();

      expect(find.text('السلة فاضية'), findsOneWidget);
      expect(find.byKey(const ValueKey('place_order')), findsNothing);
    });
  });

  group('Module 3 & 4: Checkout & Order-Splitting Engine Tests', () {
    test('placeOrder writes one orders document per supplier', () async {
      final masterOrder = await placeSampleOrder();

      expect(masterOrder.id, 'KZ-1001');
      expect(masterOrder.formattedOrderNumber, '#1001');
      expect(masterOrder.totalCartons, 6); // 2 + 1 + 3
      expect(masterOrder.totalAmount, (420 * 2) + 540 + (360 * 3)); // 2460
      expect(masterOrder.subOrders.length, 2); // Split into 2 suppliers

      final juhaynaSub = masterOrder.subOrders.firstWhere((s) => s.supplierId == 'uid_12');
      expect(juhaynaSub.items.length, 2);
      expect(juhaynaSub.subtotal, 1380.0);
      expect(juhaynaSub.deliveryNotes, 'الاستلام عند الباب الخلفي');

      final docs = await db.collection('orders').get();
      expect(docs.docs.map((d) => d.id), unorderedEquals(['KZ-1001-1', 'KZ-1001-2']));

      final juhaynaDoc = docs.docs.firstWhere((d) => d['supplier_uid'] == 'uid_12').data();
      expect(juhaynaDoc['master_order_id'], 'KZ-1001');
      expect(juhaynaDoc['merchant_id'], 'mer_test_01');
      expect(juhaynaDoc['merchant_name'], 'سوبرماركت التحرير');
      expect(juhaynaDoc['supplier_code'], '#12');
      expect(juhaynaDoc['status'], 'pending');
      expect(juhaynaDoc['payment_method'], 'cash_on_delivery');
      expect(juhaynaDoc['total'], 1380.0);
      expect(juhaynaDoc['cartons_count'], 3);
      final firstItem = Map<String, dynamic>.from((juhaynaDoc['items'] as List).first as Map);
      expect(firstItem['product_id'], 'khazeen_prod_05');
      expect(firstItem['cartons_qty'], 2);
      expect(firstItem['carton_price'], 420.0);
      expect(firstItem['units_per_carton'], 12);
      expect(firstItem['line_total'], 840.0);

      final counter = await db.collection('counters').doc('orders_counter').get();
      expect(counter['last_number'], 1001);
    });

    test('order numbers increase with each checkout', () async {
      await placeSampleOrder();
      final second = await placeSampleOrder();
      expect(second.formattedOrderNumber, '#1002');
    });

    test('an unavailable product rejects the whole order', () async {
      await db.collection('products').doc('khazeen_prod_06').update({'is_available': false});

      await expectLater(placeSampleOrder(), throwsA(isA<OrderFailure>()));
      expect((await db.collection('orders').get()).docs, isEmpty);
    });

    test('a changed price rejects the order', () async {
      await db.collection('products').doc('khazeen_prod_05').update({'carton_price': 430.0});

      await expectLater(
        placeSampleOrder(),
        throwsA(isA<OrderFailure>().having((e) => e.message, 'message', contains('تم تحديث سعر'))),
      );
    });

    test('quantity below the minimum order is rejected', () async {
      await expectLater(
        OrderRepository.instance.placeOrder(
          merchant: testMerchant,
          items: [itemFor('khazeen_prod_06', 1)], // MOQ is 2
          deliveryAddress: testMerchant.address,
        ),
        throwsA(isA<OrderFailure>()),
      );
    });

    test('watchMerchantOrders groups sub-orders and maps web status values', () async {
      await placeSampleOrder();
      await db.collection('orders').doc('KZ-1001-2').update({'status': 'out_for_delivery'});

      final orders = await OrderRepository.instance.watchMerchantOrders('mer_test_01').first;
      expect(orders.length, 1);
      expect(orders.first.subOrders.map((s) => s.status),
          [OrderStatus.pending, OrderStatus.outForDelivery]);
      expect(orders.first.statusLabel, 'قيد التنفيذ');

      final otherMerchant = await OrderRepository.instance.watchMerchantOrders('someone_else').first;
      expect(otherMerchant, isEmpty);
    });

    testWidgets('placing an order from the cart saves it and returns to my orders', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      CartResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<CartResult>(
                    MaterialPageRoute(
                      builder: (_) => CartScreen(
                        merchant: testMerchant,
                        initialQuantities: const {
                          'khazeen_prod_05': 2,
                          'khazeen_prod_06': 2,
                        },
                      ),
                    ),
                  );
                },
                child: const Text('open cart'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open cart'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('delivery_notes')),
        'التسليم بعد الظهر',
      );
      await tester.tap(find.byKey(const ValueKey('place_order')));
      await tester.pumpAndSettle();

      expect(find.text('طلبك #1001 وصل'), findsOneWidget);
      expect(find.textContaining('اتقسم على 2 موردين'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('track_order')));
      await tester.pumpAndSettle();

      expect(result, CartResult.orderPlaced);
      final orders = await db.collection('orders').get();
      expect(orders.docs.map((d) => d.id), containsAll(['KZ-1001-1', 'KZ-1001-2']));
      expect(orders.docs.first.data()['delivery_notes'], 'التسليم بعد الظهر');
    });
  });

  group('Module 5: Order Tracking & 1-Click Re-Order Tests', () {
    testWidgets('MerchantOrdersScreen renders past orders and triggers re-order',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Map<String, int>? reorderedItems;
      await tester.runAsync(placeSampleOrder);
      await tester.runAsync(
          () => db.collection('orders').doc('KZ-1001-2').update({'status': 'out_for_delivery'}));

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantOrdersScreen(
            merchant: testMerchant,
            onReorder: (quantities) {
              reorderedItems = quantities;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طلباتي'), findsOneWidget);

      expect(find.text('طلب #1001'), findsOneWidget);

      // Sub-shipment status pills
      expect(find.text('قيد المراجعة'), findsWidgets);
      expect(find.text('مع المندوب في الطريق'), findsWidgets);

      // Tap 1-Click Re-Order
      final reorderButtons = find.text('اطلب تاني');
      expect(reorderButtons, findsWidgets);
      await tester.tap(reorderButtons.first);
      await tester.pumpAndSettle();

      expect(reorderedItems, isNotNull);
      expect(reorderedItems, {'khazeen_prod_05': 2, 'khazeen_prod_09': 1, 'khazeen_prod_06': 3});
    });

    testWidgets('MerchantHomeScreen switches to "طلباتي" tab and returns on re-order',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.runAsync(placeSampleOrder);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantHomeScreen(
            merchant: testMerchant,
            productsStream: Stream.value(B2BProductMockData.sampleProducts),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on "طلباتي" bottom nav tab (icon: receipt_long_outlined)
      final ordersTab = find.byIcon(Icons.receipt_long_outlined);
      expect(ordersTab, findsOneWidget);
      await tester.tap(ordersTab);
      await tester.pumpAndSettle();

      // Verify "طلباتي" screen is active
      expect(find.widgetWithText(AppBar, 'طلباتي'), findsOneWidget);

      // Tap re-order
      final reorderBtn = find.text('اطلب تاني').first;
      await tester.tap(reorderBtn);
      await tester.pumpAndSettle();

      // Back on the catalog with the re-ordered items in the cart bar.
      expect(find.text('كل المنتجات'), findsOneWidget);
      expect(find.text('عرض السلة'), findsOneWidget);
    });
  });
}
