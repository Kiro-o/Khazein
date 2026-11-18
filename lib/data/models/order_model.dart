import 'package:cloud_firestore/cloud_firestore.dart';
import 'b2b_product_model.dart';

/// Status of a supplier sub-order, stored in `orders.status`.
///
/// Shared with the supplier web app, which writes the same values.
enum OrderStatus {
  pending('pending', 'قيد المراجعة'),
  processing('processing', 'جاري تجهيز الشحنة'),
  outForDelivery('out_for_delivery', 'مع المندوب في الطريق'),
  delivered('delivered', 'تم التوصيل'),
  cancelled('cancelled', 'ملغي');

  const OrderStatus(this.value, this.label);

  /// Value stored in Firestore.
  final String value;

  /// Arabic label shown to the merchant.
  final String label;

  /// Parses a stored value. Older web builds wrote display names such as
  /// `Preparing` or `Shipped`, so those are accepted too.
  static OrderStatus fromValue(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final status in values) {
      if (status.value == value) return status;
    }
    if (value.contains('prep') || value.contains('proc')) return processing;
    if (value.contains('ship') || value.contains('out')) return outForDelivery;
    if (value.contains('deliv')) return delivered;
    if (value.contains('cancel')) return cancelled;
    return pending;
  }
}

/// Payment method chosen at checkout, stored in `orders.payment_method`.
enum PaymentMethod {
  cashOnDelivery('cash_on_delivery', 'الدفع نقداً عند الاستلام'),
  deferred('deferred', 'المحفظة الإلكترونية / دفع آجل');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  static PaymentMethod fromValue(String? raw) => values.firstWhere(
        (method) => method.value == raw,
        orElse: () => cashOnDelivery,
      );
}

/// Represents an active item in the merchant's shopping cart
class CartItem {
  final String productId;
  final String productName;
  final String imageUrl;
  final double cartonPrice;
  final int piecesPerCarton;
  final int quantity; // Number of cartons

  /// `products.supplier_uid` of the supplier selling this product.
  final String supplierId;
  final String supplierName;
  final String supplierSla;

  const CartItem({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.cartonPrice,
    required this.piecesPerCarton,
    required this.quantity,
    required this.supplierId,
    required this.supplierName,
    this.supplierSla = 'توصيل خلال 24 ساعة',
  });

  double get totalPrice => cartonPrice * quantity;
  double get piecePrice =>
      piecesPerCarton > 0 ? cartonPrice / piecesPerCarton : cartonPrice;
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(0)} ج.م';
  String get formattedCartonPrice => '${cartonPrice.toStringAsFixed(0)} ج.م';
  String get formattedPiecePrice => '${piecePrice.toStringAsFixed(2)} ج.م';

  CartItem copyWith({
    String? productId,
    String? productName,
    String? imageUrl,
    double? cartonPrice,
    int? piecesPerCarton,
    int? quantity,
    String? supplierId,
    String? supplierName,
    String? supplierSla,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      imageUrl: imageUrl ?? this.imageUrl,
      cartonPrice: cartonPrice ?? this.cartonPrice,
      piecesPerCarton: piecesPerCarton ?? this.piecesPerCarton,
      quantity: quantity ?? this.quantity,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierSla: supplierSla ?? this.supplierSla,
    );
  }

  OrderItemModel toOrderItemModel() => OrderItemModel(
        productId: productId,
        productName: productName,
        imageUrl: imageUrl,
        cartonPrice: cartonPrice,
        piecesPerCarton: piecesPerCarton,
        quantity: quantity,
        supplierId: supplierId,
        supplierName: supplierName,
        supplierSla: supplierSla,
      );

  factory CartItem.fromProduct(B2BProductModel product, int quantity) =>
      CartItem(
        productId: product.id,
        productName: product.name,
        imageUrl: product.imageUrl,
        cartonPrice: product.cartonPrice,
        piecesPerCarton: product.piecesPerCarton,
        quantity: quantity,
        supplierId: product.supplierUid ?? '',
        supplierName: product.supplierName,
        supplierSla: product.deliverySla,
      );
}

/// Represents products in the cart grouped by supplier for delivery and logistics
class SupplierGroup {
  final String supplierId;
  final String supplierName;
  final String deliverySla;
  final List<CartItem> items;

  const SupplierGroup({
    required this.supplierId,
    required this.supplierName,
    required this.deliverySla,
    required this.items,
  });

