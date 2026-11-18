import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../home/views/merchant_home_screen.dart';
import '../../../view_models/onboarding_view_model.dart';
import 'step_widgets.dart';

/// Step 7: the account was created; a short summary and the way in.
class Step7SuccessStep extends StatelessWidget {
  final OnboardingViewModel viewModel;

  const Step7SuccessStep({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final merchant = viewModel.authenticatedMerchant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.primarySurface,
          child: Icon(Icons.check_rounded, color: AppColors.primary, size: 52),
        ),
        const SizedBox(height: 20),
        const Text(
          'حسابك جاهز',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'اطلب نواقص محلك بسعر الجملة والتوصيل لحد باب المحل',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        if (merchant != null)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.storefront_outlined,
                  label: 'المحل',
                  value: merchant.storeName,
                ),
                _SummaryRow(
                  icon: Icons.category_outlined,
                  label: 'النشاط',
                  value: merchant.category,
                ),
                _SummaryRow(
                  icon: Icons.location_on_outlined,
                  label: 'العنوان',
                  value: merchant.fullLocation,
                ),
              ],
            ),
          ),
        const Spacer(),
        StepPrimaryButton(
          label: 'ابدأ الطلب',
          onPressed: merchant == null
              ? null
              : () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => MerchantHomeScreen(merchant: merchant),
                  ),
                  (route) => false,
                ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
