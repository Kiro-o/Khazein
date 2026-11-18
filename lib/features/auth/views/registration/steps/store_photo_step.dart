import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../view_models/onboarding_view_model.dart';
import 'step_widgets.dart';

/// Returns JPEG bytes from [source], or null when the merchant cancels.
typedef StorePhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Picks and shrinks a photo (max 1280 px, JPEG 70%) so uploads stay small
/// on slow mobile data.
Future<Uint8List?> pickStorePhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,
  );
  return file?.readAsBytes();
}

/// Steps 5 and 6: an optional photo of the storefront or the inside of the
/// store, taken with the camera or chosen from the gallery.
///
/// The inside photo is the last step, so it submits the registration.
class StorePhotoStep extends StatefulWidget {
  final OnboardingViewModel viewModel;
  final bool interior;
  final StorePhotoPicker pickPhoto;

  const StorePhotoStep({
    super.key,
    required this.viewModel,
    required this.interior,
    this.pickPhoto = pickStorePhoto,
  });

  @override
  State<StorePhotoStep> createState() => _StorePhotoStepState();
}

class _StorePhotoStepState extends State<StorePhotoStep> {
  OnboardingViewModel get _vm => widget.viewModel;

  Uint8List? get _photo =>
      widget.interior ? _vm.interiorPhoto : _vm.exteriorPhoto;

  void _setPhoto(Uint8List? bytes) => widget.interior
      ? _vm.setInteriorPhoto(bytes)
      : _vm.setExteriorPhoto(bytes);

  Future<void> _pick(ImageSource source) async {
    try {
      final bytes = await widget.pickPhoto(source);
      if (bytes != null) _setPhoto(bytes);
    } catch (e) {
      debugPrint('Picking a store photo failed: $e');
      _vm.showStepError(
        source == ImageSource.camera
            ? 'مقدرناش نفتح الكاميرا. اسمح بالكاميرا أو اختار صورة من الاستوديو.'
            : 'مقدرناش نفتح الصور. حاول تاني.',
      );
    }
  }

  /// [dropAllPhotos] registers without any photo after an upload failed
  /// (e.g. Storage is unavailable), so the merchant isn't stuck.
  Future<void> _continue({
    required bool withPhoto,
    bool dropAllPhotos = false,
  }) async {
    if (!withPhoto) _setPhoto(null);
    if (widget.interior) {
      await _vm.completeRegistration(withPhotos: !dropAllPhotos);
    } else {
      _vm.nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final photo = _photo;
        final submitting = _vm.isSubmitting;
        final uploadFailed =
            widget.interior && _vm.stepError != null && !submitting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepHeader(
              title: widget.interior
                  ? 'صورة من جوّه المحل'
                  : 'صورة واجهة المحل',
              subtitle: widget.interior
                  ? 'صورة للرفوف أو الكاشير بتساعدنا نتأكد من المحل (اختياري)'
                  : 'صورة للواجهة واليافطة بتساعد المندوب يلاقيك (اختياري)',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photo == null
                    ? Container(
                        color: AppColors.slateGray,
                        alignment: Alignment.center,
                        child: Icon(
                          widget.interior
                              ? Icons.shelves
                              : Icons.storefront_outlined,
                          size: 72,
                          color: AppColors.textMuted,
                        ),
                      )
                    : Image.memory(
                        photo,
                        key: const ValueKey('store_photo_preview'),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        cacheWidth: 800,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('take_photo'),
                    onPressed: submitting
                        ? null
                        : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(photo == null ? 'صوّر' : 'صوّر تاني'),
                    style: _photoButtonStyle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('pick_photo'),
                    onPressed: submitting
                        ? null
                        : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('من الاستوديو'),
                    style: _photoButtonStyle,
                  ),
                ),
              ],
            ),
            StepError(viewModel: _vm),
            const SizedBox(height: 12),
            StepPrimaryButton(
              label: widget.interior ? 'إنشاء الحساب' : 'التالي',
              loading: submitting,
              onPressed: photo == null && !widget.interior
                  ? null
                  : () => _continue(withPhoto: true),
            ),
            TextButton(
              key: const ValueKey('skip_photo'),
              onPressed: submitting
                  ? null
                  : () => _continue(
                      withPhoto: false,
                      dropAllPhotos: uploadFailed,
                    ),
              child: Text(
                uploadFailed
                    ? 'كمّل من غير صور'
                    : (widget.interior ? 'تخطّي وإنشاء الحساب' : 'تخطّي'),
              ),
            ),
          ],
        );
      },
    );
  }

  static final ButtonStyle _photoButtonStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