  int get totalCartons => items.fold(0, (acc, item) => acc + item.quantity);
  double get subtotal => items.fold(0.0, (acc, item) => acc + item.totalPrice);
  String get formattedSubtotal => '${subtotal.toStringAsFixed(0)} ج.م';

  String get deliveryScheduleText => 'شحنة $supplierName: $deliverySla';

  static List<SupplierGroup> fromCartItems(List<CartItem> items) {
    final Map<String, List<CartItem>> map = {};
    for (final item in items) {
      map.putIfAbsent(item.supplierId, () => []).add(item);
    }
    return map.entries.map((entry) {
      final first = entry.value.first;
      return SupplierGroup(
        supplierId: entry.key,
        supplierName: first.supplierName,
        deliverySla: first.supplierSla,
        items: List.unmodifiable(entry.value),
      );
    }).toList();
  }
}

/// Represents an individual item in a wholesale purchase
class OrderItemModel {
  final String productId;
  final String productName;
  final String imageUrl;
  final double cartonPrice;
  final int piecesPerCarton;
  final int quantity; // Number of cartons

  /// `products.supplier_uid` of the supplier selling this product.
  final String supplierId;
  final String supplierName;
  final String supplierSla;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.cartonPrice,
    required this.piecesPerCarton,
    required this.quantity,
    required this.supplierId,
    required this.supplierName,
    this.supplierSla = 'توصيل خلال 24 ساعة',
  });

  double get totalPrice => cartonPrice * quantity;
  double get piecePrice =>
      piecesPerCarton > 0 ? cartonPrice / piecesPerCarton : cartonPrice;
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(0)} ج.م';
  String get formattedCartonPrice => '${cartonPrice.toStringAsFixed(0)} ج.م';

  /// Entry of `orders.items`, in the format the supplier web app reads.
  Map<String, dynamic> toFirestore() => {
        'product_id': productId,
        'product_name': productName,
        'image_url': imageUrl,
        'cartons_qty': quantity,
        'carton_price': cartonPrice,
        'units_per_carton': piecesPerCarton,
        'line_total': totalPrice,
      };

  factory OrderItemModel.fromFirestore(
    Map<String, dynamic> data, {
    required String supplierId,
    required String supplierName,
    required String supplierSla,
  }) =>
      OrderItemModel(
        productId: data['product_id']?.toString() ?? '',
        productName: data['product_name']?.toString() ?? '',
        imageUrl: data['image_url']?.toString() ?? '',
        cartonPrice: (data['carton_price'] as num?)?.toDouble() ?? 0.0,
        piecesPerCarton: (data['units_per_carton'] as num?)?.toInt() ?? 1,
        quantity: (data['cartons_qty'] as num?)?.toInt() ?? 1,
        supplierId: supplierId,
        supplierName: supplierName,
        supplierSla: supplierSla,
      );
}

/// One supplier's part of a merchant order: a document in `orders`.
class SubOrder {
  /// Document id, e.g. `KZ-1046-1`.
  final String subOrderId;

  /// Groups the sub-orders of one checkout, e.g. `KZ-1046`.
  final String masterOrderId;
  final int orderNumber;
  final String merchantId;
  final String supplierId;
  final String supplierCode;
  final String supplierName;
  final String deliverySla;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final List<OrderItemModel> items;
  final double subtotal;
  final DateTime createdAt;
  final String merchantPhone;
  final String merchantStoreName;
  final String deliveryAddress;
  final String? deliveryNotes;

  const SubOrder({
    required this.subOrderId,
    required this.masterOrderId,
    required this.orderNumber,
    required this.merchantId,
    required this.supplierId,
    this.supplierCode = '',
    required this.supplierName,
    required this.deliverySla,
    this.status = OrderStatus.pending,
    this.paymentMethod = PaymentMethod.cashOnDelivery,
    required this.items,
    required this.subtotal,
    required this.createdAt,
    required this.merchantPhone,
    required this.merchantStoreName,
    required this.deliveryAddress,
    this.deliveryNotes,
  });

  int get totalCartons => items.fold(0, (acc, i) => acc + i.quantity);
  String get formattedSubtotal => '${subtotal.toStringAsFixed(0)} ج.م';

