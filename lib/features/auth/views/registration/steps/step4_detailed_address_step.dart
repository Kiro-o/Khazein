import 'package:flutter/material.dart';

import '../../../../../core/constants/egypt_governorates.dart';
import '../../../../../core/utils/validators.dart';
import '../../../view_models/onboarding_view_model.dart';
import 'step_widgets.dart';

/// Step 4: the written address used by suppliers' drivers.
class Step4DetailedAddressStep extends StatefulWidget {
  final OnboardingViewModel viewModel;

  const Step4DetailedAddressStep({super.key, required this.viewModel});

  @override
  State<Step4DetailedAddressStep> createState() =>
      _Step4DetailedAddressStepState();
}

class _Step4DetailedAddressStepState extends State<Step4DetailedAddressStep> {
  final _formKey = GlobalKey<FormState>();
  late String? _governorate = widget.viewModel.governorate;
  late final _cityController = TextEditingController(
    text: widget.viewModel.city,
  );
  late final _addressController = TextEditingController(
    text: widget.viewModel.detailedAddress,
  );
  late final _landmarkController = TextEditingController(
    text: widget.viewModel.landmark,
  );

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _onNext() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    widget.viewModel.setAddressDetails(
      governorate: _governorate,
      city: _cityController.text,
      address: _addressController.text,
      landmark: _landmarkController.text,
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
          Expanded(
            child: ListView(
              children: [
                const StepHeader(
                  title: 'عنوان المحل',
                  subtitle: 'المندوب هيستخدم العنوان ده علشان يوصلك',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: const ValueKey('governorate'),
                  initialValue: _governorate,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: [
                    for (final name in EgyptGovernorates.all)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setState(() => _governorate = value),
                  validator: (value) => value == null ? 'اختار المحافظة' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('city'),
                  controller: _cityController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'المدينة أو الحي',
                    hintText: 'مثال: مدينة نصر',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'اكتب المدينة أو الحي'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('address'),
                  controller: _addressController,
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'العنوان بالتفصيل',
                    hintText: 'الشارع ورقم العمارة',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: Validators.validateAddress,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('landmark'),
                  controller: _landmarkController,
                  decoration: const InputDecoration(
                    labelText: 'علامة مميزة (اختياري)',
                    hintText: 'مثال: جنب صيدلية الشفاء',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
              ],
            ),
          ),
          StepError(viewModel: widget.viewModel),
          const SizedBox(height: 12),
          StepPrimaryButton(label: 'التالي', onPressed: _onNext),
        ],
      ),
    );
  }
}
