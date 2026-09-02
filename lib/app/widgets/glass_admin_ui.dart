import 'package:flutter/material.dart';

import 'glass_ui.dart';

class GlassPageHeader extends StatelessWidget {
  const GlassPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        opacity: 0.78,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
}

class GlassToolbarButton extends StatefulWidget {
  const GlassToolbarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  State<GlassToolbarButton> createState() => _GlassToolbarButtonState();
}

class _GlassToolbarButtonState extends State<GlassToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.08), widget.accent)
        : widget.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _hovered
                    ? floatingShadow(
                        color: widget.accent,
                        opacity: 0.2,
                        blur: 14,
                        y: 6,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
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

class GlassSummaryStatCard extends StatefulWidget {
  const GlassSummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.accentColor,
    this.dense = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color accentColor;
  final bool dense;

  @override
  State<GlassSummaryStatCard> createState() => _GlassSummaryStatCardState();
}

class _GlassSummaryStatCardState extends State<GlassSummaryStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(14),
            padding: EdgeInsets.zero,
            opacity: _hovered ? 0.84 : 0.74,
            borderOpacity: _hovered ? 0.72 : 0.55,
            tint: _hovered
                ? Color.alphaBlend(
                    widget.accentColor.withValues(alpha: 0.05),
                    Colors.white,
                  )
                : Colors.white,
            elevated: _hovered,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: widget.dense ? 2 : 3,
                  color: widget.accentColor,
                ),
                Padding(
                  padding: widget.dense
                      ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
                      : const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              fontSize: widget.dense ? 11 : null,
                            ),
                      ),
                      SizedBox(height: widget.dense ? 4 : 6),
                      Text(
                        widget.value,
                        style: (widget.dense
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.headlineMedium)
                            ?.copyWith(
                          color: widget.valueColor,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(20),
      opacity: 0.76,
      child: child,
    );
  }
}

class GlassActionButton extends StatefulWidget {
  const GlassActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  State<GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<GlassActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1,
        duration: const Duration(milliseconds: 180),
        child: widget.filled
            ? FilledButton(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _hovered ? 3 : 0,
                ),
                child: Text(widget.label),
              )
            : OutlinedButton(
                onPressed: widget.onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(
                    color: accent.withValues(alpha: _hovered ? 0.6 : 0.35),
                  ),
                  backgroundColor: _hovered
                      ? accent.withValues(alpha: 0.06)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(widget.label),
              ),
      ),
    );
  }
}

class GlassActionChipButton extends StatefulWidget {
  const GlassActionChipButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<GlassActionChipButton> createState() => _GlassActionChipButtonState();
}

class _GlassActionChipButtonState extends State<GlassActionChipButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.05 : 1,
        duration: const Duration(milliseconds: 160),
        child: OutlinedButton(
          onPressed: widget.onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.color,
            side: BorderSide(
              color: widget.color.withValues(alpha: _hovered ? 0.55 : 0.35),
            ),
            backgroundColor: widget.color.withValues(
              alpha: _hovered ? 0.14 : 0.06,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
          ),
        ),
      ),
    );
  }
}

class GlassListRow extends StatefulWidget {
  const GlassListRow({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<GlassListRow> createState() => _GlassListRowState();
}

class _GlassListRowState extends State<GlassListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.005 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              opacity: _hovered ? 0.84 : 0.7,
              borderOpacity: _hovered ? 0.7 : 0.5,
              tint: _hovered
                  ? Color.alphaBlend(
                      accent.withValues(alpha: 0.04),
                      Colors.white,
                    )
                  : Colors.white,
              elevated: _hovered,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassDirectoryHeader extends StatelessWidget {
  const GlassDirectoryHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.countLabel,
  });

  final String title;
  final IconData icon;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Row(
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          countLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class GlassEmptyState extends StatelessWidget {
  const GlassEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class GlassTableHeader extends StatelessWidget {
  const GlassTableHeader({super.key, required this.columns});

  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: i == 0 ? 1 : 3,
              child: Text(columns[i], style: style),
            ),
        ],
      ),
    );
  }
}

class GlassAdminPage extends StatelessWidget {
  const GlassAdminPage({
    super.key,
    required this.title,
    required this.subtitle,
    this.toolbar,
    required this.body,
  });

  final String title;
  final String subtitle;
  final Widget? toolbar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4F7),
      body: DashboardBackdrop(
        child: Column(
          children: [
            GlassPageHeader(
              title: title,
              subtitle: subtitle,
              onBack: () => Navigator.of(context).pop(),
            ),
            if (toolbar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: toolbar!,
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

Widget glassSummaryGrid({
  required BuildContext context,
  required Color accent,
  required List<GlassSummaryStatCard> cards,
  int? columns,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final resolvedColumns = columns ??
          (constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
                  ? 2
                  : 1);
      final aspectRatio = resolvedColumns >= 4
          ? 3.6
          : resolvedColumns == 1
              ? 4.8
              : 4.2;
      return GridView.count(
        crossAxisCount: resolvedColumns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: resolvedColumns >= 4 ? 10 : 12,
        mainAxisSpacing: resolvedColumns >= 4 ? 10 : 12,
        childAspectRatio: aspectRatio,
        children: cards,
      );
    },
  );
}

InputDecoration glassInputDecoration(
  BuildContext context, {
  required String hint,
  IconData? prefixIcon,
}) {
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.45),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: theme.dividerColor.withValues(alpha: 0.35),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
  );
}
