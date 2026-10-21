import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../rendering/bubble_renderer.dart';
import '../rendering/bubble_text_helper.dart';
import '../../models/bubble_style.dart';

// A reusable bubble (Sphere, Ellipsoid, or 3D Cube) for standard UI
class BubbleWidgetText extends StatefulWidget {
  const BubbleWidgetText({
    super.key,
    this.text = '',
    this.phonetic,
    this.textColor = Colors.white,
    this.phoneticColor,
    this.style = const BubbleStyle(),
    this.maxLines = 3,
    this.autoFit = true,

    // StyledChip parity
    this.dimmed = false,
    this.dimmedOpacity = 0.4,
    this.popDelay = Duration.zero,
    this.popEnabled = false,
    this.popDuration = const Duration(milliseconds: 500),
    this.floatEnabled = false,
    this.floatDistance = 5,
    this.floatDuration = const Duration(milliseconds: 3400),

    // Sizing
    this.autoSize = false,
    this.fontSize,
    this.horizontalPadding,
    this.verticalPadding,

    // Icon support
    this.icon,
    this.iconData,
    this.iconAsset,
    this.iconColor,
    this.iconSize,
    this.clipIconToCircle = true,
    this.bubbleSize,
    this.onTap,
  });

  final String text;

  final String? phonetic;
  final Color textColor;

  final Color? phoneticColor;
  final BubbleStyle style;
  final int maxLines;
  final bool autoFit;

  final bool dimmed;
  final double dimmedOpacity;

  final Duration popDelay;

  final bool popEnabled;
  final Duration popDuration;

  final bool floatEnabled;
  final double floatDistance;
  final Duration floatDuration;

  final bool autoSize;

  final double? fontSize;

  final double? horizontalPadding;
  final double? verticalPadding;

  // ICON MODE
  final Widget? icon;

  // A Material icon
  final IconData? iconData;

  // An asset image path
  final String? iconAsset;

  // Color of iconData
  final Color? iconColor;

  // Size of the icon
  final double? iconSize;

  final bool clipIconToCircle;

  // Forces a square bubble of this size
  final double? bubbleSize;

  // Tap callback for the whole bubble.
  final VoidCallback? onTap;

  bool get hasIcon => icon != null || iconData != null || iconAsset != null;

  @override
  State<BubbleWidgetText> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidgetText>
    with TickerProviderStateMixin {
  AnimationController? _floatController;
  Animation<double>? _float;
  AnimationController? _popController;
  Animation<double>? _popScale;
  Animation<double>? _popOpacity;

  @override
  void initState() {
    super.initState();
    if (widget.floatEnabled) _setupFloat();
    if (widget.popEnabled) _setupPop();
  }

  void _setupFloat() {
    _floatController = AnimationController(
      vsync: this,
      duration: widget.floatDuration,
    )..repeat(reverse: true);

    _float = Tween<double>(begin: 0, end: -widget.floatDistance).animate(
      CurvedAnimation(parent: _floatController!, curve: Curves.easeInOut),
    );
  }

  void _setupPop() {
    _popController = AnimationController(
      vsync: this,
      duration: widget.popDuration,
    );

    _popScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.15), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _popController!, curve: Curves.easeOut));

    _popOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _popController!,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    Future.delayed(widget.popDelay, () {
      if (mounted) _popController?.forward();
    });
  }

  @override
  void didUpdateWidget(covariant BubbleWidgetText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.floatEnabled != oldWidget.floatEnabled) {
      if (widget.floatEnabled) {
        _setupFloat();
      } else {
        _floatController?.dispose();
        _floatController = null;
        _float = null;
      }
    }
  }

  @override
  void dispose() {
    _floatController?.dispose();
    _popController?.dispose();
    super.dispose();
  }

  double _resolvedFontSize(BuildContext context) {
    if (widget.fontSize != null) return widget.fontSize!;
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.05).clamp(16.0, 22.0);
  }

  Size _measure(BuildContext context, double fontSize) {
    final mq = MediaQuery.sizeOf(context);
    final hPad =
        widget.horizontalPadding ?? (mq.width * 0.035).clamp(10.0, 15.0);
    final vPad =
        widget.verticalPadding ?? (mq.height * 0.008).clamp(10.0, 10.0);

    // Icon mode: square bubble around the icon.
    if (widget.hasIcon) {
      final iconExtent = widget.iconSize ?? fontSize * 1.6;
      final side = iconExtent + max(hPad, vPad) * 2;
      return Size(side, side);
    }

    final mainTp = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: GoogleFonts.quicksand(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    double width = mainTp.width;
    double height = mainTp.height;
    mainTp.dispose();

    final hasPhonetic = widget.phonetic != null && widget.phonetic!.isNotEmpty;
    if (hasPhonetic) {
      final phonTp = TextPainter(
        text: TextSpan(
          text: widget.phonetic,
          style: GoogleFonts.quicksand(
            fontSize: fontSize * 0.65,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      width = max(width, phonTp.width);
      height += phonTp.height + fontSize * 0.15;
      phonTp.dispose();
    }

    return Size(width + hPad * 2, height + vPad * 2);
  }

  Widget? _buildIcon(Size bubble) {
    if (!widget.hasIcon) return null;

    final extent = widget.iconSize ?? bubble.shortestSide * 0.5;

    if (widget.icon != null) return widget.icon;

    if (widget.iconAsset != null) {
      final image = Image.asset(
        widget.iconAsset!,
        width: extent,
        height: extent,
        fit: BoxFit.cover,
      );
      return widget.clipIconToCircle ? ClipOval(child: image) : image;
    }

    return Icon(
      widget.iconData,
      size: extent,
      color: widget.iconColor ?? widget.textColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasIcon = widget.hasIcon;
    final hasFontSize = widget.autoSize || widget.fontSize != null;
    final fontSize = hasFontSize ? _resolvedFontSize(context) : null;

    BubbleStyle effectiveStyle = widget.style;
    if (widget.bubbleSize != null) {
      effectiveStyle = widget.style.copyWith(
        size: Size(widget.bubbleSize!, widget.bubbleSize!),
      );
    } else if (widget.autoSize) {
      effectiveStyle = widget.style.copyWith(
        size: _measure(context, fontSize ?? _resolvedFontSize(context)),
      );
    }

    final bubbleBox = effectiveStyle.size;
    final iconWidget = _buildIcon(bubbleBox);

    Widget bubble = SizedBox(
      width: bubbleBox.width,
      height: bubbleBox.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BubblePainter(
                style: effectiveStyle,
                // In icon mode the text is not painted.
                text: hasIcon ? '' : widget.text,
                phonetic: hasIcon ? null : widget.phonetic,
                textColor: widget.textColor,
                phoneticColor: widget.phoneticColor ?? widget.textColor,
                maxLines: widget.maxLines,
                autoFit: widget.autoFit,
                fontSize: fontSize,
              ),
            ),
          ),
          if (iconWidget != null) Center(child: iconWidget),
        ],
      ),
    );

    // Tap
    if (widget.onTap != null) {
      bubble = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: bubble,
      );
    }

    // Dimming
    bubble = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: widget.dimmed ? widget.dimmedOpacity : 1.0,
      child: bubble,
    );

    // Float
    if (_float != null) {
      final inner = bubble;
      bubble = AnimatedBuilder(
        animation: _float!,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _float!.value), child: child),
        child: inner,
      );
    }

    // Pop-in
    if (_popController != null) {
      final inner = bubble;
      bubble = AnimatedBuilder(
        animation: _popController!,
        builder: (context, child) => FadeTransition(
          opacity: _popOpacity!,
          child: ScaleTransition(scale: _popScale!, child: child),
        ),
        child: inner,
      );
    }

    return bubble;
  }
}

