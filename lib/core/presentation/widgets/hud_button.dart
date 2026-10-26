import 'package:flutter/material.dart';

/// Bouton neon "verre" : pilule brillante, contour lumineux, reflet glossy,
/// avec pulsation continue pour inviter le joueur a toucher.
class HudButton extends StatefulWidget {
  const HudButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = const Color.fromARGB(255, 198, 255, 43),
    this.secondaryColor = const Color.fromARGB(255, 158, 146, 10),
    this.iconColor = Colors.white,
    this.alignment=Alignment.bottomLeft,
    this.scale = 0.6,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Alignment alignment;
  final double scale;
  /// Couleur neon principale (contour, halo, haut du degrade).
  final Color color;

  /// Teinte profonde du bas du degrade.
  final Color secondaryColor;

  /// Couleur de l'icone.
  final Color iconColor;

  @override
  State<HudButton> createState() => _HudButtonState();
}

/// Owns the repeating highlight animation and pressed visual state.
class _HudButtonState extends State<HudButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeInOut,
  );

  bool _pressed = false;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final borderColor = Color.lerp(color, Colors.white, 0.45)!;

    return Transform.scale(
      scale: widget.scale,
      alignment: widget.alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final p = _pulse.value;
              final glow = (0.45 + 0.40 * p) + (_pressed ? 0.15 : 0.0);

              return Transform.scale(
                scale: 1.0 + 0.04 * p,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: borderColor, width: 2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, widget.secondaryColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: glow.clamp(0.0, 1.0)),
                        blurRadius: 14 + 12 * p,
                        spreadRadius: 1 + 2 * p,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(38),
                    child: Stack(
                      children: [
                        // Contenu : texte + icone.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.label.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Transform.translate(
                                offset: Offset(4 * p, 0),
                                child: Icon(
                                  widget.icon,
                                  color: widget.iconColor,
                                  size: 26,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reflet glossy : bande claire sur la moitie haute.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 22,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.38),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Petit reflet brillant en haut a gauche.
                        Positioned(
                          left: 14,
                          top: 5,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: -0.35,
                              child: Container(
                                width: 16,
                                height: 7,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
