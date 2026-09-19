import 'dart:ui';

import 'package:flutter/material.dart';

/// Mercate brand teal.
const Color kMercateTeal = Color(0xFF00E5A8);
const Color kMercateTealDeep = Color(0xFF00B87A);
const Color kMercateTealSoft = Color(0xFF5CFFE0);

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: kMercateTeal,
      brightness: Brightness.light,
      primary: kMercateTealDeep,
      secondary: kMercateTeal,
    ).copyWith(
      surface: const Color(0xFFF2F7F5),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFE8F5F0),
      surfaceContainer: const Color(0xFFDFF0EA),
      surfaceContainerHigh: const Color(0xFFD0E8E0),
    );

    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: kMercateTeal,
      brightness: Brightness.dark,
      primary: kMercateTeal,
      secondary: kMercateTealSoft,
    ).copyWith(
      surface: const Color(0xFF0B1412),
      surfaceContainerLowest: const Color(0xFF0F1A17),
      surfaceContainerLow: const Color(0xFF152420),
      surfaceContainer: const Color(0xFF1A2C27),
      surfaceContainerHigh: const Color(0xFF223832),
    );

    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.55 : 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: isDark ? 0.08 : 0.06),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor:
            scheme.surfaceContainer.withValues(alpha: isDark ? 0.82 : 0.92),
        indicatorColor: kMercateTeal.withValues(alpha: isDark ? 0.28 : 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: isDark ? const Color(0xFF00382A) : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: isDark ? const Color(0xFF00382A) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outline.withValues(alpha: 0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outline.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        selectedColor: scheme.primary.withValues(alpha: 0.22),
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer.withValues(alpha: 0.96),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.12),
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}

/// Frosted glass panel for cards / sheets.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final bool accent;
  final Color? glowColor;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blur = 18,
    this.accent = false,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = glowColor ?? kMercateTeal;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accent
              ? glow.withValues(alpha: isDark ? 0.35 : 0.4)
              : (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: isDark ? 0.1 : 0.06),
          width: accent ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          if (accent)
            BoxShadow(
              color: glow.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 28,
              spreadRadius: -4,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: accent
                    ? [
                        glow.withValues(alpha: isDark ? 0.22 : 0.18),
                        scheme.surfaceContainer
                            .withValues(alpha: isDark ? 0.4 : 0.55),
                      ]
                    : [
                        scheme.surfaceContainerHighest
                            .withValues(alpha: isDark ? 0.5 : 0.7),
                        scheme.surfaceContainer
                            .withValues(alpha: isDark ? 0.38 : 0.55),
                      ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Soft gradient backdrop behind glass surfaces.
class GlassScaffoldBody extends StatelessWidget {
  final Widget child;

  const GlassScaffoldBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0B1412),
                        Color(0xFF0E1F1A),
                        Color(0xFF0A1620),
                      ]
                    : const [
                        Color(0xFFF5FBFA),
                        Color(0xFFE8F6F1),
                        Color(0xFFEEF4FF),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kMercateTeal.withValues(alpha: isDark ? 0.14 : 0.12),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -60,
          child: IgnorePointer(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kMercateTealDeep.withValues(alpha: isDark ? 0.1 : 0.08),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
