import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CurrencyText extends StatelessWidget {
  final double amount;
  final String currency;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final Color? currencyColor;
  final bool showCurrency;
  final TextDecoration? decoration;
  final Color? decorationColor;

  const CurrencyText({
    super.key,
    required this.amount,
    this.currency = 'LKR',
    this.fontSize = 15,
    this.fontWeight = FontWeight.w800,
    this.color,
    this.currencyColor,
    this.showCurrency = true,
    this.decoration,
    this.decorationColor,
  });

  /// Formats integer part with thousands commas (e.g. 500000 -> 500,000)
  static String formatWithCommas(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? const Color(0xFF0F172A);
    final curColor = currencyColor ?? textColor.withOpacity(0.65);

    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = int.tryParse(parts[0]) ?? 0;
    final formattedInt = formatWithCommas(intPart);
    final decPart = parts.length > 1 ? parts[1] : '00';

    return RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: textColor,
          decoration: decoration,
          decorationColor: decorationColor ?? textColor,
        ),
        children: [
          if (showCurrency)
            TextSpan(
              text: '$currency ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize * 0.75,
                fontWeight: FontWeight.w600,
                color: curColor,
                letterSpacing: 0.2,
              ),
            ),
          TextSpan(
            text: formattedInt,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          TextSpan(
            text: '.$decPart',
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize * 0.82,
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}
