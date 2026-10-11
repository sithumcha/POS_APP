import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Interactive card with smooth scale up and shadow lift on mouse hover & tap
class HoverScaleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? normalShadow;
  final List<BoxShadow>? hoverShadow;
  final EdgeInsetsGeometry? padding;

  const HoverScaleCard({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 1.025,
    this.duration = const Duration(milliseconds: 220),
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.normalShadow,
    this.hoverShadow,
    this.padding,
  });

  @override
  State<HoverScaleCard> createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double targetScale = _isPressed
        ? 0.98
        : (_isHovered ? widget.scaleFactor : 1.0);

    final defaultNormalShadow = widget.normalShadow ?? AppColors.softShadow;
    final defaultHoverShadow = widget.hoverShadow ?? AppColors.cardHoverShadow;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: targetScale,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: widget.duration,
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Colors.white,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
              border: widget.border ?? Border.all(
                color: _isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                width: _isHovered ? 1.4 : 1.0,
              ),
              boxShadow: _isHovered ? defaultHoverShadow : defaultNormalShadow,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Staggered Fade & Slide entrance animation
class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;
  final Curve curve;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.delay = Duration.zero,
    this.offset = const Offset(0.0, 0.08),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slideAnimation = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Interactive button with micro-spring tap feedback
class AnimatedTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;
  final double scaleDown;

  const AnimatedTapButton({
    super.key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 140),
    this.scaleDown = 0.96,
  });

  @override
  State<AnimatedTapButton> createState() => _AnimatedTapButtonState();
}

class _AnimatedTapButtonState extends State<AnimatedTapButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Pulsing indicator dot for live statuses, sync states, & badges
class PulsingStatusDot extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const PulsingStatusDot({
    super.key,
    this.color = const Color(0xFF10B981),
    this.size = 8.0,
    this.duration = const Duration(milliseconds: 1600),
  });

  @override
  State<PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted Glass container with subtle gradient border & backdrop blur
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.borderRadius,
    this.backgroundColor,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withOpacity(0.85),
            borderRadius: r,
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Creative Page Route Transition with Depth Scale, Parallax Slide, and Smooth Fade
class CreativePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration transitionDurationCustom;

  CreativePageRoute({
    required this.page,
    this.transitionDurationCustom = const Duration(milliseconds: 320),
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: transitionDurationCustom,
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Forward animation for incoming page: Slide + Scale from 0.94 + Fade
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            final slideIn = Tween<Offset>(
              begin: const Offset(0.04, 0.04),
              end: Offset.zero,
            ).animate(curvedAnimation);

            final scaleIn = Tween<double>(
              begin: 0.94,
              end: 1.0,
            ).animate(curvedAnimation);

            final fadeIn = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(curvedAnimation);

            // Secondary animation when another page is pushed above
            final secondaryCurved = CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
            );
            final scaleOut = Tween<double>(begin: 1.0, end: 0.96).animate(secondaryCurved);
            final fadeOut = Tween<double>(begin: 1.0, end: 0.7).animate(secondaryCurved);

            return SlideTransition(
              position: slideIn,
              child: FadeTransition(
                opacity: fadeIn,
                child: ScaleTransition(
                  scale: scaleIn,
                  child: FadeTransition(
                    opacity: fadeOut,
                    child: ScaleTransition(
                      scale: scaleOut,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        );
}

/// Helper class providing creative route animations and haptic feedback
class AppNavigator {
  /// Push page with depth scale & fade animation
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(context, CreativePageRoute<T>(page: page));
  }

  /// Replace page with creative route animation
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
    return Navigator.pushReplacement<T, TO>(context, CreativePageRoute<T>(page: page));
  }

  /// Remove all previous routes and push new page with creative transition
  static Future<T?> pushAndRemoveUntil<T>(BuildContext context, Widget page) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      CreativePageRoute<T>(page: page),
      (route) => false,
    );
  }
}

