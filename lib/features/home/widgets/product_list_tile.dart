import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/b2b_product_model.dart';

/// One product row in a list (image, name, carton details, price) with an
/// add button that turns into a quantity stepper, like a delivery app menu.
///
/// Flat on purpose (no shadows, blur or animations) to stay light on
/// low-end phones.
class ProductListTile extends StatelessWidget {
  final B2BProductModel product;

  /// Cartons of this product in the cart (0 when not added).
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  const ProductListTile({
    super.key,
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
  });

  static const double _imageSize = 64;

  /// Quantity after tapping + or -: the first add jumps to the minimum
  /// order, and going below the minimum removes the product.
  static int nextQuantity(
    int current,
    int minOrder, {
    required bool increment,
  }) {
    final moq = minOrder < 1 ? 1 : minOrder;
    if (increment) return current < moq ? moq : current + 1;
    final updated = current - 1;
    return updated < moq ? 0 : updated;
  }

  int get _minOrder => product.minOrderQuantity ?? 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _ProductImage(url: product.imageUrl, size: _imageSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'كرتونة ${product.piecesPerCarton} قطعة · ${product.supplierName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_minOrder > 1)
                  Text(
                    'أقل طلب $_minOrder كرتونة',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentDark,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  product.formattedCartonPrice,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (quantity == 0)
            _SquareButton(
              key: const ValueKey('add_to_cart'),
              icon: Icons.add,
              tooltip: 'أضف ${product.name}',
              onTap: () => onQuantityChanged(
                nextQuantity(quantity, _minOrder, increment: true),
              ),
            )
          else
            _QuantityStepper(
              quantity: quantity,
              decrementRemoves:
                  nextQuantity(quantity, _minOrder, increment: false) == 0,
              onIncrement: () => onQuantityChanged(
                nextQuantity(quantity, _minOrder, increment: true),
              ),
              onDecrement: () => onQuantityChanged(
                nextQuantity(quantity, _minOrder, increment: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String url;
  final double size;

  const _ProductImage({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.slateGray,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.textMuted,
        size: 28,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url.isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Decode at thumbnail size: full-size photos use a lot of
              // memory on low-end phones.
              memCacheWidth: kIsWeb ? null : (size * 3).round(),
              // On web the default <img> path renders black after the list
              // is rebuilt (CanvasKit); decoding fetched bytes does not.
              // Needs CORS on the image host.
              imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
              fadeInDuration: Duration.zero,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;

  /// Shows a trash icon when the next tap removes the product.
  final bool decrementRemoves;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QuantityStepper({
    required this.quantity,
    required this.decrementRemoves,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            key: const ValueKey('increment'),
            icon: Icons.add,
            label: 'زيادة',
            onTap: onIncrement,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepperButton(
            key: const ValueKey('decrement'),
            icon: decrementRemoves ? Icons.delete_outline : Icons.remove,
            label: 'تقليل',
            onTap: onDecrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StepperButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
