import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';

class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? productName;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const ProductImageWidget({
    super.key,
    this.imageUrl,
    this.productName,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(12);

    String? targetUrl = imageUrl;

    if (targetUrl == null || targetUrl.trim().isEmpty) {
      return _buildGradientFallbackCard(productName, br);
    }

    // Base64 image string
    if (targetUrl.startsWith('data:image/') || targetUrl.length > 300) {
      try {
        final base64Str = targetUrl.contains(',') ? targetUrl.split(',').last : targetUrl;
        final bytes = base64Decode(base64Str);
        return ClipRRect(
          borderRadius: br,
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildGradientFallbackCard(productName, br),
          ),
        );
      } catch (_) {
        return _buildGradientFallbackCard(productName, br);
      }
    }

    // Relative path from API (e.g. /files/mouse.png)
    if (targetUrl.startsWith('/')) {
      targetUrl = '${ApiConfig.baseUrl}$targetUrl';
    }

    return ClipRRect(
      borderRadius: br,
      child: Image.network(
        targetUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildGradientFallbackCard(productName, br),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientFallbackCard(String? name, BorderRadius br) {
    final lower = (name ?? '').toLowerCase();
    
    List<Color> gradientColors;
    IconData iconData;

    if (lower.contains('mouse') || lower.contains('peripheral')) {
      gradientColors = const [Color(0xFF6366F1), Color(0xFF4F46E5)];
      iconData = Icons.mouse_rounded;
    } else if (lower.contains('phone') || lower.contains('mobile') || lower.contains('smart')) {
      gradientColors = const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
      iconData = Icons.smartphone_rounded;
    } else if (lower.contains('coffee') || lower.contains('espresso') || lower.contains('latte')) {
      gradientColors = const [Color(0xFFD97706), Color(0xFF92400E)];
      iconData = Icons.coffee_rounded;
    } else if (lower.contains('tea')) {
      gradientColors = const [Color(0xFF059669), Color(0xFF047857)];
      iconData = Icons.emoji_food_beverage_rounded;
    } else if (lower.contains('croissant') || lower.contains('bakery') || lower.contains('bread')) {
      gradientColors = const [Color(0xFFF59E0B), Color(0xFFB45309)];
      iconData = Icons.bakery_dining_rounded;
    } else if (lower.contains('keyboard')) {
      gradientColors = const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
      iconData = Icons.keyboard_rounded;
    } else if (lower.contains('headphone') || lower.contains('audio')) {
      gradientColors = const [Color(0xFFEC4899), Color(0xFFBE185D)];
      iconData = Icons.headphones_rounded;
    } else {
      gradientColors = const [Color(0xFF475569), Color(0xFF1E293B)];
      iconData = Icons.inventory_2_rounded;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background subtle pattern circle
          Positioned(
            right: -10,
            bottom: -10,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 36, color: Colors.white),
              if (name != null && name.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
