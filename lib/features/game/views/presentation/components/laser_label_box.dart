import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Neon HUD panel (tech / space style) that displays a short text
/// below the mascot.
///
/// Rendering is cached in a [ui.Picture]: it is only recomputed
/// when the text or maximum width changes.
class LaserLabelBox extends PositionComponent {
  LaserLabelBox({
    required this._text,
    required this.accentColor,
    super.position,
    super.anchor = Anchor.topCenter,
  }) {
    _rebuild();
  }

  /// Outline, neon halo, and accent details color.
  Color accentColor;

  /// Updates the neon color and redraws the panel.
  set color(Color value) {
    if (value == accentColor) return;
    accentColor = value;
    _rebuild();
  }

  String _text;
  ui.Picture? _picture;
  double _maxWidth = _defaultMaxWidth;

  static const double _defaultMaxWidth = 352;
  static const double _maxTextWidth = 300;
  static const double _paddingH = 30;
  static const double _paddingV = 20;
  static const double _chamfer = 16; // cut corners
  static const double _borderWidth = 2.5;

  /// Maximum panel width (rendering adapts to viewport width).
  set maxWidth(double value) {
    final next = value.clamp(48.0, _defaultMaxWidth).toDouble();
    if (next == _maxWidth) return;
    _maxWidth = next;
    _rebuild();
  }

