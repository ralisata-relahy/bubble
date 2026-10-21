import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Panneau néon « verre » qui affiche un court texte sous le mascotte.
///
/// Le rendu est mis en cache dans un [ui.Picture] : il n'est recalculé
/// que lorsque le texte change.
class LaserLabelBox extends PositionComponent {
  LaserLabelBox({
    required this._text,
    required this.accentColor,
    super.position,
    super.anchor = Anchor.topCenter,
  }) {
    _rebuild();
  }

  /// Couleur du contour et du halo.
  final Color accentColor;

  String _text;
  ui.Picture? _picture;

  static const double _defaultMaxWidth = 352;
  static const double _maxTextWidth = 300;
  static const double _paddingH = 26;
  static const double _paddingV = 16;
  static const double _cornerRadius = 22;
  static const double _borderWidth = 3;
  static const double _glowBlur = 14;

  double _maxWidth = _defaultMaxWidth;

  set maxWidth(double value) {
    final nextWidth = value.clamp(48.0, _defaultMaxWidth).toDouble();
    if (nextWidth == _maxWidth) return;
    _maxWidth = nextWidth;
    _rebuild();
  }

  /// Met à jour le texte et redessine le panneau.
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

  // ── Construction du cache ─────────────────────────────────────────

  void _rebuild() {
    final scale = (_maxWidth / _defaultMaxWidth).clamp(0.65, 1.0).toDouble();
    final paddingH = _paddingH * scale;
    final paddingV = _paddingV * scale;
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 18 * scale,
      fontWeight: FontWeight.w700,
      height: 1.25,
      shadows: [
        Shadow(
          color: const Color(0x66000000),
          blurRadius: 4 * scale,
          offset: Offset(0, scale),
        ),
      ],
    );
    final textPainter =
        TextPainter(
          text: TextSpan(text: _text, style: textStyle),
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
    final panel = RRect.fromRectAndRadius(
      Offset.zero & Size(size.x, size.y),
      Radius.circular(_cornerRadius * scale),
    );

    _paintGlow(canvas, panel, scale);
    _paintFill(canvas, panel);
    _paintSheen(canvas, panel, scale);
    _paintBorder(canvas, panel, scale);
    textPainter.paint(canvas, Offset(paddingH, paddingV));

    _picture?.dispose();
    _picture = recorder.endRecording();
    textPainter.dispose();
  }

  // ── Couches de dessin ─────────────────────────────────────────────

  /// Halo lumineux diffus autour du panneau.
  void _paintGlow(Canvas canvas, RRect panel, double scale) {
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth * 2 * scale
        ..color = accentColor.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _glowBlur * scale),
    );
  }

  /// Fond semi-transparent accordé à la couleur aléatoire du panneau.
  void _paintFill(Canvas canvas, RRect panel) {
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = ui.Gradient.linear(
          panel.outerRect.topCenter,
          panel.outerRect.bottomCenter,
          [
            Color.lerp(accentColor, Colors.black, 0.45)!.withValues(alpha: 0.9),
            Color.lerp(accentColor, Colors.black, 0.78)!.withValues(alpha: 0.9),
          ],
        ),
    );
  }

  /// Reflet de verre sur la moitié haute + fin liseré intérieur.
  void _paintSheen(Canvas canvas, RRect panel, double scale) {
    final inner = panel.deflate((_borderWidth + 4) * scale);
    final rect = inner.outerRect;

    canvas
      ..save()
      ..clipRRect(inner)
      ..drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.5),
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, rect.center, [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ]),
      )
      ..restore();

    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  /// Contour néon net.
  void _paintBorder(Canvas canvas, RRect panel, double scale) {
    canvas.drawRRect(
      panel.deflate(_borderWidth * scale / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth * scale
        ..color = Color.lerp(accentColor, Colors.white, 0.35)!,
    );
  }
}
