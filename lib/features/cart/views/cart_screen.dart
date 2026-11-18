import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/merchant_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../home/widgets/product_list_tile.dart';

/// What the cart screen returns to the home screen.
enum CartResult {
  /// An order was placed; the home screen opens the orders tab.
  orderPlaced,
}

/// The cart and checkout in one screen (like delivery apps): items grouped
/// by supplier, delivery address and notes, cash on delivery, and the total.
///
/// Placing the order splits it into one sub-order per supplier
/// ([OrderRepository.placeOrder]); prices are re-checked against the live
/// catalog there.
class CartScreen extends StatefulWidget {
  final MerchantModel merchant;
  final Map<String, int> initialQuantities;
  final ValueChanged<Map<String, int>>? onCartUpdated;

  const CartScreen({
    super.key,
    required this.merchant,
    required this.initialQuantities,
    this.onCartUpdated,
  });

  /// The merchant's saved address as one line.
  static String addressOf(MerchantModel merchant) => [
        merchant.address,
        if (merchant.landmark?.isNotEmpty ?? false) merchant.landmark!,
        merchant.city,
        merchant.governorate,
      ].where((part) => part.trim().isNotEmpty).join('، ');

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final Map<String, int> _quantities = Map.of(widget.initialQuantities);
  late String _deliveryAddress = CartScreen.addressOf(widget.merchant);
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _setQuantity(String productId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _quantities.remove(productId);
      } else {
        _quantities[productId] = quantity;
      }
    });
    widget.onCartUpdated?.call(Map.unmodifiable(_quantities));
  }

  void _clearCart() {
    setState(_quantities.clear);
    widget.onCartUpdated?.call(const {});
  }

  /// Cart lines for products still in the catalog (prices are current).
  List<CartItem> get _items => [
        for (final entry in _quantities.entries)
          if (ProductRepository.instance.findById(entry.key)
              case final product?)
            CartItem.fromProduct(product, entry.value),
      ];

  Future<void> _confirmClear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تفريغ السلة؟'),
          content: const Text('كل المنتجات هتتشال من السلة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لأ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('فرّغ السلة'),
            ),
          ],
        ),
      ),
    );
    if (clear == true) _clearCart();
  }

  Future<void> _editAddress() async {
    final controller = TextEditingController(text: _deliveryAddress);
    final address = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'عنوان التوصيل للطلب ده',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('address_field'),
                controller: controller,
                autofocus: true,
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('حفظ العنوان'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (address != null && address.length >= 5) {
      setState(() => _deliveryAddress = address);
    }
  }

  Future<void> _placeOrder(List<CartItem> items) async {
    setState(() => _isSubmitting = true);
    final notes = _notesController.text.trim();
    try {
      final order = await OrderRepository.instance.placeOrder(
        merchant: widget.merchant,
        items: items.map((item) => item.toOrderItemModel()).toList(),
        deliveryAddress: _deliveryAddress,
        deliveryNotes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      _clearCart();
      await _showOrderPlaced(order);
      if (!mounted) return;
      Navigator.of(context).pop(CartResult.orderPlaced);
    } on OrderFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showOrderPlaced(MasterOrder order) {
    final suppliers = order.subOrders.length;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: AppColors.primary,
            size: 52,
          ),
          title: Text('طلبك ${order.formattedOrderNumber} وصل'),
          content: Text(
            suppliers == 1
                ? 'المورد هيبدأ يجهّز طلبك، وتقدر تتابعه من "طلباتي".'
                : 'طلبك اتقسم على $suppliers موردين، وكل واحد هيوصّل شحنته. تابعهم من "طلباتي".',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            ElevatedButton(
              key: const ValueKey('track_order'),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تابع طلبك'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final groups = SupplierGroup.fromCartItems(items);
    final total = items.fold(0.0, (acc, item) => acc + item.totalPrice);
    final cartons = items.fold(0, (acc, item) => acc + item.quantity);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('السلة'),
          actions: [
            if (items.isNotEmpty)
              IconButton(
                tooltip: 'تفريغ السلة',
                icon: const Icon(Icons.delete_outline),
                onPressed: _isSubmitting ? null : _confirmClear,
              ),
          ],
        ),
        body: items.isEmpty
            ? _EmptyCart(onBrowse: () => Navigator.of(context).pop())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final group in groups) ...[
                        _SectionHeader(
                          title: group.supplierName,
                          trailing: group.deliverySla,
                        ),
                        for (final item in group.items)
                          if (ProductRepository.instance
                                  .findById(item.productId)
                              case final product?)
                            ProductListTile(
                              key: ValueKey(item.productId),
                              product: product,
                              quantity: item.quantity,
                              onQuantityChanged: (qty) =>
                                  _setQuantity(item.productId, qty),
                            ),
                      ],
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.add),
                        label: const Text('ضيف منتجات تانية'),
                      ),
                      const _Divider(),
                      const _SectionHeader(title: 'التوصيل إلى'),
                      ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          widget.merchant.storeName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _deliveryAddress,
                          style: const TextStyle(height: 1.5),
                        ),
                        trailing: TextButton(
                          onPressed: _isSubmitting ? null : _editAddress,
                          child: const Text('تعديل'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          key: const ValueKey('delivery_notes'),
                          controller: _notesController,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            hintText: 'ملاحظات للمندوب (اختياري)',
                            counterText: '',
                          ),
                        ),
                      ),
                      const _Divider(),
                      const _SectionHeader(title: 'طريقة الدفع'),
                      const ListTile(
                        leading: Icon(
                          Icons.payments_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text('كاش عند الاستلام'),
                        subtitle: Text('ادفع للمندوب لما البضاعة توصل'),
                      ),
                      const _Divider(),
                      _SummaryRow(
                        label: 'المنتجات ($cartons كرتونة)',
                        value: _money(total),
                      ),
                      const _SummaryRow(
                        label: 'التوصيل',
                        value: 'مجاناً',
                        valueColor: AppColors.primary,
                      ),
                      _SummaryRow(
                        label: 'الإجمالي',
                        value: _money(total),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: items.isEmpty
            ? null
            : SafeArea(
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: ElevatedButton(
                        key: const ValueKey('place_order'),
                        onPressed:
                            _isSubmitting ? null : () => _placeOrder(items),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text('تأكيد الطلب · ${_money(total)}'),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  static String _money(double value) {
    final text = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$text ج.م';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? AppColors.textPrimary : AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 24,
        thickness: 6,
        color: AppColors.slateGray,
      );
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onBrowse;

  const _EmptyCart({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'السلة فاضية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'ضيف المنتجات اللي محلك محتاجها',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onBrowse,
              style: OutlinedButton.styleFrom(minimumSize: const Size(180, 46)),
              child: const Text('تصفّح المنتجات'),
            ),
          ],
        ),
      ),
    );
  }
}
