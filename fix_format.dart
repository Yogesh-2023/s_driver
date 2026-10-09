import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  int processed = 0;

  for (var file in files) {
    String content = file.readAsStringSync();
    String original = content;

    // Fix issues like 10..ww, 14..spsp, 10..h, etc.
    content = content.replaceAll('..ww', '.w');
    content = content.replaceAll('..hh', '.h');
    content = content.replaceAll('..rr', '.r');
    content = content.replaceAll('..spsp', '.sp');

    // Fix issues like .w.w, .sp.sp
    content = content.replaceAll('.w.w', '.w');
    content = content.replaceAll('.h.h', '.h');
    content = content.replaceAll('.r.r', '.r');
    content = content.replaceAll('.sp.sp', '.sp');

    // Fix double dots
    content = content.replaceAll('..w', '.w');
    content = content.replaceAll('..h', '.h');
    content = content.replaceAll('..r', '.r');
    content = content.replaceAll('..sp', '.sp');

    if (content != original) {
      file.writeAsStringSync(content);
      processed++;
    }
  }

  print('Successfully fixed formatting issues in $processed files.');
}
