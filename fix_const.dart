import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  int processed = 0;

  final regex = RegExp(r'const\s+([A-Z_][a-zA-Z0-9_]*)');
  final listRegex = RegExp(r'const\s+\[');
  final genericListRegex = RegExp(r'const\s+<[^>]+>\[');

  for (var file in files) {
    String content = file.readAsStringSync();
    String original = content;

    // Remove const before constructor calls
    content = content.replaceAllMapped(regex, (match) {
      final type = match.group(1)!;
      // Allow const for primitives and a few safe ones
      if (['Color', 'String', 'int', 'double', 'bool', 'BoxConstraints', 'LinearGradient'].contains(type)) {
        return match.group(0)!;
      }
      return type;
    });

    // Remove const before lists
    content = content.replaceAll(listRegex, '[');
    content = content.replaceAllMapped(genericListRegex, (match) {
      return match.group(0)!.replaceFirst('const ', '');
    });

    if (content != original) {
      file.writeAsStringSync(content);
      processed++;
    }
  }

  print('Successfully removed invalid consts from $processed files.');
}
