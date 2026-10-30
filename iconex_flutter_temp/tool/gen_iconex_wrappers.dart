import 'dart:io';

/// Reads the generated icon files and builds wrapper classes
/// that expose all IconData as getters under Iconex.filled, Iconex.light, etc.
void main() {
  const styles = ['filled', 'light', 'broken'];
  final buffer = StringBuffer();

  buffer.writeln('library iconex_flutter;');
  buffer.writeln("import 'package:flutter/widgets.dart';");
  buffer.writeln();

  // Import each generated file
  for (final style in styles) {
    buffer.writeln("import 'generated/iconex_$style.dart' as $style;");
  }

  buffer.writeln();
  buffer.writeln('class Iconex {');
  buffer.writeln('  Iconex._();');
  for (final style in styles) {
    final className = '_Iconex${_capitalize(style)}';
    buffer.writeln('  static const $style = $className();');
  }
  buffer.writeln('}');
  buffer.writeln();

  for (final style in styles) {
    final styleCap = _capitalize(style);
    buffer.writeln('class _Iconex$styleCap {');
    buffer.writeln('  const _Iconex$styleCap();');
    buffer.writeln();

    final file = File('lib/generated/iconex_$style.dart');
    if (!file.existsSync()) continue;

    final content = file.readAsStringSync();
    final matches = RegExp(r'static const IconData (\w+)').allMatches(content);

    for (final match in matches) {
      final name = match.group(1);
      buffer.writeln(
        '  IconData get $name => $style.Iconex${styleCap}Data.$name;',
      );
    }

    buffer.writeln('}');
    buffer.writeln();
  }

  File('lib/iconex_flutter.dart').writeAsStringSync(buffer.toString());
  // ignore: avoid_print
  print('Updated lib/iconex_flutter.dart with all icon getters.');
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
