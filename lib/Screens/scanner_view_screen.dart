import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mylocker/Screens/guard_dashboard_screen.dart';
import 'package:vibration/vibration.dart';

class ScannerViewScreen extends StatefulWidget {
  const ScannerViewScreen({super.key});

  @override
  State<ScannerViewScreen> createState() => _ScannerViewScreenState();
}

class _ScannerViewScreenState extends State<ScannerViewScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    // Camera is fully released when this screen leaves the stack
    _scannerController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Detection handler
  // ─────────────────────────────────────────────
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final String? scannedCode = capture.barcodes.firstOrNull?.rawValue;
    if (scannedCode == null || scannedCode.isEmpty) return;

    // ── Pre-validation ────────────────────────────
    final RegExp enrollmentRegex = RegExp(r'^[A-Z0-9]{5,20}$');

    if (!enrollmentRegex.hasMatch(scannedCode)) {
      Vibration.vibrate(duration: 200, amplitude: 255);

      setState(() => _isProcessing = true);
      await _scannerController.stop();
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Invalid QR Format'),
          content: const Text(
            'This QR code does not match a valid enrollment number.\n\n'
                'Ask the student to open MyLocker and show the correct QR code.',
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _scannerController.start();
                if (mounted) setState(() => _isProcessing = false);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Close & Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // ── Valid format — lock, stop, then query ─────
    setState(() => _isProcessing = true);
    await _scannerController.stop();
    if (!mounted) return;

    await GuardDashboardScreen.runScanFlow(
      context: context,
      scannedCode: scannedCode,

      // ── NEW: fires as soon as Firestore responds ──
      // Clears the spinner before the dialog mounts so
      // the camera background is clean behind the dialog.
      onLookupComplete: () {
        if (mounted) setState(() => _isProcessing = false);
      },

      onScanNext: () async {
        Navigator.pop(context);
        await _scannerController.start();
        if (mounted) setState(() => _isProcessing = false);
      },
      onClose: () {
        Navigator.pop(context);
        Navigator.pop(context);
      },
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.45),
        foregroundColor: Colors.white,
        elevation: 0,
        // Back arrow automatically shown by Flutter since this
        // screen was push()'d. Tapping it pops the screen and
        // dispose() releases the camera cleanly.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Back to Dashboard',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // ── Layer 1: Full-screen camera ───────────
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // ── Layer 2: Dimmed overlay with cutout ───
          _ScannerOverlay(),

          // ── Layer 3: Bottom controls ──────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.78),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Torch toggle
                  ValueListenableBuilder(
                    valueListenable: _scannerController,
                    builder: (context, value, child) {
                      final isOn = value.torchState == TorchState.on;
                      return IconButton(
                        icon: Icon(
                          isOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: isOn ? Colors.amber : Colors.white,
                          size: 32,
                        ),
                        onPressed: () => _scannerController.toggleTorch(),
                        tooltip: 'Toggle Flashlight',
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Point camera at student\'s QR code',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Live processing indicator
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isProcessing
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      key: const ValueKey('processing'),
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Verifying...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                        : const SizedBox.shrink(key: ValueKey('idle')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Scanner Overlay (same CustomPainter as before)
// ═══════════════════════════════════════════════
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const cutoutSize = 260.0;

    return CustomPaint(
      size: Size(size.width, size.height),
      painter: _OverlayPainter(
        cutoutRect: Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2 - 40),
          width: cutoutSize,
          height: cutoutSize,
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect cutoutRect;
  const _OverlayPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.62);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final cornerPaint = Paint()
      ..color = const Color(0xFF1A73E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Dim mask with cutout hole via evenOdd fill rule
    final dimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
          RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dimPath, dimPaint);

    // White border
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)),
      borderPaint,
    );

    // Blue corner brackets
    const cl = 28.0;
    final l = cutoutRect.left;
    final t = cutoutRect.top;
    final r = cutoutRect.right;
    final b = cutoutRect.bottom;

    canvas.drawLine(Offset(l, t + cl), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + cl, t), cornerPaint);
    canvas.drawLine(Offset(r - cl, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cl), cornerPaint);
    canvas.drawLine(Offset(l, b - cl), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + cl, b), cornerPaint);
    canvas.drawLine(Offset(r - cl, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b), Offset(r, b - cl), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}