  /// Updates displayed text and redraws the panel.
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _rebuild();
  }

  @override
  void render(Canvas canvas) {
    final picture = _picture;
    if (picture != null) canvas.drawPicture(picture);
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  // ── Cache Construction ─────────────────────────────────────────────

  void _rebuild() {
    final scale = (_maxWidth / _defaultMaxWidth).clamp(0.65, 1.0).toDouble();
    final paddingH = _paddingH * scale;
    final paddingV = _paddingV * scale;

    final textPainter =
        TextPainter(
          text: TextSpan(text: _text, style: _textStyle(scale)),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          textWidthBasis: TextWidthBasis.longestLine,
        )..layout(
          maxWidth: (_maxWidth - paddingH * 2)
              .clamp(1.0, _maxTextWidth)
              .toDouble(),
        );

    size = Vector2(
      textPainter.width + paddingH * 2,
      textPainter.height + paddingV * 2,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final panelSize = Size(size.x, size.y);
    final path = _panelPath(panelSize, _chamfer * scale);

    _paintGlow(canvas, path, scale);
    _paintFill(canvas, path, panelSize);
    _paintInnerGlow(canvas, path, scale);
    _paintScanlines(canvas, path, panelSize, scale);
    _paintSheen(canvas, path, panelSize);
    _paintBorder(canvas, path, scale);
    _paintAccents(canvas, panelSize, scale);
    textPainter.paint(canvas, Offset(paddingH, paddingV));

    _picture?.dispose();
    _picture = recorder.endRecording();
    textPainter.dispose();
  }

  TextStyle _textStyle(double scale) => TextStyle(
    color: Colors.white,
    fontSize: 18 * scale,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4 * scale,
    height: 1.25,
    shadows: [
      // Neon glow around letters.
      Shadow(color: accentColor.withValues(alpha: 0.9), blurRadius: 10 * scale),
      Shadow(
        color: const Color(0x66000000),
        blurRadius: 3 * scale,
        offset: Offset(0, scale),
      ),
    ],
  );

  // ── Shape ──────────────────────────────────────────────────────────

  /// Rectangle with four cut corners (sci-fi panel look).
  Path _panelPath(Size s, double c) => Path()
    ..moveTo(c, 0)
    ..lineTo(s.width - c, 0)
    ..lineTo(s.width, c)
    ..lineTo(s.width, s.height - c)
    ..lineTo(s.width - c, s.height)
    ..lineTo(c, s.height)
    ..lineTo(0, s.height - c)
    ..lineTo(0, c)
    ..close();

  Paint _stroke(double width, Color color, {double blur = 0}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = color
    ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

  // ── Paint Layers ───────────────────────────────────────────────────

  /// Outer neon halo in two passes (wide & diffuse + tight & vivid).
  void _paintGlow(Canvas canvas, Path path, double scale) {
    canvas
      ..drawPath(
        path,
        _stroke(
          12 * scale,
          accentColor.withValues(alpha: 0.5),
          blur: 26 * scale,
        ),
      )
      ..drawPath(
        path,
        _stroke(
          5 * scale,
          accentColor.withValues(alpha: 0.95),
          blur: 8 * scale,
        ),
      );
  }

  /// Dark tinted background, top-to-bottom gradient.
  void _paintFill(Canvas canvas, Path path, Size s) {
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(s.width / 2, 0),
          Offset(s.width / 2, s.height),
          [
            Color.lerp(
              accentColor,
              const Color(0xFF040A1E),
              0.72,
            )!.withValues(alpha: 0.92),
            Color.lerp(
              accentColor,
              const Color(0xFF02040F),
              0.9,
            )!.withValues(alpha: 0.95),
          ],
        ),
    );
  }

  /// Inner edge illumination around the panel border.
  void _paintInnerGlow(Canvas canvas, Path path, double scale) {
    canvas
      ..save()
      ..clipPath(path)
      ..drawPath(
        path,
        _stroke(
          18 * scale,
          accentColor.withValues(alpha: 0.45),
          blur: 12 * scale,
        ),
      )
      ..restore();
  }

  /// Fine horizontal holographic scanlines.
  void _paintScanlines(Canvas canvas, Path path, Size s, double scale) {
    final paint = Paint()
      ..strokeWidth = scale
      ..color = Colors.white.withValues(alpha: 0.05);
    final step = 4 * scale;

    canvas
      ..save()
      ..clipPath(path);
    for (var y = step; y < s.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), paint);
    }
    canvas.restore();
  }

  /// Glass sheen across top portion of panel.
  void _paintSheen(Canvas canvas, Path path, Size s) {
    canvas
      ..save()
      ..clipPath(path)
      ..drawRect(
        Rect.fromLTWH(0, 0, s.width, s.height * 0.5),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, s.height * 0.5),
            [
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0),
            ],
          ),
      )
      ..restore();
  }

  /// Sharp neon border lightened towards white.
  void _paintBorder(Canvas canvas, Path path, double scale) {
    canvas.drawPath(
      path,
      _stroke(
        _borderWidth * scale,
        Color.lerp(accentColor, Colors.white, 0.55)!,
      ),
    );
  }

  /// Tech details: luminous edge segments and side nodes.
  void _paintAccents(Canvas canvas, Size s, double scale) {
    final c = _chamfer * scale;
    final inset = c + 10 * scale;
    final length = 44 * scale;
    final y = s.height / 2;

    final segments = Path()
      // Top left
      ..moveTo(inset, 0)
      ..lineTo(inset + length, 0)
      // Bottom right
      ..moveTo(s.width - inset - length, s.height)
      ..lineTo(s.width - inset, s.height);

    final nodes = Path()
      ..addPolygon(_diamond(Offset(0, y), 4.5 * scale), true)
      ..addPolygon(_diamond(Offset(s.width, y), 4.5 * scale), true);

    // Blurred pass (glow) then sharp pass (white core).
    canvas
      ..drawPath(segments, _stroke(5 * scale, accentColor, blur: 6 * scale))
      ..drawPath(segments, _stroke(3 * scale, Colors.white))
      ..drawPath(
        nodes,
        Paint()
          ..color = accentColor
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * scale),
      )
      ..drawPath(nodes, Paint()..color = Colors.white);
  }

  List<Offset> _diamond(Offset center, double r) => [
    center + Offset(0, -r),
    center + Offset(r, 0),
    center + Offset(0, r),
    center + Offset(-r, 0),
  ];
}
