import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khazeen_app/core/theme/app_colors.dart';
import 'package:khazeen_app/data/repositories/auth_repository.dart';

import '../../../home/views/merchant_home_screen.dart';
import '../registration/merchant_registration_screen.dart';

/// Why the merchant is verifying their number.
enum OtpPurpose {
  /// From the login screen: an unregistered number is reported, not
  /// silently sent to registration.
  login,

  /// From the sign-up screen: a new number continues to registration.
  signUp,
}

/// SMS OTP verification (التحقق من رقم الهاتف).
///
/// Verifies the 6-digit Firebase code for [verification]. A registered
/// merchant always goes to the home screen. A number without a profile goes
/// to the registration wizard on [OtpPurpose.signUp]; on [OtpPurpose.login]
/// the merchant is told the number is not registered and chooses between
/// creating an account (no second SMS needed) or trying another number.
class OtpVerificationScreen extends StatefulWidget {
  final PhoneVerification verification;
  final OtpPurpose purpose;

  const OtpVerificationScreen({
    super.key,
    required this.verification,
    this.purpose = OtpPurpose.signUp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  late PhoneVerification _verification;
  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  String? _errorMessage;
  bool _isVerifying = false;
  bool _isResending = false;

  /// Set once Firebase sign-in succeeded; a retry then only reloads the profile.
  bool _signedIn = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _codeFocusNode.addListener(() => setState(() {}));
    _useVerification(widget.verification);
    _startCountdown();
  }

  void _useVerification(PhoneVerification verification) {
    _verification = verification;
    if (verification.autoVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onSignedIn());
    }
    verification.autoSignedIn.then((_) {
      if (mounted) _onSignedIn();
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    setState(() => _errorMessage = null);
    if (value.length == _codeLength) {
      _codeFocusNode.unfocus();
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_isVerifying) return;
    if (_signedIn) {
      await _onSignedIn();
      return;
    }

    final code = _codeController.text.trim();
    if (code.length < _codeLength) {
      setState(
        () => _errorMessage =
            'يرجى إدخال رمز التحقق المكون من $_codeLength أرقام بالكامل',
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await AuthRepository.instance.verifyOtp(_verification, code);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e.message;
      });
      return;
    }
    await _onSignedIn();
  }

  /// Loads the merchant profile and leaves the auth flow.
  Future<void> _onSignedIn() async {
    if (_navigated) return;
    _signedIn = true;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final merchant = await AuthRepository.instance.loadCurrentMerchant();
      if (!mounted || _navigated) return;

      if (merchant == null && widget.purpose == OtpPurpose.login) {
        setState(() => _isVerifying = false);
        await _showNotRegisteredDialog();
        return;
      }

      _leaveAuthFlow(
        merchant != null
            ? MerchantHomeScreen(merchant: merchant)
            : const MerchantRegistrationScreen(),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = e.message;
        // A non-merchant account was signed out: a new code is needed.
        if (AuthRepository.instance.currentUser == null) _signedIn = false;
      });
    }
  }

  void _leaveAuthFlow(Widget destination) {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  /// Login with a number that has no `users/{uid}` profile yet.
  Future<void> _showNotRegisteredDialog() async {
    final createAccount = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'الرقم ده مش مسجّل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'مفيش حساب تاجر على خزين بالرقم ${_verification.phone}.\n'
            'تقدر تنشئ حساب جديد بنفس الرقم دلوقتي، أو ترجع وتكتب رقم تاني.',
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('رقم تاني'),
            ),
            ElevatedButton(
              key: const ValueKey('create_account_button'),
              // The theme's full-width minimumSize breaks dialog actions.
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('إنشاء حساب جديد'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (createAccount == true) {
      // The number is already verified, so registration needs no new SMS.
      _leaveAuthFlow(const MerchantRegistrationScreen());
      return;
    }

    await AuthRepository.instance.signOut();
    if (!mounted) return;
    _signedIn = false;
    Navigator.of(context).pop();
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final verification = await AuthRepository.instance.sendOtp(
        _verification.phone,
        resendFrom: _verification,
      );
      if (!mounted) return;
      _codeController.clear();
      _useVerification(verification);
      _startCountdown();
      _codeFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال رمز تأكيد جديد إلى الرقم ${_verification.phone} 📩',
          ),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = '00:${_secondsLeft.toString().padLeft(2, '0')}';

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
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'التحقق من رقم الهاتف',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Stylized SMS Icon badge
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Screen Header
                const Text(
                  'التحقق من رقم الهاتف 📱',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle with formatted phone
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'تم إرسال رمز تأكيد مكون من $_codeLength أرقام إلى الرقم ${_verification.phone}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Error banner if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildCodeBoxes(),
                const SizedBox(height: 24),

                // Resend Timer Row
                Center(
                  child: _secondsLeft > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'إعادة إرسال الكود بعد $formattedTime',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : TextButton.icon(
                          onPressed: _isResending || _isVerifying
                              ? null
                              : _resendCode,
                          icon: _isResending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'إعادة إرسال الكود',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),

                const Spacer(),

                // Verify and Proceed Button
                ElevatedButton(
                  onPressed: _isVerifying ? null : _submit,
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
                  child: _isVerifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'تأكيد الكود والمتابعة',
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Six digit boxes drawn over one invisible text field, so paste and
  /// SMS autofill (oneTimeCode) fill the whole code at once.
  Widget _buildCodeBoxes() {
    final code = _codeController.text;
    final focused = _codeFocusNode.hasFocus;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Row(
                children: List.generate(_codeLength, (index) {
                  final isActive =
                      focused &&
                      (index == code.length ||
                          (index == _codeLength - 1 &&
                              code.length == _codeLength));
                  final isFilled = index < code.length;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AspectRatio(
                        aspectRatio: 0.85,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : (isFilled
                                        ? AppColors.primaryDark
                                        : AppColors.border),
                              width: isActive ? 2 : 1.5,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isFilled ? code[index] : '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    key: const ValueKey('otp_code_field'),
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    autofocus: true,
                    enabled: !_isVerifying,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: _codeLength,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    onChanged: _onCodeChanged,
                    onTap: () => setState(() {}),
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
