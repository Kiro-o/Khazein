import 'package:flutter/material.dart';
import 'package:khazeen_app/core/theme/app_colors.dart';
import 'package:khazeen_app/data/repositories/auth_repository.dart';
import 'package:khazeen_app/features/auth/view_models/onboarding_view_model.dart';
import 'package:khazeen_app/features/auth/views/welcome_gateway_screen.dart';

import 'steps/step1_basic_info_step.dart';
import 'steps/step2_store_category_step.dart';
import 'steps/step3_map_pin_step.dart';
import 'steps/step4_detailed_address_step.dart';
import 'steps/step7_success_step.dart';
import 'steps/store_photo_step.dart';

/// Multi-Step B2B Merchant Registration Flow (Screens 4 to 8)
/// Features a Segmented Progress Bar (pill-shaped indicators in Emerald Green #128A56)
/// and sequential step forms.
///
/// Expects a signed-in Firebase user (phone verified); the profile is saved
/// to `users/{uid}` on the last step.
class MerchantRegistrationScreen extends StatefulWidget {
  const MerchantRegistrationScreen({super.key});

  @override
  State<MerchantRegistrationScreen> createState() =>
      _MerchantRegistrationScreenState();
}

class _MerchantRegistrationScreenState
    extends State<MerchantRegistrationScreen> {
  late final OnboardingViewModel _viewModel;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _viewModel = OnboardingViewModel();
    _pageController = PageController(initialPage: _viewModel.currentStep);
    _viewModel.addListener(_onViewModelStepChanged);
  }

  void _onViewModelStepChanged() {
    if (_pageController.hasClients &&
        _pageController.page?.round() != _viewModel.currentStep) {
      _pageController.jumpToPage(_viewModel.currentStep);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelStepChanged);
    _pageController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// Abandons registration: signs out so another number can be used.
  Future<void> _leaveRegistration() async {
    await AuthRepository.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeGatewayScreen()),
      (route) => false,
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'بياناتك';
      case 1:
        return 'نوع النشاط';
      case 2:
        return 'مكان المحل';
      case 3:
        return 'العنوان';
      case 4:
        return 'صورة الواجهة';
      case 5:
        return 'صورة من جوّه';
      case 6:
        return 'تم التسجيل';
      default:
        return 'إنشاء حساب جديد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              if (_viewModel.currentStep > 0 && _viewModel.currentStep < 6) {
                _viewModel.previousStep();
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                _leaveRegistration();
              }
            },
          ),
          centerTitle: true,
          title: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) {
              return Text(
                _getStepTitle(_viewModel.currentStep),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              );
            },
          ),
          actions: [
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                if (_viewModel.currentStep >= 6) return const SizedBox.shrink();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'خطوة ${_viewModel.currentStep + 1} من ${OnboardingViewModel.totalSteps}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Segmented Progress Bar (Pill-shaped indicators in Emerald Green #128A56)
              ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  if (_viewModel.currentStep >= OnboardingViewModel.doneStep) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: List.generate(OnboardingViewModel.totalSteps, (
                        index,
                      ) {
                        final isCompleted = index <= _viewModel.currentStep;

                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              left: index < OnboardingViewModel.totalSteps - 1
                                  ? 4
                                  : 0,
                              right: index > 0 ? 4 : 0,
                            ),
                            height: 4,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

              // Step Form Content managed via dedicated PageController
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Step1BasicInfoStep(
                        key: const ValueKey('step_1'),
                        viewModel: _viewModel,
                      ),
                      Step2StoreCategoryStep(
                        key: const ValueKey('step_2'),
                        viewModel: _viewModel,
                      ),
                      Step3MapPinStep(
                        key: const ValueKey('step_3'),
                        viewModel: _viewModel,
                      ),
                      Step4DetailedAddressStep(
                        key: const ValueKey('step_4'),
                        viewModel: _viewModel,
                      ),
                      StorePhotoStep(
                        key: const ValueKey('step_5'),
                        viewModel: _viewModel,
                        interior: false,
                      ),
                      StorePhotoStep(
                        key: const ValueKey('step_6'),
                        viewModel: _viewModel,
                        interior: true,
                      ),
                      Step7SuccessStep(
                        key: const ValueKey('step_7'),
                        viewModel: _viewModel,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
