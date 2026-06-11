import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

class DocumentCaptureScreen extends StatefulWidget {
  static const uploadFallbackResult = '__upload_fallback__';

  final String documentTypeId;

  const DocumentCaptureScreen({super.key, required this.documentTypeId});

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen> {
  CameraController? _controller;
  XFile? _capturedFile;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  bool _flashEnabled = false;
  bool _canToggleFlash = true;
  String? _errorMessage;

  bool get _isFrontSide => widget.documentTypeId == 'id_front';

  String get _title => _isFrontSide ? 'Cédula (frente)' : 'Cédula (reverso)';

  String get _hintText => _isFrontSide
      ? 'Alinea el frente de tu cédula dentro del marco y procura buena luz.'
      : 'Alinea el reverso de tu cédula dentro del marco y evita reflejos.';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No se encontró una cámara disponible.';
        });
        return;
      }

      final preferredCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        preferredCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isCameraReady = true;
      });
    } on CameraException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = switch (error.code) {
          'CameraAccessDenied' ||
          'CameraAccessDeniedWithoutPrompt' ||
          'CameraAccessRestricted' =>
            'Necesitas permitir el acceso a la cámara para tomar esta foto.',
          _ =>
            'No se pudo iniciar la cámara: ${error.description ?? error.code}',
        };
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo iniciar la cámara: $error';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !_canToggleFlash) return;

    try {
      final nextFlashEnabled = !_flashEnabled;
      await controller.setFlashMode(
        nextFlashEnabled ? FlashMode.torch : FlashMode.off,
      );
      if (mounted) {
        setState(() {
          _flashEnabled = nextFlashEnabled;
        });
      }
    } on CameraException {
      if (mounted) {
        setState(() {
          _canToggleFlash = false;
          _flashEnabled = false;
        });
      }
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final picture = await controller.takePicture();
      if (!mounted) return;

      setState(() {
        _capturedFile = picture;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo tomar la foto: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _useCapturedPhoto() {
    final capturedFile = _capturedFile;
    if (capturedFile == null) return;
    Navigator.of(context).pop(capturedFile.path);
  }

  void _retryCapture() {
    setState(() {
      _capturedFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedFile != null) {
      return _buildConfirmationView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (!_isCameraReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CameraPreview(_controller!)),
            const Positioned.fill(child: _DocumentFrameOverlay()),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _hintText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_canToggleFlash) ...[
                    const SizedBox(width: 12),
                    _CircleButton(
                      icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
                      onTap: _toggleFlash,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Revisa que toda la cédula quede dentro del marco antes de capturar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.file(File(_capturedFile!.path), fit: BoxFit.cover),
            ),
            const Positioned.fill(child: _DocumentFrameOverlay()),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Confirma que la foto esté nítida y que el documento se vea completo.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retryCapture,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Repetir'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _useCapturedPhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Usar foto'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Capturar documento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFFFF9800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Puedes volver a intentarlo más tarde o seguir con el flujo de archivo manual.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(DocumentCaptureScreen.uploadFallbackResult),
                child: const Text('Subir archivo en su lugar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentFrameOverlay extends StatelessWidget {
  const _DocumentFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameWidth = constraints.maxWidth * 0.84;
          final frameHeight = frameWidth / 1.58;
          final sideWidth = (constraints.maxWidth - frameWidth) / 2;
          final topHeight = (constraints.maxHeight - frameHeight) / 2;
          const overlayColor = Color.fromRGBO(0, 0, 0, 0.55);

          return Column(
            children: [
              Container(height: topHeight, color: overlayColor),
              Row(
                children: [
                  Container(
                    width: sideWidth,
                    height: frameHeight,
                    color: overlayColor,
                  ),
                  Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                  Expanded(
                    child: Container(height: frameHeight, color: overlayColor),
                  ),
                ],
              ),
              Expanded(child: Container(color: overlayColor)),
            ],
          );
        },
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
