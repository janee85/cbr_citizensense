import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import 'seal_logo.dart';

/// Split layout on wide screens (brand panel + form), single column on mobile.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final form = Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[
                    const Center(child: SealLogo(size: 84)),
                    const SizedBox(height: 12),
                    Text('Cabadbaran CitizenSense',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.navy)),
                    const SizedBox(height: 24),
                  ],
                  child,
                ],
              ),
            ),
          ),
        );
        if (!wide) return SafeArea(child: form);
        return Row(children: [
          const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(flex: 5, child: ColoredBox(color: AppColors.canvas, child: form)),
        ]);
      }),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyDark, AppColors.navy, Color(0xFF0F5BB5)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 340,
              height: 340,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(child: CustomPaint(painter: _StarRingPainter())),
                const SealLogo(size: 220),
              ]),
            ),
            const SizedBox(height: 28),
            const Text('Cabadbaran CitizenSense',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Container(width: 48, height: 3, color: AppColors.gold),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 380),
              child: Text(
                'Report a concern once. Machine learning rates how urgent it is and sends it to the right city office.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),
            const Text('City Government of Cabadbaran · Agusan del Norte',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

/// Ring of stars around the seal, echoing the stars on the official seal.
class _StarRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width / 2 - 14;
    const n = 28;
    final paint = Paint()..color = AppColors.gold.withValues(alpha: 0.55);
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n;
      final p = Offset(c.dx + radius * math.cos(a), c.dy + radius * math.sin(a));
      canvas.drawPath(_star(p, 6), paint);
    }
  }

  Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.42;
      final a = -math.pi / 2 + i * math.pi / 5;
      final x = c.dx + rad * math.cos(a);
      final y = c.dy + rad * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shows which role the typed email will get.
class RoleHint extends StatelessWidget {
  const RoleHint({super.key, required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final e = email.trim();
    final role = roleFromEmail(e);
    final String text;
    final Color color;
    final IconData icon;
    if (role != null) {
      text = 'Role detected: ${role.label}';
      color = AppColors.forest;
      icon = role.icon;
    } else if (e.contains('@')) {
      text = 'Unknown domain. Use @gmail.com, @staff.com or @admin.com.';
      color = const Color(0xFFC77700);
      icon = Icons.info_outline_rounded;
    } else {
      text = 'Your role is set by your email: @gmail.com citizen, @staff.com staff, @admin.com admin.';
      color = AppColors.muted;
      icon = Icons.info_outline_rounded;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.3))),
      ]),
    );
  }
}

class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, required this.message, this.good = false});
  final String message;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final c = good ? AppColors.forest : AppColors.star;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(good ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: c, height: 1.4, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
