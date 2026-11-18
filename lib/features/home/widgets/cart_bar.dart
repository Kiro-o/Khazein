import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Sticky "view cart" bar shown above the bottom tabs once the cart has
/// items.
class CartBar extends StatelessWidget {
  final int cartons;
  final double total;
  final VoidCallback onTap;

  const CartBar({
    super.key,
    required this.cartons,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalText = total.truncateToDouble() == total
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const ValueKey('cart_bar'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$cartons',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'عرض السلة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$totalText ج.م',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
