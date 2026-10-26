/// Named expressions supported by Curio's animated painter.
enum Mood {
  happy,
  excited,
  surprised,
  sad,
  angry,
  sleepy,
  love,
  stressed,
  wining,
  satisfied,
  disapointed,
}

// =============================================================================
// ParamÃ¨tres d'humeur
// =============================================================================

/// Indexed parameter keys shared by default values and mood-specific presets.
enum MoodParameter {
  // yeux
  lid, // 0 ouvert .. 1 fermÃ© (paupiÃ¨re au repos)
  lidSlant, // + en colÃ¨re (coins intÃ©rieurs bas), - triste
  eyeScale,
  pupil, // multiplicateur de la pupille
  gazeY, // biais vertical du regard (px)
  // sourcils
  browLift, // px, nÃ©gatif = vers le haut
  browTilt, // degrÃ©s, + colÃ¨re, - tristesse
  // bouche
  mW, // multiplicateur de largeur
  mCorner, // y des coins de la bouche
  mTop, // y du point de contrÃ´le de la lÃ¨vre supÃ©rieure
  mBottom, // y du bas de l'ouverture
  tongue, // 0..1
  tooth, // 0..1
  blush, // multiplicateur des joues
  // oreilles / cÅ“ur
  earDroop, // degrÃ©s, + tombantes, - dressÃ©es
  heartTilt, // degrÃ©s
  heartScale,
  heartPulse, // amplitude du battement
  heartRate, // Hz
  // corps
  breathAmp,
  breathRate, // Hz
  bobAmp, // px
  bobRate, // Hz
  shake, // px (tremblement)
  slump, // 0..~0.05 affaissement
  wagAmp, // degrÃ©s de la queue
  wagRate, // Hz
  // effets (alpha 0..1)
  tear,
  zzz,
  hearts,
  anger,
}

/// Compact immutable values used to interpolate between mood presets.
class MoodParams {
  MoodParams._(this._v);

  final List<double> _v;

  double operator [](MoodParameter k) => _v[k.index];

  factory MoodParams._make(Map<MoodParameter, double> overrides) {
    final m = {..._defaults, ...overrides};
    return MoodParams._([for (final k in MoodParameter.values) m[k]!]);
  }

  /// ParamÃ¨tres d'une humeur donnÃ©e.
  factory MoodParams.of(Mood mood) => _presets[mood]!;

  /// Interpolates every pose parameter for a smooth mood transition.
  static MoodParams lerp(MoodParams a, MoodParams b, double t) {
    return MoodParams._([
      for (var i = 0; i < a._v.length; i++) a._v[i] + (b._v[i] - a._v[i]) * t,
    ]);
  }
}

// "happy" = les valeurs par dÃ©faut.
const Map<MoodParameter, double> _defaults = {
  MoodParameter.lid: 0,
  MoodParameter.lidSlant: 0,
  MoodParameter.eyeScale: 1,
  MoodParameter.pupil: 1,
  MoodParameter.gazeY: 0,
  MoodParameter.browLift: 0,
  MoodParameter.browTilt: 0,
  MoodParameter.mW: 1,
  MoodParameter.mCorner: 360,
  MoodParameter.mTop: 349,
  MoodParameter.mBottom: 415,
  MoodParameter.tongue: 1,
  MoodParameter.tooth: 1,
  MoodParameter.blush: 1,
  MoodParameter.earDroop: 0,
  MoodParameter.heartTilt: -5,
  MoodParameter.heartScale: 1,
  MoodParameter.heartPulse: 0.03,
  MoodParameter.heartRate: 0.9,
  MoodParameter.breathAmp: 0.015,
  MoodParameter.breathRate: 0.45,
  MoodParameter.bobAmp: 0,
  MoodParameter.bobRate: 1,
  MoodParameter.shake: 0,
  MoodParameter.slump: 0,
  MoodParameter.wagAmp: 7,
  MoodParameter.wagRate: 1.1,
  MoodParameter.tear: 0,
  MoodParameter.zzz: 0,
  MoodParameter.hearts: 0,
  MoodParameter.anger: 0,
};

