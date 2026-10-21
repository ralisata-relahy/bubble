import 'dart:ui';

/// Shape of the bubble.
enum BubbleShape { sphere, ellipsoid, cube }

/// An arc highlight (luminous border along the edge).
class ArcStyle {
  const ArcStyle({
    required this.color,
    required this.startAngle,
    required this.sweep,
    required this.radiusFactor,
    required this.width,
    this.blur = 0,
    this.visible = true,
  });

  final Color color;
  final double startAngle; // radians (0 = right, pi/2 = bottom, pi = left)
  final double sweep;      // length in radians
  final double radiusFactor; // fraction of radius (0.93 = near edge)
  final double width;      // fraction of radius
  final double blur;
  final bool visible;

  ArcStyle copyWith({
    Color? color,
    double? startAngle,
    double? sweep,
    double? radiusFactor,
    double? width,
    double? blur,
    bool? visible,
  }) =>
      ArcStyle(
        color: color ?? this.color,
        startAngle: startAngle ?? this.startAngle,
        sweep: sweep ?? this.sweep,
        radiusFactor: radiusFactor ?? this.radiusFactor,
        width: width ?? this.width,
        blur: blur ?? this.blur,
        visible: visible ?? this.visible,
      );
}

/// An oval or circular highlight (spots of light).
class SpotStyle {
  const SpotStyle({
    required this.color,
    required this.offset,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.blur = 0,
    this.visible = true,
  });

  final Color color;
  final Offset offset;   // offset from center, as fraction of radius
  final double width;    // fraction of radius
  final double height;   // fraction of radius
  final double rotation; // radians
  final double blur;
  final bool visible;

  SpotStyle copyWith({
    Color? color,
    Offset? offset,
    double? width,
    double? height,
    double? rotation,
    double? blur,
    bool? visible,
  }) =>
      SpotStyle(
        color: color ?? this.color,
        offset: offset ?? this.offset,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        blur: blur ?? this.blur,
        visible: visible ?? this.visible,
      );
}

/// Complete style of a bubble. All values have defaults.
class BubbleStyle {
  const BubbleStyle({
    // Shape
    this.shape = BubbleShape.sphere,
    this.size = const Size(120, 120),
    this.spin = const Offset(0.5, 0.8),            // cube: rad/s around X and Y
    this.initialRotation = const Offset(0.40, -0.55), // cube: initial angle
    this.iridescence = 0.35,
    // Body
    this.baseColor = const Color(0xFFFFFFFF),
    this.bodyCenterAlpha = 0.20,
    this.bodyMidAlpha = 0.001,
    this.bodyEdgeAlpha = 0.40,
    this.bodyStops = const [0.1, 0.75, 1.0],
    this.radius = 60,
    // Rim
    this.rimColor,
    this.rimAlpha = 0.5,
    this.rimWidth = 0.01,
    this.rimRadiusFactor = 0.9825,
    // Crescent
    this.crescentColor,
    this.crescentVisible = true,
    this.crescentAlphas = const [1.0, 0.6, 0.0],
    this.crescentStops = const [0.0, 0.5, 0.85],
    this.crescentOffset = const Offset(0.06, 0.16),
    this.crescentOuterFactor = 0.96,
    this.crescentInnerFactor = 0.98,
    this.crescentBlur = 1.5,
    // Highlights
    this.sideReflection = const ArcStyle(
      color: Color(0x59FFFFFF),
      startAngle: 3.0,
      sweep: 0.9,
      radiusFactor: 0.88,
      width: 0.035,
      blur: 2,
    ),
    this.rightGlint = const ArcStyle(
      color: Color(0xE6FFFFFF),
      startAngle: -0.35,
      sweep: 0.9,
      radiusFactor: 0.93,
      width: 0.05,
      blur: 3,
    ),
    this.bottomShade = const ArcStyle(
      color: Color(0xE6DCEBFF),
      startAngle: 0.5,
      sweep: 1.5,
      radiusFactor: 0.96,
      width: 0.04,
      blur: 3,
    ),
    this.mainHighlight = const SpotStyle(
      color: Color(0xF2FFFFFF),
      offset: Offset(-0.40, -0.45),
      width: 0.5,
      height: 0.2,
      rotation: -0.7,
      blur: 0.5,
    ),
    this.dot = const SpotStyle(
      color: Color(0xBFFFFFFF),
      offset: Offset(0.5, 0.45),
      width: 0.16,
      height: 0.16,
    ),
  });

