import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:bubble/features/bubble/presentation/rendering/bubble_text_helper.dart';

class BubbleLabel extends PositionComponent {
  BubbleLabel({
    required this._text,
    required this.box,      // available text box
    required this.textCenter,   // center of this box, in bubble coordinates
    required this.style,
    this.maxLines = 3,
    this.autoFit = true,
    this.widthFactor = 0.7,
    this.heightFactor = 0.6,
    this.deform,
  })  : super(anchor: Anchor.center, position: Vector2(textCenter.dx, textCenter.dy));

  final Size box;
  final Offset textCenter;
  final TextStyle style;
  final int maxLines;
  final bool autoFit; // reduces font to fit inside the bubble
  final double widthFactor;
  final double heightFactor;
  final void Function(Canvas, void Function(Canvas))? deform;

  String _text;
  TextPainter? _tp;

  String get text => _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _layout();
  }

  @override
  Future<void> onLoad() async => _layout();

  void _layout() {
    _tp?.dispose();
    if (_text.isEmpty) {
      _tp = null;
      return;
    }

    _tp = BubbleTextHelper.createTextPainter(
      text: _text,
      style: style,
      box: box,
      maxLines: maxLines,
      autoFit: autoFit,
      widthFactor: widthFactor,
      heightFactor: heightFactor,
    );
  }

  @override
  void render(Canvas canvas) {
    final tp = _tp;
    if (tp == null) return;

    void draw(Canvas c) =>
        tp.paint(c, Offset(textCenter.dx - tp.width / 2, textCenter.dy - tp.height / 2));

    final d = deform;
    if (d == null) {
      draw(canvas);
    } else {
      // Switch back to bubble coordinates before deforming
      canvas.save();
      canvas.translate(-position.x, -position.y);
      d(canvas, draw);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    _tp?.dispose();
    super.onRemove();
  }
}