class BubblePainter extends CustomPainter {
  BubblePainter({
    required this.style,
    required this.text,
    required this.textColor,
    required this.maxLines,
    required this.autoFit,
    this.phonetic,
    this.phoneticColor,
    this.fontSize,
  }) : _renderer = BubbleRenderer(style);

  final BubbleStyle style;
  final String text;
  final String? phonetic;
  final Color textColor;
  final Color? phoneticColor;
  final int maxLines;
  final bool autoFit;

  final double? fontSize;
  final BubbleRenderer _renderer;

  bool get _hasPhonetic => phonetic != null && phonetic!.isNotEmpty;

  @override
  void paint(Canvas canvas, Size size) {
    _renderer.paintBody(canvas);

    if (text.isNotEmpty) {
      final shortest = size.shortestSide;
      final mainFont = fontSize ?? shortest * 0.1;
      final phoneticFont = fontSize != null ? fontSize! * 0.65 : shortest * 0.13;

      final shadows = [
        Shadow(
          color: Colors.black45,
          offset: Offset(0, shortest * 0.015),
          blurRadius: shortest * 0.03,
        ),
      ];

      final mainBox = _hasPhonetic ? Size(size.width, size.height * 0.6) : size;

      final mainPainter = BubbleTextHelper.createTextPainter(
        text: text,
        style: GoogleFonts.quicksand(
          color: textColor,
          fontSize: mainFont,
          fontWeight: FontWeight.bold,
          shadows: shadows,
        ),
        box: mainBox,
        maxLines: _hasPhonetic ? 1 : maxLines,
        autoFit: autoFit,
      );

      TextPainter? phoneticPainter;
      if (_hasPhonetic) {
        phoneticPainter = BubbleTextHelper.createTextPainter(
          text: phonetic!,
          style: GoogleFonts.quicksand(
            color: phoneticColor ?? textColor.withValues(alpha: 0.9),
            fontSize: phoneticFont,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            shadows: shadows,
          ),
          box: Size(size.width, size.height * 0.3),
          maxLines: 1,
          autoFit: autoFit,
        );
      }

      final gap = phoneticPainter != null ? mainFont * 0.15 : 0.0;
      final blockHeight =
          (phoneticPainter?.height ?? 0) + gap + mainPainter.height;
      double y = (size.height - blockHeight) / 2;

      if (phoneticPainter != null) {
        phoneticPainter.paint(
          canvas,
          Offset((size.width - phoneticPainter.width) / 2, y),
        );
        y += phoneticPainter.height + gap;
        phoneticPainter.dispose();
      }

      mainPainter.paint(
        canvas,
        Offset((size.width - mainPainter.width) / 2, y),
      );
      mainPainter.dispose();
    }

    // 3. Paint gloss layer (highlights)
    _renderer.paintGloss(canvas);
  }

  @override
  bool shouldRepaint(covariant BubblePainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.text != text ||
        oldDelegate.phonetic != phonetic ||
        oldDelegate.textColor != textColor ||
        oldDelegate.phoneticColor != phoneticColor ||
        oldDelegate.maxLines != maxLines ||
        oldDelegate.autoFit != autoFit ||
        oldDelegate.fontSize != fontSize;
  }
}