import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SwipeToConfirmButton extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;
  final Color backgroundColor;
  final Color thumbColor;
  final Color textColor;
  final double height;
  final bool isEnabled;

  const SwipeToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.backgroundColor = const Color(0xFF0F172A),
    this.thumbColor = Colors.white,
    this.textColor = Colors.white,
    this.height = 56,
    this.isEnabled = true,
  });

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton> {
  double _dragPosition = 0.0;
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - widget.height;

        return Opacity(
          opacity: widget.isEnabled ? 1.0 : 0.45,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
              boxShadow: [
                BoxShadow(
                  color: widget.backgroundColor.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Center text label
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: widget.height),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: widget.textColor.withOpacity(0.92),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: widget.textColor.withOpacity(0.6),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                // Active slide progress fill
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _dragPosition + widget.height,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),

                // Draggable circular thumb
                Positioned(
                  left: _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: widget.isEnabled && !_isConfirmed
                        ? (details) {
                            setState(() {
                              _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                            });
                          }
                        : null,
                    onHorizontalDragEnd: widget.isEnabled && !_isConfirmed
                        ? (details) {
                            if (_dragPosition >= maxDrag * 0.8) {
                              // Trigger confirmation
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _dragPosition = maxDrag;
                                _isConfirmed = true;
                              });
                              widget.onConfirmed();
                            } else {
                              // Snap back
                              setState(() {
                                _dragPosition = 0.0;
                              });
                            }
                          }
                        : null,
                    child: Container(
                      width: widget.height,
                      height: widget.height,
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConfirmed ? const Color(0xFF10B981) : widget.thumbColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isConfirmed ? Icons.check_rounded : Icons.arrow_forward_rounded,
                          color: _isConfirmed ? Colors.white : const Color(0xFF0F172A),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