  /// Fields of the `orders/{subOrderId}` document. Timestamps are added by
  /// the repository.
  Map<String, dynamic> toFirestore() => {
        'id': subOrderId,
        'master_order_id': masterOrderId,
        'order_number': orderNumber,
        'merchant_id': merchantId,
        'merchant_name': merchantStoreName,
        'merchant_phone': merchantPhone,
        'delivery_address': deliveryAddress,
        'delivery_notes': deliveryNotes ?? '',
        'supplier_uid': supplierId,
        'supplier_code': supplierCode,
        'supplier_name': supplierName,
        'delivery_sla': deliverySla,
        'items': items.map((i) => i.toFirestore()).toList(),
        'cartons_count': totalCartons,
        'subtotal': subtotal,
        'delivery_fee': 0,
        'total': subtotal,
        'status': status.value,
        'payment_method': paymentMethod.value,
      };

  factory SubOrder.fromFirestore(String docId, Map<String, dynamic> data) {
    final supplierId = data['supplier_uid']?.toString() ?? '';
    final supplierName = data['supplier_name']?.toString() ?? '';
    final deliverySla = data['delivery_sla']?.toString() ?? '';
    final createdAt = data['created_at'];

    return SubOrder(
      subOrderId: docId,
      masterOrderId: data['master_order_id']?.toString() ?? docId,
      orderNumber: (data['order_number'] as num?)?.toInt() ?? 0,
      merchantId: data['merchant_id']?.toString() ?? '',
      supplierId: supplierId,
      supplierCode: data['supplier_code']?.toString() ?? '',
      supplierName: supplierName,
      deliverySla: deliverySla,
      status: OrderStatus.fromValue(data['status']?.toString()),
      paymentMethod:
          PaymentMethod.fromValue(data['payment_method']?.toString()),
      items: (data['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((i) => OrderItemModel.fromFirestore(
                Map<String, dynamic>.from(i),
                supplierId: supplierId,
                supplierName: supplierName,
                supplierSla: deliverySla,
              ))
          .toList(),
      subtotal: (data['total'] as num?)?.toDouble() ??
          (data['subtotal'] as num?)?.toDouble() ??
          0.0,
      // Null while a just-written server timestamp is pending.
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      merchantPhone: data['merchant_phone']?.toString() ?? '',
      merchantStoreName: data['merchant_name']?.toString() ?? '',
      deliveryAddress: data['delivery_address']?.toString() ?? '',
      deliveryNotes: (data['delivery_notes']?.toString() ?? '').isEmpty
          ? null
          : data['delivery_notes'].toString(),
    );
  }
}

/// A merchant checkout: the sub-orders sharing one `master_order_id`.
class MasterOrder {
  final String id;
  final int orderNumber;
  final List<SubOrder> subOrders;

  const MasterOrder({
    required this.id,
    required this.orderNumber,
    required this.subOrders,
  });

  String get formattedOrderNumber => '#$orderNumber';
  DateTime get createdAt => subOrders.first.createdAt;
  PaymentMethod get paymentMethod => subOrders.first.paymentMethod;
  String get storeAddress => subOrders.first.deliveryAddress;
  double get totalAmount => subOrders.fold(0.0, (acc, s) => acc + s.subtotal);
  int get totalCartons =>
      subOrders.fold(0, (acc, sub) => acc + sub.totalCartons);
  String get formattedTotal => '${totalAmount.toStringAsFixed(0)} ج.م';

  /// Overall progress across suppliers.
  String get statusLabel {
    final statuses = subOrders.map((s) => s.status).toSet();
    if (statuses.length == 1) return statuses.first.label;
    if (statuses.every((s) =>
        s == OrderStatus.delivered || s == OrderStatus.cancelled)) {
      return 'مكتمل';
    }
    return 'قيد التنفيذ';
  }

  /// Groups sub-orders into master orders, newest first.
  static List<MasterOrder> group(Iterable<SubOrder> subOrders) {
    final Map<String, List<SubOrder>> byMaster = {};
    for (final sub in subOrders) {
      byMaster.putIfAbsent(sub.masterOrderId, () => []).add(sub);
    }
    final orders = byMaster.entries.map((entry) {
      final subs = entry.value
        ..sort((a, b) => a.subOrderId.compareTo(b.subOrderId));
      return MasterOrder(
        id: entry.key,
        orderNumber: subs.first.orderNumber,
        subOrders: List.unmodifiable(subs),
      );
    }).toList()
      ..sort((a, b) => b.orderNumber.compareTo(a.orderNumber));
    return orders;
  }
}
