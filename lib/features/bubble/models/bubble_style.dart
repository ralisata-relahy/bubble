import 'dart:ui';

/// Forme geometrique de la bulle supportee par le moteur de rendu.
enum BubbleShape {
  /// Bulle parfaitement ronde.
  sphere,

  /// Bulle etiree ou aplatie selon ses dimensions de boite.
  ellipsoid,
}

/// Definition visuelle d'un reflet en arc de cercle le long du bord de la bulle.
class ArcStyle {
  /// Cree un style de reflet en arc.
  const ArcStyle({
    required this.color,
    required this.startAngle,
    required this.sweep,
    required this.radiusFactor,
    required this.width,
    this.blur = 0,
    this.visible = true,
  });

  /// Couleur principale de l'arc de reflet.
  final Color color;

  /// Angle de debut en radians (0 = droite, pi/2 = bas, pi = gauche).
  final double startAngle;

  /// Longueur angulaire de l'arc en radians.
  final double sweep;

  /// Rayon relatif par rapport au rayon total de la bulle (0.93 = proche du bord).
  final double radiusFactor;

  /// Epaisseur relative du trait par rapport au rayon de la bulle.
  final double width;

  /// Flou applique a l'arc pour adoucir la lumiere.
  final double blur;

  /// Indique si ce reflet doit etre rendu.
  final bool visible;

  /// Cree une copie de ce style avec les parametres modifies.
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

/// Definition visuelle d'un point lumineux ou halo elliptique.
class SpotStyle {
  /// Cree un style de point lumineux.
  const SpotStyle({
    required this.color,
    required this.offset,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.blur = 0,
    this.visible = true,
  });

  /// Couleur du reflet lumineux.
  final Color color;

  /// Decalage par rapport au centre, exprime en fraction du rayon.
  final Offset offset;

  /// Largeur relative du spot.
  final double width;

  /// Hauteur relative du spot.
  final double height;

  /// Rotation angulaire en radians.
  final double rotation;

  /// Rayon de flou pour adoucir les contours.
  final double blur;

  /// Indique si ce point lumineux est actif.
  final bool visible;

  /// Cree une copie modifiee de ce style de spot.
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

/// Configuration esthetique complete d'une bulle.
/// Toutes les proprietes disposent de valeurs par defaut realistes.
class BubbleStyle {
  /// Construit un profil de style complet pour une bulle.
  const BubbleStyle({
    // Forme et dimensions
    this.shape = BubbleShape.sphere,
    this.size = const Size(120, 120),
    this.iridescence = 0.35,

    // Corps de la bulle
    this.baseColor = const Color(0xFFFFFFFF),
    this.bodyCenterAlpha = 0.20,
    this.bodyMidAlpha = 0.001,
    this.bodyEdgeAlpha = 0.40,
    this.bodyStops = const [0.1, 0.75, 1.0],
    this.radius = 60,

    // Anneau de bordure
    this.rimColor,
    this.rimAlpha = 0.5,
    this.rimWidth = 0.01,
    this.rimRadiusFactor = 0.9825,

    // Croissant d'ombre / lueur
    this.crescentColor,
    this.crescentVisible = true,
    this.crescentAlphas = const [1.0, 0.6, 0.0],
    this.crescentStops = const [0.0, 0.5, 0.85],
    this.crescentOffset = const Offset(0.06, 0.16),
    this.crescentOuterFactor = 0.96,
    this.crescentInnerFactor = 0.98,
    this.crescentBlur = 1.5,

    // Reflets lumineux et ombres portees
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

  /// Forme de base de la bulle.
  final BubbleShape shape;

  /// Dimensions du rectangle englobant de la bulle.
  final Size size;

  /// Taux d'iridescence applique au reflet.
  final double iridescence;

  /// Couleur de fond de la bulle.
  final Color baseColor;

  /// Opacite au centre du degrade spherique.
  final double bodyCenterAlpha;

  /// Opacite intermediaire du degrade spherique.
  final double bodyMidAlpha;

  /// Opacite au niveau du contour externe du degrade.
  final double bodyEdgeAlpha;

  /// Positions relatives des paliers de couleur du degrade de corps.
  final List<double> bodyStops;

  /// Rayon de reference en pixels.
  final double radius;

  /// Couleur de l'anneau externe (utilise baseColor si non specifie).
  final Color? rimColor;

  /// Opacite de l'anneau externe.
  final double rimAlpha;

  /// Epaisseur de l'anneau externe en fraction du rayon.
  final double rimWidth;

  /// Facteur de placement radial de l'anneau externe.
  final double rimRadiusFactor;

  /// Couleur du croissant (utilise baseColor si non specifie).
  final Color? crescentColor;

  /// Visibilite du croissant interne.
  final bool crescentVisible;

  /// Paliers d'opacite pour le degrade du croissant.
  final List<double> crescentAlphas;

  /// Paliers de positionnement pour le degrade du croissant.
  final List<double> crescentStops;

  /// Decalage spatial du centre du croissant.
  final Offset crescentOffset;

  /// Rayon externe relatif du croissant.
  final double crescentOuterFactor;

  /// Rayon interne relatif du croissant.
  final double crescentInnerFactor;

  /// Rayon de flou du croissant.
  final double crescentBlur;

  /// Reflet lateral de la bulle.
  final ArcStyle sideReflection;

  /// Eclat lumineux lateral droit.
  final ArcStyle rightGlint;

  /// Ombrage doux en bas de la bulle.
  final ArcStyle bottomShade;

  /// Tache de lumiere principale du dessus.
  final SpotStyle mainHighlight;

  /// Point secondaire de lumiere oppose.
  final SpotStyle dot;

  /// Teinte rapidement la bulle ainsi que ses reflets principaux.
  BubbleStyle tinted(Color color) => copyWith(
        baseColor: color,
        sideReflection:
            sideReflection.copyWith(color: color.withValues(alpha: 0.35)),
        rightGlint: rightGlint.copyWith(color: color.withValues(alpha: 0.9)),
        mainHighlight:
            mainHighlight.copyWith(color: color.withValues(alpha: 0.95)),
        dot: dot.copyWith(color: color.withValues(alpha: 0.75)),
      );

  /// Genere une copie immutabilisee avec les champs fournis modifies.
  BubbleStyle copyWith({
    BubbleShape? shape,
    Size? size,
    double? iridescence,
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