import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/b2b_product_model.dart';
import '../data/models/merchant_model.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/product_repository.dart';
import '../features/auth/views/welcome_gateway_screen.dart';
import '../features/cart/views/cart_screen.dart';
import '../features/home/widgets/cart_bar.dart';
import '../features/home/widgets/product_list_tile.dart';
import '../features/orders/views/orders_view.dart';

/// The merchant's home: a delivery-app style catalog (search, category
/// circles, a flat product list and a sticky cart bar) plus the orders and
/// account tabs.
///
/// Kept deliberately light for low-end phones: flat surfaces, no blur or
/// animations, lazily built lists and thumbnail-sized images.
class HomeScreen extends StatefulWidget {
  /// The signed-in merchant (from `users/{uid}`).
  final MerchantModel merchant;

  /// Overrides the live Firestore products stream (used by tests).
  final Stream<List<B2BProductModel>>? productsStream;

  const HomeScreen({super.key, required this.merchant, this.productsStream});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Type alias for backward compatibility with existing MerchantHomeScreen imports.
typedef MerchantHomeScreen = HomeScreen;

/// A catalog category with its icon in the category strip.
typedef _Category = ({String title, IconData icon});

class _HomeScreenState extends State<HomeScreen> {
  static const int _homeTab = 0;
  static const int _ordersTab = 1;
  static const int _accountTab = 2;

  static const String _allCategories = 'الكل';

  /// Known categories in display order; others from the catalog follow.
  static const List<_Category> _knownCategories = [
    (title: 'ألبان وأجبان', icon: Icons.egg_outlined),
    (title: 'مياه ومشروبات', icon: Icons.local_drink_outlined),
    (title: 'بقالة وزيوت', icon: Icons.soup_kitchen_outlined),
    (title: 'بقوليات وحبوب', icon: Icons.grain_outlined),
    (title: 'معلبات وصلصات', icon: Icons.inventory_2_outlined),
    (title: 'مستلزمات تصنيع وحلويات', icon: Icons.bakery_dining_outlined),
    (title: 'سناكس ومقرمشات', icon: Icons.cookie_outlined),
    (title: 'منظفات ومستلزمات تنظيف', icon: Icons.cleaning_services_outlined),
  ];

  final Map<String, int> _cartQuantities = {};
  final TextEditingController _searchController = TextEditingController();
  late Stream<List<B2BProductModel>> _productsStream;
  int _currentTab = _homeTab;
  String _selectedCategory = _allCategories;

  @override
  void initState() {
    super.initState();
    // Created once so rebuilds (tab switches, +/- taps) don't resubscribe.
    final injected = widget.productsStream;
    _productsStream = injected == null
        ? ProductRepository.instance.watchProducts()
        : injected.map((products) {
            ProductRepository.instance.registerAll(products);
            return products;
          });
    _searchController.addListener(() => setState(() {}));
  }

  /// Subscribes to the catalog again after an error (e.g. no internet).
  void _retryProducts() {
    if (widget.productsStream != null) return;
    setState(
      () => _productsStream = ProductRepository.instance.watchProducts(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  MerchantModel get _merchant => widget.merchant;

  int get _totalCartons =>
      _cartQuantities.values.fold(0, (total, qty) => total + qty);

  double get _totalCartPrice {
    var total = 0.0;
    for (final entry in _cartQuantities.entries) {
      final product = ProductRepository.instance.findById(entry.key);
      if (product != null) total += product.cartonPrice * entry.value;
    }
    return total;
  }

  void _updateQuantity(String productId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cartQuantities.remove(productId);
      } else {
        _cartQuantities[productId] = quantity;
      }
    });
  }

  Future<void> _openCart() async {
    final result = await Navigator.of(context).push<CartResult>(
      MaterialPageRoute(
        builder: (_) => CartScreen(
          merchant: _merchant,
          initialQuantities: _cartQuantities,
          onCartUpdated: (updated) {
            setState(() {
              _cartQuantities
                ..clear()
                ..addAll(updated);
            });
          },
        ),
      ),
    );
    if (result == CartResult.orderPlaced && mounted) {
      setState(() => _currentTab = _ordersTab);
    }
  }

