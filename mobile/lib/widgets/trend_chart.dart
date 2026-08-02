import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Single-series g/km trend line with the vehicle's baseline band.
///
/// Chart rules applied: one axis, thin 2px line, recessive gridlines,
/// no legend (single series — the title names it), text in ink colors.
class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final double? baseline; // city baseline g/km, if learned

  const TrendChart({super.key, required this.points, this.baseline});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text('Trend appears after a few recorded trips',
              style: TextStyle(color: Colors.black54)),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendPainter(points, baseline),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> pts;
  final double? baseline;

  _TrendPainter(this.pts, this.baseline);

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 40.0, padR = 8.0, padT = 10.0, padB = 22.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final values = pts.map((p) => p.gpkm).toList();
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (baseline != null) {
      lo = lo < baseline! ? lo : baseline!;
      hi = hi > baseline! ? hi : baseline!;
    }
    final range = (hi - lo) < 1 ? 1 : (hi - lo);
    lo -= range * 0.12;
    hi += range * 0.12;

    double x(int i) => padL + plotW * i / (pts.length - 1);
    double y(double v) => padT + plotH * (1 - (v - lo) / (hi - lo));

    // recessive grid: 3 horizontal lines + ink labels
    final grid = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: Colors.black54, fontSize: 10);
    for (var i = 0; i <= 2; i++) {
      final v = lo + (hi - lo) * i / 2;
      final yy = y(v);
      canvas.drawLine(Offset(padL, yy), Offset(size.width - padR, yy), grid);
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(0), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 4, yy - tp.height / 2));
    }

    // baseline band (+/-5%) then baseline dash
    if (baseline != null) {
      final bandTop = y(baseline! * 1.05);
      final bandBot = y(baseline! * 0.95);
      canvas.drawRect(
        Rect.fromLTRB(padL, bandTop, size.width - padR, bandBot),
        Paint()..color = CtColors.baselineBand,
      );
      final dash = Paint()
        ..color = CtColors.brand.withOpacity(0.55)
        ..strokeWidth = 1.4;
      final yy = y(baseline!);
      for (var xx = padL; xx < size.width - padR; xx += 8) {
        canvas.drawLine(Offset(xx, yy), Offset(xx + 4, yy), dash);
      }
    }

    // the series: thin 2px line
    final line = Paint()
      ..color = CtColors.chartLine
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(x(0), y(pts[0].gpkm));
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(x(i), y(pts[i].gpkm));
    }
    canvas.drawPath(path, line);

    // selective direct label: last point only, with >=8px marker
    final lastX = x(pts.length - 1), lastY = y(pts.last.gpkm);
    canvas.drawCircle(lastX == 0 ? Offset.zero : Offset(lastX, lastY), 4.5,
        Paint()..color = CtColors.chartLine);
    canvas.drawCircle(Offset(lastX, lastY), 2.2, Paint()..color = Colors.white);
    final lastLabel = TextPainter(
      text: TextSpan(
          text: '${pts.last.gpkm.toStringAsFixed(0)} g/km',
          style: const TextStyle(
              color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    lastLabel.paint(
        canvas,
        Offset((lastX - lastLabel.width).clamp(padL, size.width - padR),
            (lastY - lastLabel.height - 6).clamp(0, size.height)));

    // x-axis end labels
    final firstDate = _fmt(pts.first.date), lastDate = _fmt(pts.last.date);
    final tpA = TextPainter(
        text: TextSpan(text: firstDate, style: labelStyle),
        textDirection: TextDirection.ltr)
      ..layout();
    tpA.paint(canvas, Offset(padL, size.height - tpA.height));
    final tpB = TextPainter(
        text: TextSpan(text: lastDate, style: labelStyle),
        textDirection: TextDirection.ltr)
      ..layout();
    tpB.paint(
        canvas, Offset(size.width - padR - tpB.width, size.height - tpB.height));
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}';

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.pts != pts || old.baseline != baseline;
}
