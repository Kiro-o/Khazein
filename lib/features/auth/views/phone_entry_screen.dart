import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import 'request_otp.dart';
import 'signup/otp_verification_screen.dart';

/// Phone number entry shared by login and sign-up: validates the Egyptian
/// number, sends the SMS code and opens the OTP screen for [purpose].
class PhoneEntryScreen extends StatefulWidget {
  final OtpPurpose purpose;
  final String title;
  final String subtitle;

  /// Footer link to the other flow, e.g. "no account? create one".
  final String switchQuestion;
  final String switchAction;
  final WidgetBuilder switchTo;

  const PhoneEntryScreen({
    super.key,
    required this.purpose,
    required this.title,
    required this.subtitle,
    required this.switchQuestion,
    required this.switchAction,
    required this.switchTo,
  });

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  String? _errorMessage;
  bool _isSending = false;

  bool get _isPhoneValid {
    final phone = Validators.normalizeNumbers(_phoneController.text)
        .replaceAll(RegExp(r'[\s\-]'), '');
    return Validators.validateEgyptianPhone(phone) == null;
  }

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() => _errorMessage = null));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    final error = await requestOtpAndOpenVerification(
      context,
      _phoneController.text,
      purpose: widget.purpose,
    );
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _errorMessage = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _isPhoneValid && !_isSending;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 56,
                        height: 56,
                        semanticLabel: 'خزين',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _phoneController,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    maxLength: 11,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
                    ],
                    style: const TextStyle(fontSize: 18, letterSpacing: 1),
                    decoration: const InputDecoration(
                      labelText: 'رقم الموبايل',
                      hintText: '01012345678',
                      counterText: '',
                      prefixIcon: Icon(Icons.phone_iphone),
                    ),
                    onFieldSubmitted: (_) {
                      if (canSend) _sendCode();
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: canSend ? _sendCode : null,
                    child: _isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('التالي'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'هنبعتلك رسالة فيها كود من 6 أرقام',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  // Wraps on narrow screens instead of overflowing.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        widget.switchQuestion,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: widget.switchTo),
                        ),
                        child: Text(widget.switchAction),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
