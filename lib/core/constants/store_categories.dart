import 'package:flutter/material.dart';

/// Store category model for Step 2 of merchant registration.
class StoreCategory {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;

  const StoreCategory({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
  });
}

/// The 8 standard FMCG retail store types on Khazeen in Egypt.
class StoreCategories {
  StoreCategories._();

  static const List<StoreCategory> list = [
    StoreCategory(
      id: 'supermarket',
      name: 'سوبر ماركت',
      subtitle: 'محل تجزئة كبير يبيع أغذية ومستلزمات منزلية',
      icon: Icons.storefront_rounded,
    ),
    StoreCategory(
      id: 'grocery',
      name: 'بقالة',
      subtitle: 'محل بقالة تقليدي يوفر السلع الأساسية اليومية',
      icon: Icons.shopping_basket_rounded,
    ),
    StoreCategory(
      id: 'kiosk',
      name: 'كشك',
      subtitle: 'كشك بيع المشروبات، الحلوى، والمقرمشات السريعة',
      icon: Icons.store_mall_directory_rounded,
    ),
    StoreCategory(
      id: 'wholesaler',
      name: 'تاجر جملة',
      subtitle: 'مخزن أو نقطة توزيع جملة ونصف جملة',
      icon: Icons.inventory_2_rounded,
    ),
    StoreCategory(
      id: 'spices',
      name: 'محل عطارة',
      subtitle: 'توابل، بقوليات، أعشاب، ومستلزمات العطارة',
      icon: Icons.grain_rounded,
    ),
    StoreCategory(
      id: 'cafe',
      name: 'كافيه',
      subtitle: 'مقهى أو كافتيريا لشراء العصائر والمشروبات بالجملة',
      icon: Icons.coffee_rounded,
    ),
    StoreCategory(
      id: 'detergents',
      name: 'محل منظفات',
      subtitle: 'منظفات منزلية وشخصية وورقيات',
      icon: Icons.cleaning_services_rounded,
    ),
    StoreCategory(
      id: 'restaurant',
      name: 'مطعم',
      subtitle: 'مطعم أو وجبات سريعة يحتاج توريدات غذائية دورية',
      icon: Icons.restaurant_rounded,
    ),
  ];

  static List<StoreCategory> search(String query) {
    if (query.trim().isEmpty) return list;
    final q = query.trim().toLowerCase();
    return list.where((cat) {
      return cat.name.toLowerCase().contains(q) ||
          cat.subtitle.toLowerCase().contains(q);
    }).toList();
  }
}
