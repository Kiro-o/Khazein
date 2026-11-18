import 'package:flutter/material.dart';
import 'package:khazeen_app/core/theme/app_colors.dart';
import 'package:khazeen_app/core/utils/validators.dart';
import 'package:khazeen_app/features/auth/view_models/onboarding_view_model.dart';

/// Step 1: Basic Information (البيانات)
class Step1BasicInfoStep extends StatefulWidget {
  final OnboardingViewModel viewModel;

  const Step1BasicInfoStep({super.key, required this.viewModel});

  @override
  State<Step1BasicInfoStep> createState() => _Step1BasicInfoStepState();
}

class _Step1BasicInfoStepState extends State<Step1BasicInfoStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _storeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.viewModel.fullName);
    _storeController = TextEditingController(text: widget.viewModel.storeName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  void _onNextPressed() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    widget.viewModel.setBasicInfo(
      fullName: _nameController.text,
      storeName: _storeController.text,
    );

    widget.viewModel.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'البيانات 📝',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'أدخل بياناتك الأساسية لتسجيل دكانك في منظومة التوريد الذكي على خزين',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // 1. Merchant Full Name (الاسم بالكامل)
          TextFormField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            decoration: const InputDecoration(
              labelText: 'الاسم بالكامل',
              hintText: 'أدخل الاسم بالكامل',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: Validators.validateMerchantName,
          ),
          const SizedBox(height: 16),

          // 2. Store Name (إسم المنشأة)
          TextFormField(
            controller: _storeController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'إسم المنشأة',
              hintText: 'مثال: سوبر ماركت النور',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
            validator: Validators.validateStoreName,
          ),

          const Spacer(),

          // Bottom CTA: "التالي"
          ElevatedButton(
            onPressed: _onNextPressed,
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
      ),
    );
  }
}
