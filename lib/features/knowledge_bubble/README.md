# Bubble component

A standalone Flutter package containing only the reusable bubble drawing
component and its visual styles. It does not depend on this project's game,
laser, audio, vibration, assets, or platform folders.

## Add to another Flutter project

Copy the `bubble_component` directory into the other project's repository and
add this dependency to that project's `pubspec.yaml`:

```yaml
dependencies:
  bubble_component:
    path: ./bubble_component
```

Then run `flutter pub get` and use the public package API:

```dart
import 'package:bubble_component/bubble_component.dart';
import 'package:flutter/material.dart';

class Example extends StatelessWidget {
  const Example({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: BubbleWidget(
        text: 'Hello!',
        style: BubbleStyle(
          shape: BubbleShape.sphere,
          size: Size(140, 140),
          baseColor: Colors.lightBlueAccent,
        ),
      ),
    );
  }
}
```

`BubbleShape` supports `sphere`, `ellipsoid`, and `cube`. `BubbleStyle` exposes
the visual parameters; `BubbleWidget` accepts text, text color, maximum lines,
and auto-fitting options.

The package preserves the original renderers while replacing app-specific
imports with package-local imports. Only `BubbleWidget`, `BubbleStyle`,
`BubbleShape`, `ArcStyle`, and `SpotStyle` are part of the public API.

## Dependencies

- Flutter 3.27 or later
- Dart 3.4 or later
- `google_fonts` (for the Quicksand label style)
