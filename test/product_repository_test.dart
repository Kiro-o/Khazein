import 'package:flutter_test/flutter_test.dart';
import 'package:khazeen_app/data/repositories/product_repository.dart';

void main() {
  group('ProductRepository.fromFirestore', () {
    final doc = <String, dynamic>{
      'name': 'حليب كامل الدسم',
      'carton_price': 420,
      'piece_price': '35',
      'image_url': 'https://example.com/milk.png',
      'category': 'ألبان وأجبان (Dairy & Cheese)',
      'is_available': true,
      'min_order_qty': 2,
      'units_per_carton': 12,
      'supplier_code': '#12',
      'supplier_uid': 'uid_123',
    };

    test('maps web-app fields and normalizes category', () {
      final p = ProductRepository.fromFirestore(
          'p1', {...doc, 'supplier_name': 'شركة جهينة'});
      expect(p.name, 'حليب كامل الدسم');
      expect(p.cartonPrice, 420.0);
      expect(p.piecePrice, 35.0);
      expect(p.piecesPerCarton, 12);
      expect(p.minOrderQuantity, 2);
      expect(p.category, 'ألبان وأجبان');
      expect(p.supplierName, 'شركة جهينة');
      expect(p.supplierCode, '#12');
      expect(p.isAvailable, isTrue);
    });

    test('falls back to supplier_code when supplier_name is missing', () {
      final p = ProductRepository.fromFirestore('p1', doc);
      expect(p.supplierName, '#12');
    });

    test('normalizeCategory handles plain and empty values', () {
      expect(ProductRepository.normalizeCategory('بقالة وزيوت'), 'بقالة وزيوت');
      expect(
        ProductRepository.normalizeCategory('مياه ومشروبات (Water & Drinks) '),
        'مياه ومشروبات',
      );
      expect(ProductRepository.normalizeCategory(null), 'عام');
    });
  });
}
