import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../view_models/onboarding_view_model.dart';
import 'step_widgets.dart';

/// Step 3: the store location. The merchant moves the map under a fixed pin
/// (like delivery apps) or jumps to the phone's GPS location.
///
/// Map tiles come from OpenStreetMap (no API key); [tileUrl] can point to
/// another provider for production traffic.
class Step3MapPinStep extends StatefulWidget {
  final OnboardingViewModel viewModel;

  /// Tile URL template. Tests pass an empty string to skip network tiles.
  final String tileUrl;

  const Step3MapPinStep({
    super.key,
    required this.viewModel,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  });

  @override
  State<Step3MapPinStep> createState() => _Step3MapPinStepState();
}

class _Step3MapPinStepState extends State<Step3MapPinStep> {
  final MapController _mapController = MapController();
  late LatLng _center;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _center = LatLng(widget.viewModel.latitude, widget.viewModel.longitude);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        widget.viewModel.showStepError(
          'افتح الـ GPS (الموقع) في الموبايل وحاول تاني',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        widget.viewModel.showStepError(
          'محتاجين إذن الموقع. تقدر تحرّك الخريطة بإيدك لحد مكان المحل.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final here = LatLng(position.latitude, position.longitude);
      _mapController.move(here, 17);
      setState(() => _center = here);
    } catch (e) {
      debugPrint('Getting the location failed: $e');
      widget.viewModel.showStepError(
        'مقدرناش نحدد موقعك. حرّك الخريطة بإيدك لحد مكان المحل.',
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onNext() {
    widget.viewModel.setMapCoordinates(_center.latitude, _center.longitude);
    widget.viewModel.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepHeader(
          title: 'مكان المحل على الخريطة',
          subtitle: 'حرّك الخريطة لحد ما الدبوس يبقى على باب المحل',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.drag |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom,
                    ),
                    onPositionChanged: (camera, _) => _center = camera.center,
                  ),
                  children: [
                    if (widget.tileUrl.isNotEmpty)
                      TileLayer(
                        urlTemplate: widget.tileUrl,
                        userAgentPackageName: 'com.khazeen.app',
                      ),
                    // Required by the OpenStreetMap tile usage policy.
                    Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: Colors.white70,
                        child: const Text(
                          '© OpenStreetMap',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
                // The pin's tip marks the map center.
                const IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('use_my_location'),
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('استخدم موقعي الحالي'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        StepError(viewModel: widget.viewModel),
        const SizedBox(height: 12),
        StepPrimaryButton(label: 'تأكيد المكان', onPressed: _onNext),
      ],
    );
  }
}