  Future<void> _signOut() async {
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeGatewayScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // One subscription above the tabs: the products stream can only
            // be listened to once, and switching tabs must not re-listen.
            child: StreamBuilder<List<B2BProductModel>>(
              stream: _productsStream,
              builder: (context, snapshot) => switch (_currentTab) {
                _ordersTab => SafeArea(
                  child: OrdersView(
                    merchant: _merchant,
                    onReorder: (reorderedQuantities) {
                      setState(() {
                        reorderedQuantities.forEach((id, qty) {
                          _cartQuantities[id] =
                              (_cartQuantities[id] ?? 0) + qty;
                        });
                        _currentTab = _homeTab;
                      });
                    },
                  ),
                ),
                _accountTab => _AccountTab(
                  merchant: _merchant,
                  onSignOut: _signOut,
                ),
                _ => _buildCatalog(snapshot),
              },
            ),
          ),
        ),
        // Same max width as the body, so wide screens don't stretch it.
        bottomNavigationBar: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_totalCartons > 0 && _currentTab == _homeTab)
                  CartBar(
                    cartons: _totalCartons,
                    total: _totalCartPrice,
                    onTap: _openCart,
                  ),
                NavigationBar(
                  height: 64,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: AppColors.primarySurface,
                  selectedIndex: _currentTab,
                  onDestinationSelected: (index) =>
                      setState(() => _currentTab = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home, color: AppColors.primary),
                      label: 'الرئيسية',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(
                        Icons.receipt_long,
                        color: AppColors.primary,
                      ),
                      label: 'طلباتي',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(
                        Icons.person,
                        color: AppColors.primary,
                      ),
                      label: 'حسابي',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Catalog tab
  // ---------------------------------------------------------------------------

  Widget _buildCatalog(AsyncSnapshot<List<B2BProductModel>> snapshot) {
    final products = snapshot.data ?? const <B2BProductModel>[];
    final categories = _categoriesIn(products);
    if (!categories.any((c) => c.title == _selectedCategory)) {
      _selectedCategory = _allCategories;
    }
    final visible = _visibleProducts(products);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        if (products.isNotEmpty && _searchQuery.isEmpty)
          SliverToBoxAdapter(child: _buildCategoryStrip(categories)),
        SliverToBoxAdapter(
          child: _buildSectionTitle(snapshot.hasData ? visible.length : null),
        ),
        ..._buildProductSlivers(snapshot, visible),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  List<_Category> _categoriesIn(List<B2BProductModel> products) {
    final present = products.map((p) => p.category).toSet();
    final known = _knownCategories.map((c) => c.title).toSet();
    return [
      (title: _allCategories, icon: Icons.apps),
      ..._knownCategories.where((c) => present.contains(c.title)),
      for (final title in present.where((t) => !known.contains(t)))
        (title: title, icon: Icons.category_outlined),
    ];
  }

  List<B2BProductModel> _visibleProducts(List<B2BProductModel> products) {
    final query = _searchQuery;
    if (query.isNotEmpty) {
      return products
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                p.supplierName.toLowerCase().contains(query),
          )
          .toList();
    }
    if (_selectedCategory == _allCategories) return products;
    return products.where((p) => p.category == _selectedCategory).toList();
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 40,
                  height: 40,
                  semanticLabel: 'خزين',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'التوصيل إلى',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      _merchant.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _merchant.fullLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('catalog_search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث عن منتج أو شركة',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _searchController.clear,
                    ),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStrip(List<_Category> categories) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryCircle(
            category: category,
            selected: category.title == _selectedCategory,
            onTap: () => setState(() => _selectedCategory = category.title),
          );
        },
      ),
    );
  }

  /// [count] is null while products are loading.
  Widget _buildSectionTitle(int? count) {
    final title = _searchQuery.isNotEmpty
        ? 'نتائج البحث'
        : (_selectedCategory == _allCategories
              ? 'كل المنتجات'
              : _selectedCategory);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (count != null)
            Text(
              '$count منتج',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildProductSlivers(
    AsyncSnapshot<List<B2BProductModel>> snapshot,
    List<B2BProductModel> visible,
  ) {
    if (snapshot.hasError) {
      return [
        SliverToBoxAdapter(
          child: _ProductsError(
            error: snapshot.error!,
            onRetry: _retryProducts,
          ),
        ),
      ];
    }
    if (!snapshot.hasData) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ),
      ];
    }
    if (visible.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _EmptyState(
            message: _searchQuery.isNotEmpty
                ? 'مفيش منتجات بالاسم ده'
                : 'مفيش منتجات متاحة دلوقتي',
          ),
        ),
      ];
    }
    return [
      SliverList.separated(
        itemCount: visible.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.divider,
        ),
        itemBuilder: (context, index) {
          final product = visible[index];
          return ProductListTile(
            key: ValueKey(product.id),
            product: product,
            quantity: _cartQuantities[product.id] ?? 0,
            onQuantityChanged: (qty) => _updateQuantity(product.id, qty),
          );
        },
      ),
    ];
  }
}

class _CategoryCircle extends StatelessWidget {
  final _Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCircle({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                color: selected ? Colors.white : AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ProductsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message =
        error is FirebaseException &&
            (error as FirebaseException).code == 'permission-denied'
        ? 'مش مسموح بعرض المنتجات لحسابك'
        : 'تعذر تحميل المنتجات، اتأكد من الإنترنت';
    debugPrint('Products failed to load: $error');
    return _EmptyState(
      message: message,
      icon: Icons.wifi_off_outlined,
      action: OutlinedButton(
        onPressed: onRetry,
        child: const Text('حاول تاني'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;

  const _EmptyState({
    required this.message,
    this.icon = Icons.inventory_2_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Account tab
// -----------------------------------------------------------------------------

class _AccountTab extends StatelessWidget {
  final MerchantModel merchant;
  final VoidCallback onSignOut;

  const _AccountTab({required this.merchant, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(
                    Icons.storefront_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant.storeName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        merchant.merchantName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _AccountRow(
            icon: Icons.phone_outlined,
            title: 'رقم الموبايل',
            value: merchant.phone,
          ),
          _AccountRow(
            icon: Icons.location_on_outlined,
            title: 'عنوان المحل',
            value: merchant.address.isNotEmpty
                ? '${merchant.address}، ${merchant.fullLocation}'
                : merchant.fullLocation,
          ),
          _AccountRow(
            icon: Icons.category_outlined,
            title: 'نشاط المحل',
            value: merchant.category,
          ),
          const Divider(height: 1, color: AppColors.divider),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _AccountRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      ),
    );
  }
}
