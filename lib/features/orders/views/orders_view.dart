import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/merchant_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/order_repository.dart';

/// "طلباتي": the merchant's orders, live from Firestore. Each order shows
/// one row per supplier shipment with its status, and can be ordered again.
class OrdersView extends StatefulWidget {
  final MerchantModel merchant;
  final ValueChanged<Map<String, int>>? onReorder;

  /// Overrides the live Firestore orders stream (used by tests).
  final Stream<List<MasterOrder>>? ordersStream;

  const OrdersView({
    super.key,
    required this.merchant,
    this.onReorder,
    this.ordersStream,
  });

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  late Stream<List<MasterOrder>> _ordersStream = _subscribe();

  Stream<List<MasterOrder>> _subscribe() =>
      widget.ordersStream ??
      OrderRepository.instance.watchMerchantOrders(widget.merchant.id);

  void _retry() => setState(() => _ordersStream = _subscribe());

  void _reorder(MasterOrder order) {
    widget.onReorder?.call(OrderRepository.reorderQuantities(order));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ضفنا منتجات طلب ${order.formattedOrderNumber} للسلة'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.slateGray,
        appBar: AppBar(title: const Text('طلباتي')),
        body: StreamBuilder<List<MasterOrder>>(
          stream: _ordersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Orders stream failed: ${snapshot.error}');
              return _Message(
                icon: Icons.wifi_off_outlined,
                title: 'مقدرناش نحمّل طلباتك',
                body: 'اتأكد من الإنترنت وحاول تاني',
                action: OutlinedButton(
                  onPressed: _retry,
                  child: const Text('حاول تاني'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final orders = snapshot.data!;
            if (orders.isEmpty) {
              return const _Message(
                icon: Icons.receipt_long_outlined,
                title: 'لسه مفيش طلبات',
                body: 'أول طلب هتعمله هيظهر هنا وتقدر تتابعه',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _OrderCard(
                order: orders[index],
                onReorder: () => _reorder(orders[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final MasterOrder order;
  final VoidCallback onReorder;

  const _OrderCard({required this.order, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    final date = order.createdAt;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Text(
                  'طلب ${order.formattedOrderNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  order.formattedTotal,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          for (final sub in order.subOrders) _ShipmentRow(subOrder: sub),
          const Divider(height: 1, color: AppColors.divider),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  order.paymentMethod.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onReorder,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('اطلب تاني'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShipmentRow extends StatelessWidget {
  final SubOrder subOrder;

  const _ShipmentRow({required this.subOrder});

  static (Color, Color) _colors(OrderStatus status) => switch (status) {
        OrderStatus.delivered => (AppColors.primary, AppColors.primarySurface),
        OrderStatus.cancelled => (AppColors.error, const Color(0xFFFEF2F2)),
        OrderStatus.outForDelivery => (
            const Color(0xFF1D4ED8),
            const Color(0xFFEFF6FF),
          ),
        OrderStatus.pending ||
        OrderStatus.processing =>
          (const Color(0xFFB45309), const Color(0xFFFFFBEB)),
      };

  @override
  Widget build(BuildContext context) {
    final (color, background) = _colors(subOrder.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subOrder.supplierName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${subOrder.totalCartons} كرتونة · ${subOrder.formattedSubtotal}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subOrder.status.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
