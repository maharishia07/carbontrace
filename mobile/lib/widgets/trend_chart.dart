import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Single-series g/km trend with baseline band, drawn like a modern web
/// analytics chart: smooth curve, soft gradient area fill, recessive grid.
///
/// Chart rules kept: one axis, thin 2px line, no legend (single series —
/// the card title names it), labels in ink colors, selective direct label.
class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final double? baseline;

  const TrendChart({super.key, required this.points, this.baseline});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox(
        height: 170,
        child: Center(
          child: Text('Trend appears after a few recorded trips',
              style: TextStyle(color: CtColors.inkSecondary, fontSize: 13)),
        ),
      );
    }
    return SizedBox(
      height: 190,
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
    const padL = 38.0, padR = 10.0, padT = 14.0, padB = 22.0;
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
    lo -= range * 0.14;
    hi += range * 0.14;

    double x(int i) => padL + plotW * i / (pts.length - 1);
    double y(double v) => padT + plotH * (1 - (v - lo) / (hi - lo));

    // recessive grid + ink labels
    final grid = Paint()
      ..color = CtColors.divider
      ..strokeWidth = 1;
    const labelStyle = TextStyle(color: CtColors.inkFaint, fontSize: 10);
    for (var i = 0; i <= 2; i++) {
      final v = lo + (hi - lo) * i / 2;
      final yy = y(v);
      canvas.drawLine(Offset(padL, yy), Offset(size.width - padR, yy), grid);
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(0), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 6, yy - tp.height / 2));
    }

    // baseline band (+/-5%) and dashed baseline
    if (baseline != null) {
      final bandTop = y(baseline! * 1.05);
      final bandBot = y(baseline! * 0.95);
      final band = Paint()..color = CtColors.baselineBand;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(padL, bandTop, size.width - padR, bandBot),
          const Radius.circular(4),
        ),
        band,
      );
      final dash = Paint()
        ..color = CtColors.brandBright.withValues(alpha: 0.7)
        ..strokeWidth = 1.4;
      final yy = y(baseline!);
      for (var xx = padL; xx < size.width - padR; xx += 9) {
        canvas.drawLine(Offset(xx, yy), Offset(xx + 4.5, yy), dash);
      }
    }

    // smooth path through points (quadratic midpoint smoothing)
    final line = Path()..moveTo(x(0), y(pts[0].gpkm));
    for (var i = 1; i < pts.length; i++) {
      final x0 = x(i - 1), y0 = y(pts[i - 1].gpkm);
      final x1 = x(i), y1 = y(pts[i].gpkm);
      final mx = (x0 + x1) / 2;
      line.cubicTo(mx, y0, mx, y1, x1, y1);
    }

    // soft gradient area under the curve
    final area = Path.from(line)
      ..lineTo(x(pts.length - 1), padT + plotH)
      ..lineTo(padL, padT + plotH)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CtColors.chartLine.withValues(alpha: 0.16),
            CtColors.chartLine.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, padT, size.width, plotH)),
    );

    // the series line: thin, rounded
    canvas.drawPath(
      line,
      Paint()
        ..color = CtColors.chartLine
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // last point marker + selective direct label
    final lastX = x(pts.length - 1), lastY = y(pts.last.gpkm);
    canvas.drawCircle(
        Offset(lastX, lastY), 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(lastX, lastY), 4.4, Paint()..color = CtColors.chartLine);
    canvas.drawCircle(Offset(lastX, lastY), 1.9, Paint()..color = Colors.white);
    final lastLabel = TextPainter(
      text: TextSpan(
          text: '${pts.last.gpkm.toStringAsFixed(0)} g/km',
          style: const TextStyle(
              color: CtColors.ink, fontSize: 11.5, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    lastLabel.paint(
        canvas,
        Offset((lastX - lastLabel.width).clamp(padL, size.width - padR),
            (lastY - lastLabel.height - 8).clamp(0, size.height)));

    // x-axis end labels
    final tpA = TextPainter(
        text: TextSpan(text: _fmt(pts.first.date), style: labelStyle),
        textDirection: TextDirection.ltr)
      ..layout();
    tpA.paint(canvas, Offset(padL, size.height - tpA.height));
    final tpB = TextPainter(
        text: TextSpan(text: _fmt(pts.last.date), style: labelStyle),
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
