import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/merchant_model.dart';
import '../models/order_model.dart';

/// Order failure carrying an Arabic, user-facing [message].
class OrderFailure implements Exception {
  final String message;
  const OrderFailure(this.message);

  @override
  String toString() => message;
}

/// Merchant orders in Firestore.
///
/// Each document in `orders` is one supplier's sub-order (`orders/{KZ-1046-1}`);
/// the sub-orders of one checkout share `master_order_id` (`KZ-1046`).
/// The supplier web app reads the same documents by `supplier_uid` and
/// updates their `status`.
class OrderRepository {
  OrderRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  static OrderRepository _instance = OrderRepository();
  static OrderRepository get instance => _instance;

  /// Replaces the shared instance (tests inject a fake Firestore).
  @visibleForTesting
  static set instance(OrderRepository repository) => _instance = repository;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  /// Order numbers start after this value when the counter doesn't exist.
  static const int _firstOrderNumber = 1000;
  static const Duration _writeTimeout = Duration(seconds: 20);

  /// Most distinct products in one supplier sub-order; `firestore.rules`
  /// enforces the same limit on `items`.
  static const int maxItemsPerSupplier = 25;

  /// Places one checkout as a sub-order per supplier.
  ///
  /// Prices, names and suppliers are read from `products` inside the same
  /// transaction, so the order uses current catalog data. Throws
  /// [OrderFailure] when a product is unavailable, below its minimum order
  /// quantity, or its price changed since it was added to the cart.
  Future<MasterOrder> placeOrder({
    required MerchantModel merchant,
    required List<OrderItemModel> items,
    required String deliveryAddress,
    String? deliveryNotes,
    PaymentMethod paymentMethod = PaymentMethod.cashOnDelivery,
  }) async {
    if (items.isEmpty) throw const OrderFailure('السلة فارغة');

    final counterRef = _db.collection('counters').doc('orders_counter');

    try {
      return await _db
          .runTransaction<MasterOrder>((tx) async {
            // All reads happen before any write.
            final counter = await tx.get(counterRef);
            final products = <String, Map<String, dynamic>>{};
            for (final item in items) {
              final snap = await tx.get(
                _db.collection('products').doc(item.productId),
              );
              final data = snap.data();
              if (data == null) {
                throw OrderFailure('الصنف "${item.productName}" لم يعد متاحاً');
              }
              products[item.productId] = data;
            }

            final pricedItems = <OrderItemModel>[];
            for (final item in items) {
              final data = products[item.productId]!;
              final name = data['name']?.toString() ?? item.productName;
              final supplierUid = data['supplier_uid']?.toString() ?? '';
              final cartonPrice =
                  (data['carton_price'] as num?)?.toDouble() ?? 0;
              final minQty = (data['min_order_qty'] as num?)?.toInt() ?? 1;

              if (data['is_available'] != true || supplierUid.isEmpty) {
                throw OrderFailure('الصنف "$name" غير متاح حالياً');
              }
              if (item.quantity < minQty) {
                throw OrderFailure('أقل كمية لطلب "$name" هي $minQty كرتونة');
              }
              if (cartonPrice != item.cartonPrice) {
                throw OrderFailure(
                  'تم تحديث سعر "$name"، راجع السلة قبل تأكيد الطلب',
                );
              }

              pricedItems.add(
                OrderItemModel(
                  productId: item.productId,
                  productName: name,
                  imageUrl: data['image_url']?.toString() ?? item.imageUrl,
                  cartonPrice: cartonPrice,
                  piecesPerCarton:
                      (data['units_per_carton'] as num?)?.toInt() ??
                      item.piecesPerCarton,
                  quantity: item.quantity,
                  supplierId: supplierUid,
                  supplierName: item.supplierName,
                  supplierSla: item.supplierSla,
                ),
              );
            }

            final lastNumber =
                (counter.data()?['last_number'] as num?)?.toInt() ??
                _firstOrderNumber;
            final orderNumber = lastNumber + 1;
            final masterOrderId = 'KZ-$orderNumber';
            final now = DateTime.now();

            final bySupplier = <String, List<OrderItemModel>>{};
            for (final item in pricedItems) {
              bySupplier.putIfAbsent(item.supplierId, () => []).add(item);
            }

            final subOrders = <SubOrder>[];
            var index = 1;
            for (final entry in bySupplier.entries) {
              final supplierItems = entry.value;
              final first = supplierItems.first;
              if (supplierItems.length > maxItemsPerSupplier) {
                throw OrderFailure(
                  'الحد الأقصى $maxItemsPerSupplier صنف من ${first.supplierName} في الطلبية الواحدة، قسّمها على أكتر من طلبية',
                );
              }
              final supplierCode =
                  products[first.productId]!['supplier_code']?.toString() ?? '';
              subOrders.add(
                SubOrder(
                  subOrderId: '$masterOrderId-${index++}',
                  masterOrderId: masterOrderId,
                  orderNumber: orderNumber,
                  merchantId: merchant.id,
                  supplierId: entry.key,
                  supplierCode: supplierCode,
                  supplierName: first.supplierName,
                  deliverySla: first.supplierSla,
                  paymentMethod: paymentMethod,
                  items: List.unmodifiable(supplierItems),
                  subtotal: supplierItems.fold(
                    0.0,
                    (acc, i) => acc + i.totalPrice,
                  ),
                  createdAt: now,
                  // E.164, the verified sign-in number (checked by firestore.rules).
                  merchantPhone: MerchantModel.toE164(merchant.phone),
                  merchantStoreName: merchant.storeName,
                  deliveryAddress: deliveryAddress,
                  deliveryNotes: deliveryNotes,
                ),
              );
            }

            tx.set(counterRef, {
              'last_number': orderNumber,
              'updated_at': FieldValue.serverTimestamp(),
            });
            for (final sub in subOrders) {
              tx.set(_orders.doc(sub.subOrderId), {
                ...sub.toFirestore(),
                'created_at': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp(),
              });
            }

            return MasterOrder(
              id: masterOrderId,
              orderNumber: orderNumber,
              subOrders: List.unmodifiable(subOrders),
            );
          })
          .timeout(_writeTimeout);
    } on OrderFailure {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('placeOrder failed: ${e.code} ${e.message}');
      throw OrderFailure(switch (e.code) {
        'unavailable' || 'deadline-exceeded' =>
          'مفيش اتصال بالإنترنت. اتأكد من الشبكة وحاول تاني.',
        // Another checkout took the same order number at the same moment.
        'aborted' => 'حصل ضغط على الطلبات دلوقتي. حاول تاني بعد ثواني.',
        'permission-denied' =>
          'حسابك مش مسموح له يطلب دلوقتي. كلّم خدمة العملاء.',
        _ => 'تعذر إرسال الطلبية، حاول مرة أخرى',
      });
    } on TimeoutException {
      throw const OrderFailure('الاتصال بطيء، تأكد من الإنترنت وحاول مرة أخرى');
    }
  }

  /// Live orders of [merchantUid], grouped per checkout, newest first.
  Stream<List<MasterOrder>> watchMerchantOrders(String merchantUid) {
    return _orders
        .where('merchant_id', isEqualTo: merchantUid)
        .snapshots()
        .map(
          (snapshot) => MasterOrder.group(
            snapshot.docs.map(
              (doc) => SubOrder.fromFirestore(doc.id, doc.data()),
            ),
          ),
        );
  }

  /// Cart quantities (product id -> cartons) to order [order] again.
  static Map<String, int> reorderQuantities(MasterOrder order) {
    final quantities = <String, int>{};
    for (final sub in order.subOrders) {
      for (final item in sub.items) {
        quantities[item.productId] =
            (quantities[item.productId] ?? 0) + item.quantity;
      }
    }
    return quantities;
  }
}
