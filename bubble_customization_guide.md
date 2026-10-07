# Bubble Engine & Customization Guide

Welcome to the **Bubble Engine** architecture and customization guide. This document explains how the bubble simulation, rendering pipeline, laser interaction, and Flutter widget integration work, along with a detailed tutorial on how to customize bubbles to fit your design system.

---

## Architecture Overview

The project is structured following **Clean Architecture** and **Clean Code** principles:

```
lib/
├── components/
│   ├── bubble/
│   │   ├── render/         # Pure rendering logic (Sphere, Cube, Text helper)
│   │   ├── ui/             # Standalone Flutter widgets (BubbleWidget)
│   │   ├── bubble.dart     # Flame component implementing LaserTarget
│   │   ├── bubble_config.dart
│   │   ├── bubble_label.dart
│   │   └── bubble_style.dart
│   └── lazer/              # Interactive Laser Beam component
├── domain/
│   └── laser_target.dart   # Domain interface for raycast targets
└── game/
    └── bubble_game.dart    # Main FlameGame loop and event handling
```

---

## How It Works

1. **Rendering Pipeline (`BubbleRenderer`)**:
   - Depending on the `BubbleShape` (`sphere`, `ellipsoid`, or `cube`), `BubbleRenderer` delegates drawing to `SphereRenderer` or `CubeRenderer`.
   - **Spheres / Ellipsoids (2.5D)**: Uses radial gradients simulating Fresnel reflections, caustic lighting, iridescent interference films, and studio-style glass highlights.
   - **3D Cubes**: Renders a true 3D perspective cube with per-face lighting, depth sorting, rounded corner polygons, and smooth reflections.

2. **Physics & Simulation (`Bubble`)**:
   - Bubbles drift along configured directional vectors with sinusoidal wave oscillations (`_drift`).
   - They feature continuous "breathing" squash & stretch deformation (`_breathe`).
   - Screen-wrapping respawn ensures bubbles continuously loop across the viewport.

3. **Laser Interaction (`LaserBeam` & `LaserTarget`)**:
   - The user can drag anywhere on the screen to aim the laser ray.
   - The ray performs a precise raycast against any `LaserTarget` (such as `Bubble` components).
   - Upon contact, the bubble triggers a smooth pop animation (expanding shockwave ring with fading opacity) before being removed from the game.

4. **Dual Reusability (`Bubble` vs `BubbleWidget`)**:
   - **Flame Game**: Use `Bubble` inside `BubbleGame` for full physics, floating, and laser interaction.
   - **Standard Flutter UI**: Use `BubbleWidget` (`CustomPaint`) anywhere in standard Flutter widget trees (posters, cards, banners) without needing Flame.

---

## Customization Tutorial

Bubbles are fully customizable through [BubbleStyle](file:///C:/Users/NEKENA/bubble/lib/components/bubble/bubble_style.dart) and [BubbleConfig](file:///C:/Users/NEKENA/bubble/lib/components/bubble/bubble_config.dart).

### 1. Basic Customization (Config & Style)

When spawning or displaying a bubble, you can customize its shape, size, speed, direction, text, and base color:

```dart
final customConfig = BubbleConfig(
  text: 'Score: 100',
  speed: 35.0,
  direction: BubbleDirection.leftToRight,
  waveAmplitude: 8.0,
  waveFrequency: 1.2,
  breathAmplitude: 0.05,
  style: BubbleStyle(
    shape: BubbleShape.sphere,
    size: Size(150, 150),
    baseColor: Colors.pinkAccent,
    iridescence: 0.5, // Strength of the oil-film rainbow effect
  ),
);
```

### 2. Available Bubble Shapes

You can choose between three built-in shapes:
- `BubbleShape.sphere`: Classic circular glass bubble.
- `BubbleShape.ellipsoid`: Oval-shaped glass bubble.
- `BubbleShape.cube`: 3D rotating glass cube with rounded corners.

### 3. Advanced Style Properties (`BubbleStyle`)

You can fine-tune every visual aspect of the glass material:

| Property | Type | Description |
| :--- | :--- | :--- |
| `shape` | `BubbleShape` | `sphere`, `ellipsoid`, or `cube`. |
| `size` | `Size` | Width and height of the bubble. |
| `baseColor` | `Color` | Primary tint color of the bubble. |
| `iridescence` | `double` | Intensity of the rainbow/oil-film interference ring (0.0 to 1.0). |
| `bodyCenterAlpha` | `double` | Opacity at the center of the bubble body (Fresnel effect). |
| `bodyEdgeAlpha` | `double` | Opacity at the edges of the bubble body. |
| `rimAlpha` | `double` | Opacity of the outer glass rim. |
| `initialRotation` | `Offset` | Starting 3D angle for cube shapes (`dx` for X-axis, `dy` for Y-axis). |

### 4. Creating Custom Widgets (Posters / UI)

To display a bubble statically or in standard Flutter UI widgets:

```dart
import 'package:bubble/components/bubble/ui/bubble_widget.dart';
import 'package:bubble/components/bubble/bubble_style.dart';

class MyPosterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: BubbleWidget(
        text: 'Special Offer!',
        textColor: Colors.yellow,
        style: BubbleStyle(
          shape: BubbleShape.ellipsoid,
          size: Size(220, 140),
          baseColor: Colors.cyanAccent,
          iridescence: 0.8,
        ),
      ),
    );
  }
}
```

### 5. Spawning Custom Bubbles in the Game

In [bubble_game.dart](file:///C:/Users/NEKENA/bubble/lib/game/bubble_game.dart), add custom spawns inside `onLoad()`:

```dart
await add(
  Bubble(
    position: Vector2(400, 300),
    textColor: Colors.white,
    config: BubbleConfig(
      text: 'Bonus',
      speed: 20,
      direction: BubbleDirection.bottomToTop,
      style: BubbleStyle(
        shape: BubbleShape.cube,
        size: Size(120, 120),
        baseColor: Colors.amberAccent,
      ),
    ),
  ),
);
```
