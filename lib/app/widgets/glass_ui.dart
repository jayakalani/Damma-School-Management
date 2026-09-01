import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft floating shadow used under cards and buttons.
List<BoxShadow> floatingShadow({
  Color? color,
  double blur = 20,
  double y = 10,
  double opacity = 0.12,
  bool elevated = false,
}) {
  return [
    BoxShadow(
      color: (color ?? Colors.black).withValues(alpha: elevated ? opacity * 1.6 : opacity),
      blurRadius: elevated ? blur * 1.4 : blur,
      offset: Offset(0, elevated ? y * 1.3 : y),
      spreadRadius: elevated ? 1 : 0,
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.65),
      blurRadius: 1,
      offset: const Offset(0, -1),
    ),
  ];
}

/// Subtle gradient backdrop for dashboard screens.
class DashboardBackdrop extends StatelessWidget {
  const DashboardBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(primary.withValues(alpha: 0.06), const Color(0xFFF4F8FA)),
            const Color(0xFFEEF4F7),
            Color.alphaBlend(primary.withValues(alpha: 0.08), const Color(0xFFE8F0F4)),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _orb(primary.withValues(alpha: 0.14), const Offset(-80, -60), 240),
          _orb(const Color(0xFF6366F1).withValues(alpha: 0.08), const Offset(720, 80), 280),
          _orb(primary.withValues(alpha: 0.1), const Offset(180, 480), 220),
          child,
        ],
      ),
    );
  }

  Widget _orb(Color color, Offset offset, double size) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Frosted-glass panel with blur and border.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding,
    this.margin,
    this.blur = 16,
    this.opacity = 0.72,
    this.borderOpacity = 0.55,
    this.tint,
    this.shadow = true,
    this.elevated = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final Color? tint;
  final bool shadow;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final fill = tint ?? Colors.white;
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? floatingShadow(color: primary, elevated: elevated)
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fill.withValues(alpha: opacity),
                  fill.withValues(alpha: opacity - 0.08),
                ],
              ),
              border: Border.all(
                color: fill.withValues(alpha: borderOpacity),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glass card with hover scale + glow for tappable dashboard tiles.
class GlassInteractiveCard extends StatefulWidget {
  const GlassInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.all(14),
    this.accentColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;

  @override
  State<GlassInteractiveCard> createState() => _GlassInteractiveCardState();
}

class _GlassInteractiveCardState extends State<GlassInteractiveCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            splashColor: accent.withValues(alpha: 0.08),
            highlightColor: accent.withValues(alpha: 0.04),
            child: GlassSurface(
              borderRadius: widget.borderRadius,
              padding: widget.padding,
              opacity: _hovered ? 0.82 : 0.72,
              borderOpacity: _hovered ? 0.75 : 0.55,
              tint: _hovered ? Color.alphaBlend(accent.withValues(alpha: 0.06), Colors.white) : Colors.white,
              elevated: _hovered,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact colored stat card for dashboard metric rows (not quick actions).
class GlassMetricCard extends StatefulWidget {
  const GlassMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  State<GlassMetricCard> createState() => _GlassMetricCardState();
}

class _GlassMetricCardState extends State<GlassMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: floatingShadow(
              opacity: _hovered ? 0.1 : 0.06,
              blur: _hovered ? 18 : 14,
              y: _hovered ? 8 : 5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Icon(widget.icon, color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.value,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                            Text(
                              widget.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact glass quick-action tile for dashboard grids.
class GlassQuickActionCard extends StatelessWidget {
  const GlassQuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassInteractiveCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primaryContainer.withValues(alpha: 0.65),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_outward_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Sidebar / nav tile with glass hover.
class GlassNavTile extends StatefulWidget {
  const GlassNavTile({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<GlassNavTile> createState() => _GlassNavTileState();
}

class _GlassNavTileState extends State<GlassNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = widget.isSelected || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered && !widget.isSelected ? 1.01 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: widget.isSelected
                    ? colorScheme.primary.withValues(alpha: 0.14)
                    : _hovered
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.transparent,
                border: Border.all(
                  color: widget.isSelected
                      ? colorScheme.primary.withValues(alpha: 0.35)
                      : _hovered
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.transparent,
                ),
                boxShadow: widget.isSelected || _hovered
                    ? floatingShadow(color: colorScheme.primary, blur: 14, y: 6, opacity: 0.08, elevated: _hovered)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: active ? colorScheme.primary : colorScheme.onSurface,
                            fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass-styled logout button with hover glow.
class GlassLogoutButton extends StatefulWidget {
  const GlassLogoutButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<GlassLogoutButton> createState() => _GlassLogoutButtonState();
}

class _GlassLogoutButtonState extends State<GlassLogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _hovered
                    ? Colors.redAccent.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.45),
                border: Border.all(
                  color: _hovered
                      ? Colors.redAccent.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.7),
                ),
                boxShadow: _hovered
                    ? floatingShadow(color: Colors.redAccent, blur: 16, y: 8, opacity: 0.12, elevated: true)
                    : floatingShadow(blur: 12, y: 6, opacity: 0.06),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: _hovered ? Colors.redAccent.shade700 : Colors.redAccent.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sign out',
                    style: TextStyle(
                      color: _hovered ? Colors.redAccent.shade700 : Colors.redAccent.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Offline status chip with glass styling.
class GlassStatusChip extends StatefulWidget {
  const GlassStatusChip({super.key});

  @override
  State<GlassStatusChip> createState() => _GlassStatusChipState();
}

class _GlassStatusChipState extends State<GlassStatusChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(999),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          opacity: _hovered ? 0.8 : 0.68,
          blur: 12,
          elevated: _hovered,
          tint: Color.alphaBlend(Colors.amber.withValues(alpha: 0.12), Colors.white),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text(
                'Offline',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
