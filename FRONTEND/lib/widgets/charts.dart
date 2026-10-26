import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

TextPainter _tp(String t, TextStyle s) =>
    TextPainter(text: TextSpan(text: t, style: s), textDirection: TextDirection.ltr)..layout();

/// Circular progress ring (service level).
class RingPainter extends CustomPainter {
  RingPainter({required this.value, required this.color});
  final double value; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: c, radius: r);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.white;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.value != value || old.color != color;
}

/// Two-series smooth line chart with hover/tap tooltip.
class LineChartView extends StatefulWidget {
  const LineChartView({
    super.key,
    required this.labels,
    required this.a,
    required this.b,
    required this.aName,
    required this.bName,
    required this.aColor,
    required this.bColor,
  });
  final List<String> labels;
  final List<double> a, b;
  final String aName, bName;
  final Color aColor, bColor;

  @override
  State<LineChartView> createState() => _LineChartViewState();
}

class _LineChartViewState extends State<LineChartView> {
  int? _hover;

  void _setFrom(double dx, double width) {
    final n = widget.labels.length;
    if (n < 2) return;
    final w = width - LinePainter.left - LinePainter.right;
    final i = (((dx - LinePainter.left) / w) * (n - 1)).round().clamp(0, n - 1).toInt();
    if (i != _hover) setState(() => _hover = i);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return MouseRegion(
        onHover: (e) => _setFrom(e.localPosition.dx, box.maxWidth),
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setFrom(d.localPosition.dx, box.maxWidth),
          onHorizontalDragUpdate: (d) => _setFrom(d.localPosition.dx, box.maxWidth),
          child: CustomPaint(
            size: Size(box.maxWidth, box.maxHeight),
            painter: LinePainter(
              labels: widget.labels,
              a: widget.a,
              b: widget.b,
              aName: widget.aName,
              bName: widget.bName,
              aColor: widget.aColor,
              bColor: widget.bColor,
              hover: _hover,
            ),
          ),
        ),
      );
    });
  }
}

class LinePainter extends CustomPainter {
  LinePainter({
    required this.labels,
    required this.a,
    required this.b,
    required this.aName,
    required this.bName,
    required this.aColor,
    required this.bColor,
    required this.hover,
  });
  final List<String> labels;
  final List<double> a, b;
  final String aName, bName;
  final Color aColor, bColor;
  final int? hover;

  static const left = 36.0, right = 10.0, top = 10.0, bottom = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n < 2 || a.length != n || b.length != n) return;

    final peak = [...a, ...b].fold<double>(0, math.max);
    final maxY = math.max(5.0, (peak / 5).ceil() * 5.0);
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    double x(int i) => left + w * i / (n - 1);
    double y(double v) => top + h - h * (v / maxY);

    const axis = TextStyle(fontSize: 11, color: AppColors.muted);
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final gy = top + h - h * i / 5;
      canvas.drawLine(Offset(left, gy), Offset(size.width - right, gy), grid);
      final t = _tp((maxY * i / 5).toStringAsFixed(0), axis);
      t.paint(canvas, Offset(left - 8 - t.width, gy - t.height / 2));
    }

    final step = size.width < 560 ? 3 : (size.width < 800 ? 2 : 1);
    for (var i = 0; i < n; i++) {
      if (i % step != 0) continue;
      final t = _tp(labels[i], axis);
      t.paint(canvas, Offset(x(i) - t.width / 2, size.height - bottom + 8));
    }

    Path smooth(List<double> s) {
      final p = Path()..moveTo(x(0), y(s[0]));
      for (var i = 0; i < n - 1; i++) {
        final mid = (x(i) + x(i + 1)) / 2;
        p.cubicTo(mid, y(s[i]), mid, y(s[i + 1]), x(i + 1), y(s[i + 1]));
      }
      return p;
    }

    Paint stroke(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = c;

    canvas.drawPath(smooth(b), stroke(bColor));
    canvas.drawPath(smooth(a), stroke(aColor));

    final hv = hover;
    if (hv != null) {
      final hx = x(hv);
      canvas.drawLine(Offset(hx, top), Offset(hx, top + h),
          Paint()..color = AppColors.line..strokeWidth = 1.2);
      for (final e in [(a[hv], aColor), (b[hv], bColor)]) {
        canvas.drawCircle(Offset(hx, y(e.$1)), 6.5, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(hx, y(e.$1)), 4.5, Paint()..color = e.$2);
      }

      const ts = TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w600);
      final l1 = _tp('$aName  ${a[hv].toStringAsFixed(0)}', ts);
      final l2 = _tp('$bName  ${b[hv].toStringAsFixed(0)}', ts);
      final l0 = _tp(labels[hv], const TextStyle(fontSize: 11, color: AppColors.muted));
      final bw = math.max(l0.width, math.max(l1.width, l2.width)) + 40;
      const bh = 76.0;
      var bx = hx + 14;
      if (bx + bw > size.width - 4) bx = hx - 14 - bw;
      final by = top + 6;
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(10));
      canvas.drawRRect(rrect.shift(const Offset(0, 2)), Paint()..color = Colors.black.withValues(alpha: 0.06));
      canvas.drawRRect(rrect, Paint()..color = Colors.white);
      canvas.drawRRect(rrect, Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.line);
      l0.paint(canvas, Offset(bx + 14, by + 8));
      canvas.drawLine(Offset(bx + 14, by + 36), Offset(bx + 26, by + 36), stroke(aColor));
      l1.paint(canvas, Offset(bx + 32, by + 28));
      canvas.drawLine(Offset(bx + 14, by + 58), Offset(bx + 26, by + 58), stroke(bColor));
      l2.paint(canvas, Offset(bx + 32, by + 50));
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter old) => true;
}
