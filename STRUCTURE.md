# Project architecture

The app uses Flutter for screens and overlays and Flame for the real-time game
world. Source code is grouped by feature; shared contracts and platform adapters
live in `core`.

The architecture follows a **feature-first Clean Architecture + MVC** approach:

- **Model** — pure Dart domain entities, configuration, and rules.
- **View** — Flutter screens, overlays, and Flame component rendering.
- **Controller** — GetX controllers that own observable state and orchestrate
  commands between the UI, domain layer, and Flame world.
- **Flame stays in charge of the real-time world** — positions, velocities,
  collisions, animations, and per-frame updates remain inside Flame components.
  GetX controllers issue high-level commands (start/restart/advance) via the
  `GameCommandPort` contract; they never manipulate per-frame physics state.

---

## Source layout

```text
lib/
├── main.dart                           App entry point and GetX initialisation
├── app.dart                            Root widget (BubbleApp) and GameView composition
│
├── core/
│   ├── contracts/
│   │   ├── knowledge_bubble_host.dart  Flame ↔ domain boundary for knowledge bubbles
│   │   └── laser_target.dart           Laser targeting contract for hittable entities
│   ├── physics/
│   │   └── bubble_collision_resolver.dart  Reusable impulse-based collision resolver
│   ├── presentation/
│   │   └── widgets/
│   │       ├── hud_button.dart         Shared neon HUD action button
│   │       └── space_background.dart   Shared animated starfield background
│   └── services/
│       ├── haptics_service.dart        Optional device vibration adapter
│       └── audio/
│           ├── game_audio.dart         Synthesised sound-effect builder (SFX)
│           ├── sfx_generate.dart       Low-level PCM synthesis primitives
│           ├── sound_effect.dart       SoundEffects facade (per-session player pool)
│           ├── sound_sfx.dart          SFX identifier enum
│           └── audio_emotion/
│               └── emotion_speaker.dart  Emotion-to-audio mapping helper
│
└── features/
    │
    ├── ai_buddy/                        Edutainer character — model, painting, widgets
    │   ├── controllers/
    │   │   └── ai_buddy_controller.dart  GetX controller for AI buddy state
    │   ├── bindings/
    │   │   └── ai_buddy_binding.dart     GetX binding registering the controller
    │   ├── views/
    │   │   └── edutainment_view.dart     Edutainment character view export barrel
    │   ├── models/
    │   │   ├── character_pose.dart       Immutable edutainer pose description
    │   │   └── saucer_palette.dart       Flying-saucer colour scheme
    │   ├── painter/
    │   │   ├── edutainer_context.dart    Paint-time context passed to all painters
    │   │   ├── arms_painter.dart         Arm stroke painting
    │   │   ├── body_painter.dart         Body fill and outline painting
    │   │   ├── eye_painter.dart          Eye expression painting
    │   │   ├── ground_painter.dart       Ground shadow / reflection painting
    │   │   ├── laser_painter.dart        Laser beam painting
    │   │   ├── mouth_painter.dart        Mouth expression painting
    │   │   ├── paint_utils.dart          Shared paint utilities
    │   │   └── saucer_painter.dart       Flying-saucer painting
    │   ├── widgets/
    │   │   ├── cage_painter.dart         Energy cage widget painter
    │   │   ├── edutainer_painter.dart    Top-level character CustomPainter
    │   │   └── edutainment_character.dart  Animated character Flutter widget
    │   └── edutainer.dart               Main edutainment entry widget
    │
    ├── bubble/                          Bubble entities, physics, and rendering
    │   ├── controllers/
    │   │   └── bubble_controller.dart   GetX controller for bubble reactive state
    │   ├── bindings/
    │   │   └── bubble_binding.dart      GetX binding for bubble dependencies
    │   ├── views/
    │   │   └── bubble_view.dart         Bubble view export barrel
    │   ├── models/
    │   │   ├── bubble_config.dart       Kinematic and visual bubble configuration (immutable)
    │   │   └── bubble_style.dart        Shape, size, and base-colour definition
    │   └── presentation/
    │       ├── components/
    │       │   ├── bubble.dart          Main answer Flame component (physics + rendering)
    │       │   ├── bubble_label.dart    Text label laid out inside a bubble
    │       │   └── knowledge_bubble.dart  Secondary knowledge bubble Flame component
    │       ├── rendering/
    │       │   ├── bubble_renderer.dart   Abstract renderer factory and contract
    │       │   ├── sphere_renderer.dart   Animated glass sphere / ellipsoid renderer
    │       │   ├── bubble_heat_effect.dart  Laser heat glow accumulator
    │       │   ├── bubble_pop_renderer.dart  Pop particle burst renderer
    │       │   └── bubble_text_helper.dart   Auto-fitting text layout utility
    │       └── widgets/
    │           └── bubble_widget.dart   Flutter CustomPainter for bubble preview
    │
    ├── curio/                           Curio mascot — mood, timer, gauge
    │   ├── controllers/
    │   │   └── curio_controller.dart   GetX controller for Curio mood state
    │   ├── bindings/
    │   │   └── curio_binding.dart      GetX binding registering CurioController
    │   ├── views/
    │   │   └── curio_views.dart        Curio view export barrel
    │   ├── models/
    │   │   └── mood.dart               Forwarding export → domain/models/mood.dart
    │   ├── domain/
    │   │   └── models/
    │   │       └── mood.dart           Mood enum (excited, happy, neutral, sad, …)
    │   ├── services/
    │   │   └── curio_audio_service.dart  Curio voice and mood-audio playback
    │   └── presentation/
    │       └── widgets/
    │           ├── character_time_gauge.dart  Animated countdown gauge with mood transitions
    │           ├── curio_timer.dart           Timer widget coordinating Curio state
    │           ├── character_backup_painter.dart  Character silhouette painter
    │           └── character_backup_widget.dart   Character silhouette widget
    │
    └── game/                            Top-level game feature
        ├── controllers/
        │   └── game_controller.dart    Canonical GetX session controller (round, score, state)
        ├── bindings/
        │   └── game_binding.dart       Canonical GetX binding (registers GameController)
        ├── views/
        │   └── game_view.dart          GameView widget (GameWidget + overlays)
        ├── models/
        │   └── game_models.dart        Export barrel for game domain models
        ├── application/                 ← Forwarding exports (backward compat)
        │   ├── controllers/
        │   │   └── game_controller.dart  Re-exports features/game/controllers/game_controller.dart
        │   ├── bindings/
        │   │   └── game_binding.dart     Re-exports features/game/bindings/game_binding.dart
        │   └── contracts/
        │       └── game_command_port.dart  Flame ↔ controller command boundary
        ├── configuration/
        │   └── game_configuration.dart  Gameplay tuning constants (speeds, durations, counts)
        ├── data/
        │   ├── game_questions.dart      Static question catalog
        │   └── repositories/
        │       └── game_question_repository.dart  StaticGameQuestionRepository interface
        ├── domain/
        │   ├── game_question_deck.dart  Round-aware question picker (no repeat logic)
        │   ├── models/
        │   │   ├── game_question.dart   Immutable question entity (prompt, choices, answer)
        │   │   └── popped_bubble_record.dart  Snapshot of a popped bubble and its knowledge
        │   ├── rules/
        │   │   └── round_color_palette.dart  Per-round distinct color selection rule
        │   └── services/
        │       └── bubble_pop_history.dart  Ordered, deduplicated pop history
        ├── presentation/
        │   ├── bubble_game.dart         Flame lifecycle coordinator and top-level game entity
        │   ├── components/
        │   │   ├── laser_beam.dart      Laser cannon component (origin, label, fire)
        │   │   ├── aim_guide_component.dart  Trajectory preview overlay component
        │   │   ├── trajectory_calculator.dart  Pure bounce-path computation
        │   │   ├── confetti_component.dart     Particle confetti burst component
        │   │   ├── knowledge_bubble_scatter.dart  Knowledge presentation + absorption sequence
        │   │   └── laser_label_box.dart  Cached neon HUD label panel
        │   ├── overlays/
        │   │   ├── game_over_overlay.dart  Flutter game-over dialog
        │   │   ├── winning_overlay.dart    Flutter round-won dialog
        │   │   └── accelerate_overlay.dart Flutter skip button during knowledge dispersal
        │   └── systems/
        │       └── bubble_collision_system.dart  Per-frame collision dispatch pass
        └── services/
            └── game_audio_service.dart  Question pronunciation audio playback
```

