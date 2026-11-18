import 'package:flutter/material.dart';
import 'package:khazeen_app/core/theme/app_colors.dart';
import 'package:khazeen_app/features/auth/view_models/onboarding_view_model.dart';

/// Step 2: Store Category Selection (اختيار نوع المنشأة)
class Step2StoreCategoryStep extends StatefulWidget {
  final OnboardingViewModel viewModel;

  const Step2StoreCategoryStep({super.key, required this.viewModel});

  @override
  State<Step2StoreCategoryStep> createState() => _Step2StoreCategoryStepState();
}

class _Step2StoreCategoryStepState extends State<Step2StoreCategoryStep> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.viewModel.categorySearchQuery;
    _searchController.addListener(() {
      widget.viewModel.updateCategorySearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final categories = vm.filteredCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختيار نوع المنشأة 🏪',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'اختر النشاط التجاري لمتجرك لتخصيص العروض وكراتين الجملة المناسبة لك',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),

        // Search Bar: "دور على نوع منشأتك"
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'دور على نوع منشأتك',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      vm.updateCategorySearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Scrollable Selectable List Tiles
        Expanded(
          child: categories.isEmpty
              ? const Center(
                  child: Text(
                    'لم يتم العثور على نشاط مطابق، يرجى تجربة كلمة بحث أخرى',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = vm.selectedCategory == cat.name;

                    return GestureDetector(
                      onTap: () => vm.selectCategory(cat.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primarySurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Category Icon Container
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                cat.icon,
                                color: isSelected ? Colors.white : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Name & Subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppColors.primaryDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cat.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected
                                          ? AppColors.primaryDark.withValues(alpha: 0.8)
                                          : AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Custom Radio Indicator
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                                  width: isSelected ? 6 : 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 16),

        // Bottom CTA: "التالي"
        ElevatedButton(
          onPressed: () => vm.nextStep(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 2,
            shadowColor: AppColors.primary.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'التالي',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
