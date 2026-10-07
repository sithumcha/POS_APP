import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BarcodeScannerModal extends StatefulWidget {
  final List<dynamic> products;
  final Function(Map<String, dynamic> product) onProductScanned;

  const BarcodeScannerModal({
    super.key,
    required this.products,
    required this.onProductScanned,
  });

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> with SingleTickerProviderStateMixin {
  late final AnimationController _scanAnimationController;
  final TextEditingController _manualBarCodeController = TextEditingController();

  bool _flashOn = false;
  String? _lastScannedSku;

  @override
  void initState() {
    super.initState();
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _manualBarCodeController.dispose();
    super.dispose();
  }

  void _triggerBarcodeScan(String sku) {
    final query = sku.trim().toLowerCase();
    if (query.isEmpty) return;

    final matched = widget.products.firstWhere(
      (p) {
        final itemSku = (p['sku'] ?? '').toString().toLowerCase();
        final itemId = (p['id'] ?? '').toString();
        final itemName = (p['name'] ?? '').toString().toLowerCase();
        return itemSku == query || itemId == query || itemName.contains(query);
      },
      orElse: () => null,
    );

    if (matched != null) {
      setState(() {
        _lastScannedSku = matched['sku'];
      });

      widget.onProductScanned(Map<String, dynamic>.from(matched));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Scanned [${matched['sku']}] ${matched['name']} → Added to Cart!'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No item found matching barcode "$sku"'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Camera Barcode Scanner',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- 1. CAMERA VIEWFINDER OVERLAY CONTAINER ---
                  Container(
                    width: double.infinity,
                    height: 260,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155), width: 2),
                    ),
                    child: Stack(
                      children: [
                        // Simulated Camera Live Stream Feed Background
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _flashOn ? Icons.flash_on_rounded : Icons.camera_alt_outlined,
                                size: 54,
                                color: Colors.white30,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Align Barcode / QR inside frame',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Corner Viewfinder Brackets
                        _buildViewfinderCorners(),

                        // Animated Scanning Red Laser Line
                        AnimatedBuilder(
                          animation: _scanAnimationController,
                          builder: (context, child) {
                            return Positioned(
                              top: 30 + (_scanAnimationController.value * 200),
                              left: 30,
                              right: 30,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Flashlight Toggle Button Overlay
                        Positioned(
                          top: 12,
                          right: 12,
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                _flashOn = !_flashOn;
                              });
                            },
                            icon: Icon(
                              _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: _flashOn ? Colors.yellow : Colors.white60,
                              size: 24,
                            ),
                          ),
                        ),

                        // Active Scanner Status Badge
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                                SizedBox(width: 6),
                                Text(
                                  'Camera Active • Auto Fetch',
                                  style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- 2. QUICK DEMO BARCODE SCANNER BUTTONS ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tap Barcode SKU to Simulate Scan:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.products.map((p) {
                      final sku = (p['sku'] ?? 'SKU').toString();
                      final name = (p['name'] ?? 'Product').toString();
                      final isSelected = _lastScannedSku == sku;

                      return InkWell(
                        onTap: () => _triggerBarcodeScan(sku),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.barcode_reader,
                                size: 16,
                                color: isSelected ? Colors.white : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$sku ($name)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // --- 3. MANUAL BARCODE / SKU CODE ENTRY BOX ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manual Barcode / SKU Input',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualBarCodeController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter barcode number (e.g. COF-101)...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (val) => _triggerBarcodeScan(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _triggerBarcodeScan(_manualBarCodeController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Fetch', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Close Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done Scanning', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinderCorners() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Stack(
          children: [
            // Top Left
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white, width: 3),
                    left: BorderSide(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
            // Top Right
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white, width: 3),
                    right: BorderSide(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
            // Bottom Left
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: 3),
                    left: BorderSide(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
            // Bottom Right
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: 3),
                    right: BorderSide(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
