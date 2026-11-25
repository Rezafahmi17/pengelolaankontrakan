import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool showBadge;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.showBadge = false,
  });
}

/// Liquid Glass Tab Bar — Disesuaikan dengan palet warna utama JEKPOL Polinela
/// (Emerald Green #084D2A -> #0B6B3A), dengan animasi fisika pegas teredam
/// (damped spring: z=0.53, wn=11.1, ~14% overshoot), lensa kaca cair
/// (emerald liquid glass refraction & mint chromatic fringe), serta ikon menyala saat aktif.
class CustomFloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const CustomFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<CustomFloatingNavBar> createState() => _CustomFloatingNavBarState();
}

class _CustomFloatingNavBarState extends State<CustomFloatingNavBar>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  /// Posisi pusat lensa dalam satuan indeks tab (0.0 .. N-1), mendukung overshoot pegas
  late double _lensIndex;
  late double _fromIndex;
  late double _toIndex;
  Duration? _startTime;

  @override
  void initState() {
    super.initState();
    _lensIndex = widget.currentIndex.toDouble();
    _fromIndex = _lensIndex;
    _toIndex = _lensIndex;
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant CustomFloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateTo(widget.currentIndex.toDouble());
    }
  }

  void _animateTo(double target) {
    _fromIndex = _lensIndex;
    _toIndex = target;
    _startTime = null;
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  /// Rumus pegas teredam (damped spring): ~14% overshoot, puncak di ~0.33s
  double _dampedSpring(double t) {
    if (t <= 0) return 0;
    const double z = 0.53;
    const double wn = 11.1;
    final double wd = wn * math.sqrt(1 - z * z);
    final double k = z / math.sqrt(1 - z * z);
    return 1.0 -
        math.exp(-z * wn * t) * (math.cos(wd * t) + k * math.sin(wd * t));
  }

  void _onTick(Duration elapsed) {
    _startTime ??= elapsed;
    final double t = (elapsed - _startTime!).inMicroseconds / 1e6;
    if (t >= 1.15) {
      setState(() {
        _lensIndex = _toIndex;
      });
      _ticker.stop();
      return;
    }
    final double p = _dampedSpring(t);
    setState(() {
      _lensIndex = _fromIndex + (_toIndex - _fromIndex) * p;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.items.length;
    final bool isCompact = count >= 5;
    final double horizontalMargin = isCompact ? 10.0 : 18.0;
    const double totalHeight = 80.0;
    const double pillHeight = 62.0;
    const double pillTop = (totalHeight - pillHeight) / 2;
    const double lensHeight = 76.0;
    const double lensTop = (totalHeight - lensHeight) / 2;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 10),
        child: SizedBox(
          height: totalHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double slotWidth = totalWidth / count;
              final double lensWidth = math.min(
                slotWidth * (isCompact ? 1.16 : 1.12),
                isCompact ? 92.0 : 112.0,
              );

              final double lensCenter = (_lensIndex + 0.5) * slotWidth;
              final double lensLeft = (lensCenter - lensWidth / 2)
                  .clamp(-6.0, totalWidth - lensWidth + 6.0);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 1. PILL UTAMA — Warna Hijau Emerald JEKPOL (AppColors.primaryDark -> AppColors.primary)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: pillTop,
                    height: pillHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryDark, // #084D2A
                            AppColors.primary, // #0B6B3A
                            Color(0xFF0D7A43),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(pillHeight / 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.38),
                            blurRadius: 28,
                            spreadRadius: 1,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),

                  // 2. LENSA KACA CAIR HIJAU EMERALD (LIQUID GLASS LENS)
                  Positioned(
                    left: lensLeft,
                    top: lensTop,
                    width: lensWidth,
                    height: lensHeight,
                    child: IgnorePointer(
                      child: _LiquidGlassLens(
                        width: lensWidth,
                        height: lensHeight,
                        pillHeight: pillHeight,
                      ),
                    ),
                  ),

                  // 3. ITEM TAB (Ikon + Label dengan efek magnetik & emerald-white glow)
                  Positioned.fill(
                    child: Row(
                      children: List.generate(count, (i) {
                        final item = widget.items[i];
                        final bool isSelected = widget.currentIndex == i;
                        final double dist = i - _lensIndex;
                        final double magneticShift =
                            (dist.abs() > 0.05 && dist.abs() < 2.5)
                                ? -dist.sign * 2.5
                                : 0.0;

                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (widget.currentIndex != i) {
                                HapticFeedback.selectionClick();
                                widget.onTap(i);
                              }
                            },
                            child: Transform.translate(
                              offset: Offset(magneticShift, 0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: const Cubic(0.2, 0.8, 0.2, 1.0),
                                transform: Matrix4.translationValues(
                                  0,
                                  isSelected ? -4.5 : 1.0,
                                  0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Badge(
                                      isLabelVisible: item.showBadge,
                                      smallSize: 9,
                                      backgroundColor: AppColors.warning,
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 240),
                                        decoration: isSelected
                                            ? BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.60),
                                                    blurRadius: 12,
                                                    spreadRadius: 0.5,
                                                  ),
                                                  BoxShadow(
                                                    color: const Color(
                                                            0xFF6EE7B7)
                                                        .withValues(alpha: 0.45),
                                                    blurRadius: 18,
                                                  ),
                                                ],
                                              )
                                            : null,
                                        child: Icon(
                                          isSelected
                                              ? item.activeIcon
                                              : item.icon,
                                          size: isCompact ? 22 : 24,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFB7DFC8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      opacity: isSelected ? 1.0 : 0.72,
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isCompact ? 10.0 : 11.0,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          letterSpacing: -0.2,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFC7E8D6),
                                          shadows: isSelected
                                              ? const [
                                                  Shadow(
                                                    color: Color(0x88FFFFFF),
                                                    blurRadius: 6,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // 4. SPECULAR RIM OVERLAY (Bingkai kilau kaca di lapisan paling atas lensa)
                  Positioned(
                    left: lensLeft,
                    top: lensTop,
                    width: lensWidth,
                    height: lensHeight,
                    child: IgnorePointer(
                      child: _LiquidGlassRim(
                        width: lensWidth,
                        height: lensHeight,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassLens extends StatelessWidget {
  final double width;
  final double height;
  final double pillHeight;

  const _LiquidGlassLens({
    required this.width,
    required this.height,
    required this.pillHeight,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = width * 0.36;
    final double bandHeight = (height - pillHeight) / 2;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.42),
            blurRadius: 18,
            spreadRadius: -3,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            children: [
              // Lapisan dasar kaca (emerald glass see-through)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.30),
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.25),
                      ],
                      stops: const [0.0, 0.18, 0.82, 1.0],
                    ),
                  ),
                ),
              ),

              // Bagian tubuh pil hijau emerald yang terbiaskan di tengah lensa (.body)
              Positioned(
                left: 0,
                right: 0,
                top: bandHeight,
                height: pillHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF0E8347).withValues(alpha: 0.95),
                        AppColors.primary.withValues(alpha: 0.96),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(radius * 0.85),
                  ),
                ),
              ),

              // Pita refraksi atas (.band.t + emerald-mint chromatic fringe)
              Positioned(
                left: 10,
                right: 10,
                top: 0,
                height: bandHeight + 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF34D399).withValues(alpha: 0.65),
                        Colors.white.withValues(alpha: 0.35),
                        const Color(0xFF34D399).withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),

              // Pita refraksi bawah (.band.b + emerald-mint chromatic fringe)
              Positioned(
                left: 10,
                right: 10,
                bottom: 0,
                height: bandHeight + 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF34D399).withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.28),
                        const Color(0xFF34D399).withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),

              // Cahaya bias samping dalam (.glow)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFFA7F3D0).withValues(alpha: 0.35),
                        Colors.transparent,
                        Colors.transparent,
                        const Color(0xFFA7F3D0).withValues(alpha: 0.35),
                      ],
                      stops: const [0.0, 0.22, 0.78, 1.0],
                    ),
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

class _LiquidGlassRim extends StatelessWidget {
  final double width;
  final double height;

  const _LiquidGlassRim({
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = width * 0.36;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: const Color(0xFFD1FAE5).withValues(alpha: 0.75),
          width: 1.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.50),
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: 0.32),
          ],
          stops: const [0.0, 0.14, 0.86, 1.0],
        ),
      ),
    );
  }
}