---

## Key architectural decisions

### GetX ↔ Flame boundary

`GameController` (GetX) owns all Flutter-observable state:

| Observable | Type | Owner |
|---|---|---|
| `completedRounds` | `RxInt` | `GameController` |
| `isWon` | `bool` (derived) | `GameController` |
| `isGameOver` | `bool` (derived) | `GameController` |
| `isCriticalNotifier` | `ValueNotifier<bool>` | `GameController` |
| `isTimerPausedNotifier` | `ValueNotifier<bool>` | `GameController` |
| `currentMood` | `Rx<Mood>` | `CurioController` |

`BubbleGame` (Flame) owns all real-time simulation state:

- Bubble positions, velocities, and wave parameters
- Laser origin and trajectory
- Collision resolution
- Confetti particles and knowledge scatter sequences
- Per-frame animation state

High-level commands (`restartGame`, `accelerateKnowledge`, `nextRound`) are
issued by the UI through the `GameCommandPort` contract. `BubbleGame` implements
this contract and applies the commands to the Flame world.

### No per-frame Rx updates

Bubble positions, velocities, and collision states are **never** stored in `Rx`
variables. This prevents unnecessary Flutter widget rebuilds on every frame and
keeps Flame as the authoritative source of truth for real-time state.

### Color identity

`RoundColorPalette` (in `domain/rules/`) selects a distinct color per bubble
within a round and avoids re-using the previous round's colors. It is a pure
Dart class with no Flutter or Flame dependencies.

---

## Test coverage

| Test file | What it covers |
|---|---|
| `bubble_collision_test.dart` | `BubbleCollisionResolver` — separation and velocity |
| `bubble_controller_test.dart` | `BubbleController` reactive state |
| `bubble_painter_test.dart` | `BubblePainter.shouldRepaint` logic |
| `bubble_pop_history_test.dart` | `BubblePopHistory` ordering and deduplication |
| `curio_controller_test.dart` | `CurioController` mood transitions |
| `game_controller_test.dart` | `GameController` round/game lifecycle and binding |
| `game_question_deck_test.dart` | `GameQuestionDeck` selection and exclusion |
| `knowledge_bubble_scatter_layout_test.dart` | `KnowledgeBubbleScatterLayout` grid math |
| `popped_bubble_record_test.dart` | `PoppedBubbleRecord` immutability |
| `round_color_palette_test.dart` | `RoundColorPalette` uniqueness and reset |
| `trajectory_calculator_test.dart` | `TrajectoryCalculator` bounce-path math |
| `widget_test.dart` | Bubble hit-testing, label fitting, time gauge mood |
