# Project architecture

The app uses Flutter for screens and overlays and Flame for the real-time game
world. Source code is grouped by feature; shared contracts and platform adapters
live in `core`.

## Source layout

```text
lib/
|-- main.dart                         Flutter composition and app bootstrap
|-- core/
|   |-- contracts/                    Narrow interfaces shared across features
|   |-- physics/                      Reusable bubble collision resolution
|   |-- presentation/widgets/         Shared Flutter presentation
|   `-- services/                     Platform integrations shared by features
|       |-- audio/                    Synthesized sound effects and audio facade
|       `-- haptics_service.dart      Optional device vibration adapter
`-- features/
    |-- ai_buddy/                     Edutainer models, painters, and widgets
    |-- bubble/
    |   |-- models/                   Bubble motion and visual configuration
    |   `-- presentation/
    |       |-- components/           Flame bubble entities and labels
    |       |-- rendering/            Bubble drawing and text layout
    |       `-- widgets/              Flutter bubble presentation
    |-- curio/
    |   |-- domain/models/           Mood names and interpolated pose presets
    |   |-- presentation/widgets/    Character, timer, gauge, and overlays
    |   |-- services/                Curio voice playback
    `-- game/
        |-- application/
        |   |-- bindings/             GetX registration and session setup
        |   |-- contracts/            App-to-Flame command boundary
        |   `-- controllers/           Observable session state and commands
        |-- configuration/            Gameplay tuning values
        |-- data/                     Static question catalog
        |-- domain/
        |   |-- models/                Immutable question and pop records
        |   |-- game_question_deck.dart Question selection
        |   `-- services/              Ordered, deduplicated pop history
        |-- presentation/
        |   |-- components/           Laser, aiming, confetti, and knowledge scatter
        |   |-- overlays/             Flutter game-over, victory, and skip UI
        |   |-- systems/              Game-world collision pass
        |   `-- bubble_game.dart      Flame lifecycle and top-level coordination
        `-- services/                 Question pronunciation playback

test/                                 Flutter unit, widget, and layout tests
```

## Responsibilities and dependency direction

- `main.dart` composes the app, shared background, overlays, and one `BubbleGame`.
- `BubbleGame` owns Flame lifecycle and coordinates rounds, input, entities, and
  real-time simulation. It receives `GameController` through its constructor
  and implements the narrow `GameCommandPort`; it does not construct or dispose
  the GetX controller. `GameController` owns observable session state and sends
  high-level commands through that port. It delegates question selection to
  `GameQuestionDeck`, pop ordering and first-hit deduplication to
  `BubblePopHistory`, collision passes to the presentation
  `BubbleCollisionSystem`, and end-of-game knowledge animation to
  `KnowledgeBubbleScatter`.
- Game tuning values live in `GameConfiguration`; question content is data in
  `GameQuestions` and immutable `GameQuestion` values.
- Bubble entities own their Flame lifecycle and animation state. Bubble drawing
  helpers and renderers do not control round progression.
- `core` contains shared physics, contracts, and adapters. Feature code may use
  these abstractions; core services do not depend on game presentation.
- `GameAudioService` handles spoken question answers. The shared audio service
  owns generated sound effects, while `HapticsService` contains the optional
  vibration plugin call. Curio voice playback is owned by its feature-local
  `CurioAudioService` rather than its Flutter widget.
- Tests remain in Flutter's top-level `test/` directory and follow the module
  they exercise through their names and imports.

Flame entities are added to and removed from the component tree. The game
coordinator advances its state after Flame updates and keeps simulation timing
and overlays synchronized with the game lifecycle.
