import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/b2b_product_model.dart';

/// Live product catalog backed by the Firestore `products` collection
/// (written by the Khazeen supplier web app).
///
/// Also keeps an in-memory index of the products received so far, so the
/// cart and checkout can resolve a product id to its price and supplier.
class ProductRepository {
  ProductRepository._();
  static final ProductRepository instance = ProductRepository._();

  final Map<String, B2BProductModel> _loadedProducts = {};

  /// Streams available products (`is_available == true`), mapped to
  /// [B2BProductModel].
  ///
  /// Errors (e.g. Firebase not initialized, `permission-denied`) are emitted
  /// on the stream so the UI can display them.
  Stream<List<B2BProductModel>> watchProducts() {
    final Stream<QuerySnapshot<Map<String, dynamic>>> snapshots;
    try {
      snapshots = FirebaseFirestore.instance
          .collection('products')
          .where('is_available', isEqualTo: true)
          .snapshots();
    } catch (e) {
      return Stream.error(e);
    }
    return snapshots.map((snapshot) {
      final products = snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
      registerAll(products);
      return products;
    });
  }

  /// Registers products so they can later be resolved by [findById].
  void registerAll(Iterable<B2BProductModel> products) {
    for (final product in products) {
      _loadedProducts[product.id] = product;
    }
  }

  B2BProductModel? findById(String id) => _loadedProducts[id];

  /// Maps a `products` document written by the supplier web app.
  ///
  /// Fields: name, carton_price, piece_price, image_url, category,
  /// is_available, min_order_qty, units_per_carton, supplier_code,
  /// supplier_uid, supplier_name. `supplier_name` is the supplier's company
  /// name copied onto the product (merchants cannot read `suppliers`); it
  /// falls back to supplier_code.
  static B2BProductModel fromFirestore(String docId, Map<String, dynamic> data) {
    final cartonPrice = _toDouble(data['carton_price']) ?? 0.0;
    final piecePrice = _toDouble(data['piece_price']) ?? 0.0;

    final unitsPerCarton = _toInt(data['units_per_carton']) ??
        (piecePrice > 0 ? (cartonPrice / piecePrice).round() : 1);

    final supplierCode = data['supplier_code']?.toString();
    final supplierUid = data['supplier_uid']?.toString();
    final supplierName = data['supplier_name']?.toString().trim() ?? '';

    return B2BProductModel(
      id: docId,
      name: (data['name'] ?? '').toString(),
      imageUrl: (data['image_url'] ?? '').toString(),
      supplierName:
          supplierName.isNotEmpty ? supplierName : (supplierCode ?? ''),
      supplierCode: supplierCode,
      supplierUid:
          (supplierUid == null || supplierUid.isEmpty) ? null : supplierUid,
      cartonPrice: cartonPrice,
      piecesPerCarton: unitsPerCarton > 0 ? unitsPerCarton : 1,
      piecePriceOverride: piecePrice > 0 ? piecePrice : null,
      minOrderQuantity: _toInt(data['min_order_qty']) ?? 1,
      category: normalizeCategory(data['category']?.toString()),
      isAvailable: data['is_available'] == true,
    );
  }

  /// Strips the English suffix from web-app categories so they match the
  /// app's chips, e.g. "ألبان وأجبان (Dairy & Cheese)" -> "ألبان وأجبان".
  static String normalizeCategory(String? raw) {
    final value = (raw ?? '').replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '').trim();
    return value.isEmpty ? 'عام' : value;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
