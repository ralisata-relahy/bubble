import 'dart:math';
import 'package:flutter/material.dart';

/// Fond spatial statique et responsif (aucune animation, très léger).
/// Utilisation : SpaceBackground(child: VotreJeu())
class SpaceBackground extends StatelessWidget {
  /// Widget placé au-dessus des étoiles.
  final Widget? child;

  /// Nombre d'étoiles par tranche de 10 000 pixels logiques.
  final double density;

  /// Graine : même valeur = même ciel.
  final int seed;

  /// Étoiles supplémentaires près du bas (0 = aucune, à utiliser avec modération).
  final int groundStars;

  const SpaceBackground({
    super.key,
    this.child,
    this.density = 1.2,
    this.seed = 42,
    this.groundStars = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // RepaintBoundary : le ciel n'est pas redessiné quand le jeu bouge.
        RepaintBoundary(
          child: CustomPaint(
            painter: _SpacePainter(
              density: density,
              seed: seed,
              groundStars: groundStars,
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}

/// Stores one star in normalized coordinates for a responsive background.
class _Star {
  final double x; // 0..1 (position relative)
  final double y; // 0..1
  final double size; // 0..1 (taille relative)
  final Color color;

  _Star(this.x, this.y, this.size, this.color);
}

/// Génère [count] étoiles bien réparties (grille avec décalage aléatoire).
/// [yMin]..[yMax] limitent la zone verticale (0 = haut, 1 = bas).
List<_Star> _generateStars(
  Random rng,
  int count,
  Size size, {
  double yMin = 0,
  double yMax = 1,
}) {
  if (count <= 0) return [];

  const tints = [
    Colors.white,
    Color(0xFFCFE3FF), // bleutée
    Color(0xFFFFF2D6), // chaude
  ];

  final bandHeight = yMax - yMin;
  final aspect = size.width / (size.height * bandHeight);

  final cols = max(1, sqrt(count * aspect).ceil());
  final rows = max(1, (count / cols).ceil());
  final cellW = 1 / cols;
  final cellH = bandHeight / rows;

  final result = <_Star>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final x = (c + 0.2 + rng.nextDouble() * 0.6) * cellW;
      final y = yMin + (r + 0.2 + rng.nextDouble() * 0.6) * cellH;
      result.add(_Star(
        x,
        y,
        pow(rng.nextDouble(), 3).toDouble(), // surtout petites, peu de grandes
        tints[rng.nextInt(tints.length)],
      ));
    }
  }
  return result;
}

/// Paints the seeded star field once behind the live game surface.
class _SpacePainter extends CustomPainter {
  final double density;
  final int seed;
  final int groundStars;

  _SpacePainter({
    required this.density,
    required this.seed,
    required this.groundStars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dégradé de fond.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 10, 15, 51),
            Color.fromARGB(255, 12, 19, 53),
            Color.fromARGB(255, 19, 29, 83),
          ],
        ).createShader(rect),
    );

    // Nombre d'étoiles selon la surface de l'écran.
    final count = ((size.width * size.height) / 10000 * density).round();
    final rng = Random(seed);

    final stars = [
      ..._generateStars(rng, count, size),
      ..._generateStars(rng, groundStars, size, yMin: 0.85, yMax: 1.0),
    ];

    // Taille relative au plus petit côté -> s'adapte à tous les écrans.
    final unit = min(size.width, size.height);
    final paint = Paint();

    for (final s in stars) {
      final radius = unit * (0.0007 + s.size * 0.0028);
      final center = Offset(s.x * size.width, s.y * size.height);

      paint.color = s.color.withValues(alpha: 0.85);
      canvas.drawCircle(center, radius, paint);

      // Léger halo pour les plus grandes étoiles.
      if (s.size > 0.5) {
        paint.color = s.color.withValues(alpha: 0.12);
        canvas.drawCircle(center, radius * 3.5, paint);
      }
    }
  }

  // Redessine seulement si les paramètres changent (la taille déclenche
  // automatiquement un nouveau paint).
  @override
  bool shouldRepaint(covariant _SpacePainter old) =>
      old.density != density ||
      old.seed != seed ||
      old.groundStars != groundStars;
}
