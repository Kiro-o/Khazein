/// B2B Product Model representing wholesale products in Khazeen (خزين).
class B2BProductModel {
  final String id;
  final String name;
  final String imageUrl;
  final String supplierName;
  final String? supplierCode;

  /// `products.supplier_uid`: Firebase uid of the supplier selling it.
  final String? supplierUid;
  final String deliverySla;
  final double cartonPrice;
  final double? oldCartonPrice;
  final int piecesPerCarton;
  final double? piecePriceOverride;
  final int? discountPercentageOverride;
  final String? bonusTag;
  final int? minOrderQuantity;
  final String category;
  final bool isAvailable;

  const B2BProductModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.supplierName,
    this.supplierCode,
    this.supplierUid,
    this.deliverySla = 'توصيل خلال 24 ساعة',
    required this.cartonPrice,
    this.oldCartonPrice,
    required this.piecesPerCarton,
    this.piecePriceOverride,
    this.discountPercentageOverride,
    this.bonusTag,
    this.minOrderQuantity,
    this.category = 'عام',
    this.isAvailable = true,
  });

  /// What one piece costs when buying the carton: carton price divided by
  /// pieces per carton, the same as the cart. [piecePriceOverride] (the
  /// stored `piece_price`) is only used when the carton size is unknown.
  double get piecePrice => piecesPerCarton > 0
      ? cartonPrice / piecesPerCarton
      : (piecePriceOverride ?? cartonPrice);

  /// Whether product has an active discount
  bool get hasDiscount =>
      oldCartonPrice != null && oldCartonPrice! > cartonPrice;

  /// Computed discount percentage (e.g. 12 for -12%)
  int? get discountPercentage {
    if (discountPercentageOverride != null) {
      return discountPercentageOverride;
    }
    if (hasDiscount) {
      final diff = oldCartonPrice! - cartonPrice;
      return (diff / oldCartonPrice! * 100).round();
    }
    return null;
  }

  /// Formatted carton price string
  String get formattedCartonPrice {
    final isInt = cartonPrice.truncateToDouble() == cartonPrice;
    return '${cartonPrice.toStringAsFixed(isInt ? 0 : 2)} ج.م';
  }

  /// Formatted old carton price string
  String? get formattedOldPrice {
    if (!hasDiscount) return null;
    final isInt = oldCartonPrice!.truncateToDouble() == oldCartonPrice!;
    return '${oldCartonPrice!.toStringAsFixed(isInt ? 0 : 2)} ج.م';
  }

  /// Formatted single piece price string (two decimals like the cart, e.g.
  /// 81.67 for a 980 EGP carton of 12).
  String get formattedPiecePrice {
    final isInt = piecePrice.truncateToDouble() == piecePrice;
    return '${piecePrice.toStringAsFixed(isInt ? 0 : 2)} ج.م';
  }

  /// Subtext unit breakdown (e.g. "سعر القطعة: 40 ج.م | كرتونة 12 قطعة")
  String get unitBreakdownText =>
      'سعر القطعة: $formattedPiecePrice | كرتونة $piecesPerCarton قطعة';

  /// Minimum order quantity tag text
  String? get moqText =>
      minOrderQuantity != null && minOrderQuantity! > 1
          ? 'أقل طلب: $minOrderQuantity كرتونة'
          : null;

  B2BProductModel copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? supplierName,
    String? supplierCode,
    String? supplierUid,
    String? deliverySla,
    double? cartonPrice,
    double? oldCartonPrice,
    int? piecesPerCarton,
    double? piecePriceOverride,
    int? discountPercentageOverride,
    String? bonusTag,
    int? minOrderQuantity,
    String? category,
    bool? isAvailable,
  }) {
    return B2BProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      supplierName: supplierName ?? this.supplierName,
      supplierCode: supplierCode ?? this.supplierCode,
      supplierUid: supplierUid ?? this.supplierUid,
      deliverySla: deliverySla ?? this.deliverySla,
      cartonPrice: cartonPrice ?? this.cartonPrice,
      oldCartonPrice: oldCartonPrice ?? this.oldCartonPrice,
      piecesPerCarton: piecesPerCarton ?? this.piecesPerCarton,
      piecePriceOverride: piecePriceOverride ?? this.piecePriceOverride,
      discountPercentageOverride:
          discountPercentageOverride ?? this.discountPercentageOverride,
      bonusTag: bonusTag ?? this.bonusTag,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'supplierName': supplierName,
      if (supplierCode != null) 'supplierCode': supplierCode,
      if (supplierUid != null) 'supplierUid': supplierUid,
      'deliverySla': deliverySla,
      'cartonPrice': cartonPrice,
      if (oldCartonPrice != null) 'oldCartonPrice': oldCartonPrice,
      'piecesPerCarton': piecesPerCarton,
      if (piecePriceOverride != null) 'piecePriceOverride': piecePriceOverride,
      if (discountPercentageOverride != null)
        'discountPercentageOverride': discountPercentageOverride,
      if (bonusTag != null) 'bonusTag': bonusTag,
      if (minOrderQuantity != null) 'minOrderQuantity': minOrderQuantity,
      'category': category,
      'isAvailable': isAvailable,
    };
  }

  factory B2BProductModel.fromJson(Map<String, dynamic> json) {
    return B2BProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      supplierName: json['supplierName']?.toString() ?? '',
      supplierCode: json['supplierCode']?.toString(),
      supplierUid: json['supplierUid']?.toString(),
      deliverySla: json['deliverySla']?.toString() ?? 'توصيل خلال 24 ساعة',
      cartonPrice: (json['cartonPrice'] as num?)?.toDouble() ?? 0.0,
      oldCartonPrice: (json['oldCartonPrice'] as num?)?.toDouble(),
      piecesPerCarton: (json['piecesPerCarton'] as num?)?.toInt() ?? 1,
      piecePriceOverride: (json['piecePriceOverride'] as num?)?.toDouble(),
      discountPercentageOverride:
          (json['discountPercentageOverride'] as num?)?.toInt(),
      bonusTag: json['bonusTag']?.toString(),
      minOrderQuantity: (json['minOrderQuantity'] as num?)?.toInt(),
      category: json['category']?.toString() ?? 'عام',
      isAvailable: json['isAvailable'] == true || json['isAvailable'] == null,
    );
  }
}