final Map<Mood, MoodParams> _presets = {
  Mood.happy: MoodParams._make({}),
  Mood.excited: MoodParams._make({
    MoodParameter.eyeScale: 1.06,
    MoodParameter.pupil: 1.1,
    MoodParameter.browLift: -8,
    MoodParameter.mW: 1.15,
    MoodParameter.mCorner: 356,
    MoodParameter.mTop: 342,
    MoodParameter.mBottom: 424,
    MoodParameter.blush: 1.3,
    MoodParameter.earDroop: -4,
    MoodParameter.heartScale: 1.05,
    MoodParameter.heartPulse: 0.08,
    MoodParameter.heartRate: 2.2,
    MoodParameter.breathAmp: 0.02,
    MoodParameter.breathRate: 1.2,
    MoodParameter.bobAmp: 16,
    MoodParameter.bobRate: 1.5,
    MoodParameter.wagAmp: 16,
    MoodParameter.wagRate: 3.2,
  }),
  Mood.stressed: MoodParams._make({
    MoodParameter.lid: 0.16,
    MoodParameter.lidSlant: 0.35,
    MoodParameter.pupil: 0.9,
    MoodParameter.browLift: 5,
    MoodParameter.browTilt: 12,
    MoodParameter.mW: 0.9,
    MoodParameter.mCorner: 370,
    MoodParameter.mTop: 350,
    MoodParameter.mBottom: 405,
    MoodParameter.breathAmp: 0.025,
    MoodParameter.breathRate: 1.4,
    MoodParameter.shake: 1.5,
    MoodParameter.wagAmp: 4,
    MoodParameter.wagRate: 0.8,
  }),
  Mood.disapointed: MoodParams._make({
    MoodParameter.lid: 0.18,
    MoodParameter.lidSlant: -0.45,
    MoodParameter.gazeY: 3,
    MoodParameter.browTilt: -12,
    MoodParameter.mW: 0.85,
    MoodParameter.mCorner: 378,
    MoodParameter.mTop: 350,
    MoodParameter.mBottom: 396,
    MoodParameter.tongue: 0,
    MoodParameter.tooth: 0,
    MoodParameter.blush: 0.6,
    MoodParameter.earDroop: 10,
    MoodParameter.breathAmp: 0.014,
    MoodParameter.breathRate: 0.35,
    MoodParameter.slump: 0.02,
    MoodParameter.wagAmp: 2,
    MoodParameter.wagRate: 0.4,
  }),
  Mood.surprised: MoodParams._make({
    MoodParameter.eyeScale: 1.14,
    MoodParameter.pupil: 0.6,
    MoodParameter.browLift: -16,
    MoodParameter.mW: 0.6,
    MoodParameter.mCorner: 374,
    MoodParameter.mTop: 336,
    MoodParameter.mBottom: 432,
    MoodParameter.tongue: 0,
    MoodParameter.tooth: 0,
    MoodParameter.blush: 0.6,
    MoodParameter.earDroop: -7,
    MoodParameter.heartTilt: 0,
    MoodParameter.heartScale: 1.12,
    MoodParameter.heartPulse: 0.05,
    MoodParameter.heartRate: 2.0,
    MoodParameter.breathAmp: 0.01,
    MoodParameter.breathRate: 0.3,
    MoodParameter.shake: 0,
    MoodParameter.wagAmp: 3,
    MoodParameter.wagRate: 0.6,
  }),
  Mood.sad: MoodParams._make({
    MoodParameter.lid: 0.28,
    MoodParameter.lidSlant: -0.7,
    MoodParameter.eyeScale: 0.98,
    MoodParameter.pupil: 1.15,
    MoodParameter.gazeY: 5,
    MoodParameter.browLift: 4,
    MoodParameter.browTilt: -20,
    MoodParameter.mW: 0.8,
    MoodParameter.mCorner: 384,
    MoodParameter.mTop: 346,
    MoodParameter.mBottom: 390,
    MoodParameter.tongue: 0,
    MoodParameter.tooth: 0,
    MoodParameter.blush: 0.5,
    MoodParameter.earDroop: 20,
    MoodParameter.heartTilt: -22,
    MoodParameter.heartScale: 0.92,
    MoodParameter.heartPulse: 0.015,
    MoodParameter.heartRate: 0.6,
    MoodParameter.breathAmp: 0.012,
    MoodParameter.breathRate: 0.3,
    MoodParameter.slump: 0.035,
    MoodParameter.wagAmp: 2,
    MoodParameter.wagRate: 0.4,
    MoodParameter.tear: 1,
  }),
  Mood.angry: MoodParams._make({
    MoodParameter.lid: 0.22,
    MoodParameter.lidSlant: 0.95,
    MoodParameter.pupil: 0.8,
    MoodParameter.browLift: 8,
    MoodParameter.browTilt: 24,
    MoodParameter.mW: 1.1,
    MoodParameter.mCorner: 374,
    MoodParameter.mTop: 352,
    MoodParameter.mBottom: 402,
    MoodParameter.tongue: 0,
    MoodParameter.blush: 0.3,
    MoodParameter.earDroop: -5,
    MoodParameter.heartPulse: 0.07,
    MoodParameter.heartRate: 2.8,
    MoodParameter.breathAmp: 0.022,
    MoodParameter.breathRate: 1.0,
    MoodParameter.shake: 0,
    MoodParameter.wagAmp: 12,
    MoodParameter.wagRate: 5.5,
    MoodParameter.anger: 1,
  }),
  Mood.sleepy: MoodParams._make({
    MoodParameter.lid: 0.88,
    MoodParameter.mW: 0.55,
    MoodParameter.mCorner: 372,
    MoodParameter.mTop: 366,
    MoodParameter.mBottom: 392,
    MoodParameter.tongue: 0,
    MoodParameter.tooth: 0,
    MoodParameter.blush: 0.8,
    MoodParameter.earDroop: 10,
    MoodParameter.heartTilt: -16,
    MoodParameter.heartScale: 0.94,
    MoodParameter.heartPulse: 0.02,
    MoodParameter.heartRate: 0.35,
    MoodParameter.breathAmp: 0.028,
    MoodParameter.breathRate: 0.25,
    MoodParameter.slump: 0.02,
    MoodParameter.wagAmp: 1.5,
    MoodParameter.wagRate: 0.3,
    MoodParameter.zzz: 1,
  }),
  Mood.love: MoodParams._make({
    MoodParameter.lid: 0.1,
    MoodParameter.eyeScale: 1.06,
    MoodParameter.pupil: 1.25,
    MoodParameter.browLift: -4,
    MoodParameter.browTilt: -6,
    MoodParameter.mW: 0.9,
    MoodParameter.mCorner: 358,
    MoodParameter.mTop: 352,
    MoodParameter.mBottom: 406,
    MoodParameter.tongue: 0.6,
    MoodParameter.tooth: 0,
    MoodParameter.blush: 2.3,
    MoodParameter.earDroop: -2,
    MoodParameter.heartScale: 1.1,
    MoodParameter.heartPulse: 0.14,
    MoodParameter.heartRate: 1.5,
    MoodParameter.breathAmp: 0.02,
    MoodParameter.breathRate: 0.7,
    MoodParameter.bobAmp: 6,
    MoodParameter.bobRate: 0.75,
    MoodParameter.wagAmp: 12,
    MoodParameter.wagRate: 2.2,
    MoodParameter.hearts: 1,
  }),
  Mood.wining: MoodParams._make({
    MoodParameter.eyeScale: 1.08,
    MoodParameter.pupil: 1.1,
    MoodParameter.browLift: -10,
    MoodParameter.mW: 1.15,
    MoodParameter.mCorner: 354,
    MoodParameter.mTop: 340,
    MoodParameter.mBottom: 426,
    MoodParameter.blush: 1.4,
    MoodParameter.earDroop: -5,
    MoodParameter.heartScale: 1.08,
    MoodParameter.heartPulse: 0.12,
    MoodParameter.heartRate: 2.5,
    MoodParameter.breathAmp: 0.022,
    MoodParameter.breathRate: 1.2,
    MoodParameter.bobAmp: 18,
    MoodParameter.bobRate: 1.6,
    MoodParameter.wagAmp: 18,
    MoodParameter.wagRate: 3.5,
  }),
  Mood.satisfied: MoodParams._make({
    MoodParameter.lid: 0.12,
    MoodParameter.mW: 0.9,
    MoodParameter.mCorner: 356,
    MoodParameter.mTop: 352,
    MoodParameter.mBottom: 406,
    MoodParameter.blush: 1.1,
    MoodParameter.heartPulse: 0.04,
    MoodParameter.heartRate: 0.6,
    MoodParameter.breathAmp: 0.012,
    MoodParameter.breathRate: 0.35,
    MoodParameter.wagAmp: 4,
    MoodParameter.wagRate: 0.6,
  }),
};
