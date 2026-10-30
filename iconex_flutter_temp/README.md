# Iconex Flutter

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.png)](https://opensource.org/licenses/MIT)
[![License: CC BY 4.0](https://img.shields.io/badge/icons-CC%20BY%204.0-orange.png)](https://creativecommons.org/licenses/by/4.0/)

A Flutter package that brings the **Iconex** icon set from Figma to Flutter.  
Clean, modern, and consistent vector icons are optimized for app interfaces.

## Quick Example

```dart
import 'package:iconex_flutter/iconex_flutter.dart';

IconexIcon(Iconex.filled.home, 
  color: Colors.orange, 
  size: 24.0,
);
```

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  iconex_flutter: ^1.0.1
```

Then run

`flutter pub get`

## Usage

---

```dart
import 'package:iconex_flutter/iconex_flutter.dart';

class Example extends StatelessWidget {
  const Example({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Iconex.filled.home),
        SizedBox(width: 12),
        Icon(Iconex.light.search),
        SizedBox(width: 12),
        Icon(Iconex.broken.heart),
      ],
    );
  }
}
```

### Light Icons

```dart
// import the package
import 'package:iconex_flutter/iconex_flutter.dart';

// Use Iconex.light for the Light (Stroke) icon style
Icon(Iconex.light.home,
  color: Colors.blue,
  size: 24.0,
  semanticLabel: 'Home',
),
```

### Broken Icons

```dart
// import the package
import 'package:iconex_flutter/iconex_flutter.dart';

// Use Iconex.broken for the Broken icon style
Icon(Iconex.broken.home,
  color: Colors.blue,
  size: 24.0,
  semanticLabel: 'Home',
),
```

### Filled Icons

```dart
// import the package
import 'package:iconex_flutter/iconex_flutter.dart';

// Use Iconex.filled for the Filled icon style
Icon(Iconex.filled.home,
  color: Colors.blue,
  size: 24.0,
  semanticLabel: 'Home',
),
```

## License

___

**Package code:** [MIT License](./LICENSE) © Budggy, Inc.

**Icons:** [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/)

- © Dmitry Mikhaylov and Tatyana Sheplyakova
- Source: [Iconex Figma Project](https://www.figma.com/community/file/1097525503669326714)

## Acknowledgements

___


Thanks to [Dmitry Mikhaylov](https://dribbble.com/MikhaylovArt) and [Tatyana Sheplyakova](https://dribbble.com/TatyanaShe) for creating the Iconex icons and sharing them with the design community.

[Iconex Figma Project](https://www.figma.com/community/file/1097525503669326714)
