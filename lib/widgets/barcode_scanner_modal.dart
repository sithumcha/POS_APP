import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 1600),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added [${matched['sku'] ?? 'SKU'}] ${matched['name']} to cart!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('No item found matching barcode "$sku"')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF0F172A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Barcode & QR Scanner',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Scan or search item SKU',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.close_rounded, color: Color(0xFF475569), size: 18),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 16, color: Color(0xFFF1F5F9), thickness: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. CAMERA VIEWFINDER OVERLAY CONTAINER ---
                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF1E293B),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Viewfinder Center Target
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                                ),
                                child: Icon(
                                  _flashOn ? Icons.flash_on_rounded : Icons.qr_code_2_rounded,
                                  size: 44,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: const Text(
                                  'Align Barcode or QR within frame',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Corner Viewfinder Brackets
                        _buildViewfinderCorners(),

                        // Animated Scanning Laser Line
                        AnimatedBuilder(
                          animation: _scanAnimationController,
                          builder: (context, child) {
                            return Positioned(
                              top: 25 + (_scanAnimationController.value * 190),
                              left: 28,
                              right: 28,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0x0006B6D4),
                                      Color(0xFF06B6D4),
                                      Color(0xFF38BDF8),
                                      Color(0xFF06B6D4),
                                      Color(0x0006B6D4),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF06B6D4).withOpacity(0.8),
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
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _flashOn = !_flashOn),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Icon(
                                  _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                  color: _flashOn ? const Color(0xFFFBBF24) : Colors.white70,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Active Scanner Status Badge
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                                SizedBox(width: 6),
                                Text(
                                  'Ready to Scan • Auto-detect',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // --- 2. MANUAL BARCODE / SKU CODE ENTRY BOX ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.keyboard_alt_outlined, color: Color(0xFF475569), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Manual Barcode / SKU Input',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualBarCodeController,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter SKU (e.g. COF-101)...',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                  ),
                                ),
                                onSubmitted: (val) => _triggerBarcodeScan(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _triggerBarcodeScan(_manualBarCodeController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Fetch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- 3. QUICK DEMO BARCODE CHIPS ---
                  if (widget.products.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quick Barcode Demo Simulation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.products.length} Items',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.products.map((p) {
                        final sku = (p['sku'] ?? 'SKU').toString();
                        final name = (p['name'] ?? 'Product').toString();
                        final isSelected = _lastScannedSku == sku;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _triggerBarcodeScan(sku),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isSelected ? 0.08 : 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.barcode_reader,
                                    size: 16,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sku,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '• $name',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Close Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Done Scanning',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildViewfinderCorners() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Stack(
          children: [
            // Top Left
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                    left: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
                ),
              ),
            ),
            // Top Right
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                    right: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
                ),
              ),
            ),
            // Bottom Left
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                    left: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                ),
              ),
            ),
            // Bottom Right
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                    right: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
                  ),
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