  // Shape
  final BubbleShape shape;
  final Size size;
  final Offset spin;
  final Offset initialRotation;
  final double iridescence;

  // Body
  final Color baseColor;
  final double bodyCenterAlpha;
  final double bodyMidAlpha;
  final double bodyEdgeAlpha;
  final List<double> bodyStops;
  final double radius;
  // Rim (rimColor == null -> baseColor)
  final Color? rimColor;
  final double rimAlpha;
  final double rimWidth;
  final double rimRadiusFactor;

  // Crescent (crescentColor == null -> baseColor)
  final Color? crescentColor;
  final bool crescentVisible;
  final List<double> crescentAlphas;
  final List<double> crescentStops;
  final Offset crescentOffset;
  final double crescentOuterFactor;
  final double crescentInnerFactor;
  final double crescentBlur;

  // Highlights
  final ArcStyle sideReflection;
  final ArcStyle rightGlint;
  final ArcStyle bottomShade;
  final SpotStyle mainHighlight;
  final SpotStyle dot;

  /// Quick tint: changes base color AND white highlights.
  BubbleStyle tinted(Color color) => copyWith(
        baseColor: color,
        sideReflection: sideReflection.copyWith(color: color.withValues(alpha: 0.35)),
        rightGlint: rightGlint.copyWith(color: color.withValues(alpha: 0.9)),
        mainHighlight: mainHighlight.copyWith(color: color.withValues(alpha: 0.95)),
        dot: dot.copyWith(color: color.withValues(alpha: 0.75)),
      );

  BubbleStyle copyWith({
    BubbleShape? shape,
    Size? size,
    Offset? spin,
    Offset? initialRotation,
    double? iridescence,
    double? boxCornerRadius,
    Offset? ellipseScale,
    Color? baseColor,
    double? bodyCenterAlpha,
    double? bodyMidAlpha,
    double? bodyEdgeAlpha,
    List<double>? bodyStops,
    double? radius,
    Color? rimColor,
    double? rimAlpha,
    double? rimWidth,
    double? rimRadiusFactor,
    Color? crescentColor,
    bool? crescentVisible,
    List<double>? crescentAlphas,
    List<double>? crescentStops,
    Offset? crescentOffset,
    double? crescentOuterFactor,
    double? crescentInnerFactor,
    double? crescentBlur,
    ArcStyle? sideReflection,
    ArcStyle? rightGlint,
    ArcStyle? bottomShade,
    SpotStyle? mainHighlight,
    SpotStyle? dot,
  }) =>
      BubbleStyle(
        shape: shape ?? this.shape,
        size: size ?? this.size,
        spin: spin ?? this.spin,
        initialRotation: initialRotation ?? this.initialRotation,
        iridescence: iridescence ?? this.iridescence,
        baseColor: baseColor ?? this.baseColor,
        bodyCenterAlpha: bodyCenterAlpha ?? this.bodyCenterAlpha,
        bodyMidAlpha: bodyMidAlpha ?? this.bodyMidAlpha,
        bodyEdgeAlpha: bodyEdgeAlpha ?? this.bodyEdgeAlpha,
        radius: radius ?? this.radius,
        bodyStops: bodyStops ?? this.bodyStops,
        rimColor: rimColor ?? this.rimColor,
        rimAlpha: rimAlpha ?? this.rimAlpha,
        rimWidth: rimWidth ?? this.rimWidth,
        rimRadiusFactor: rimRadiusFactor ?? this.rimRadiusFactor,
        crescentColor: crescentColor ?? this.crescentColor,
        crescentVisible: crescentVisible ?? this.crescentVisible,
        crescentAlphas: crescentAlphas ?? this.crescentAlphas,
        crescentStops: crescentStops ?? this.crescentStops,
        crescentOffset: crescentOffset ?? this.crescentOffset,
        crescentOuterFactor: crescentOuterFactor ?? this.crescentOuterFactor,
        crescentInnerFactor: crescentInnerFactor ?? this.crescentInnerFactor,
        crescentBlur: crescentBlur ?? this.crescentBlur,
        sideReflection: sideReflection ?? this.sideReflection,
        rightGlint: rightGlint ?? this.rightGlint,
        bottomShade: bottomShade ?? this.bottomShade,
        mainHighlight: mainHighlight ?? this.mainHighlight,
        dot: dot ?? this.dot,
      );
}