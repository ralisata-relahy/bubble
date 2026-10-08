# Bubble

A Flutter and Flame game with customizable glass bubbles and laser interaction.

## Project organization

- `lib/core/` contains shared integration contracts.
- `lib/features/bubble/` contains bubble models, Flame components, renderers,
  and a reusable Flutter widget.
- `lib/features/game/` contains the Flame game and its laser component.
- `assets/` contains the images used by the game.

See [PROJECT_STRUCTURE.txt](./PROJECT_STRUCTURE.txt) for the complete source
tree and a summary of the reorganization. See the
[bubble customization guide](./bubble_customization_guide.md) for configuration
and usage examples.

## Run

```sh
flutter pub get
flutter run
```
