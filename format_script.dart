import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found');
    return;
  }

  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  int processed = 0;

  for (var file in files) {
    String content = file.readAsStringSync();
    String originalContent = content;

    // Only process files that seem to be UI files
    if (!content.contains('package:flutter/material.dart') && 
        !content.contains('package:flutter/cupertino.dart')) {
      continue;
    }

    // Avoid double imports
    if (!content.contains('package:flutter_screenutil/flutter_screenutil.dart')) {
      content = content.replaceFirst(
        "import 'package:flutter/material.dart';", 
        "import 'package:flutter/material.dart';\nimport 'package:flutter_screenutil/flutter_screenutil.dart';"
      );
      // In case material.dart isn't found but cupertino is
      if (!content.contains('flutter_screenutil')) {
        content = content.replaceFirst(
          "import 'package:flutter/cupertino.dart';", 
          "import 'package:flutter/cupertino.dart';\nimport 'package:flutter_screenutil/flutter_screenutil.dart';"
        );
      }
    }

    // Simple regexes for numeric literals
    final RegExp numRegex = RegExp(r'^[\d\.]+$');

    // EdgeInsets.all
    content = content.replaceAllMapped(RegExp(r'EdgeInsets\.all\(\s*([\d\.]+)\s*\)'), (match) {
      if (match.group(1) == '0' || match.group(1) == '0.0') return match.group(0)!;
      return 'EdgeInsets.all(${match.group(1)}.w)';
    });

    // EdgeInsets.symmetric
    content = content.replaceAllMapped(RegExp(r'EdgeInsets\.symmetric\(([^)]+)\)'), (match) {
      String inner = match.group(1)!;
      inner = inner.replaceAllMapped(RegExp(r'horizontal:\s*([\d\.]+)'), (m) => 'horizontal: ${m.group(1)}.w');
      inner = inner.replaceAllMapped(RegExp(r'vertical:\s*([\d\.]+)'), (m) => 'vertical: ${m.group(1)}.h');
      // Fix double extensions if already done before
      inner = inner.replaceAll(RegExp(r'\.w\.w'), '.w').replaceAll(RegExp(r'\.h\.h'), '.h');
      return 'EdgeInsets.symmetric($inner)';
    });

    // EdgeInsets.only
    content = content.replaceAllMapped(RegExp(r'EdgeInsets\.only\(([^)]+)\)'), (match) {
      String inner = match.group(1)!;
      inner = inner.replaceAllMapped(RegExp(r'left:\s*([\d\.]+)'), (m) => 'left: ${m.group(1)}.w');
      inner = inner.replaceAllMapped(RegExp(r'right:\s*([\d\.]+)'), (m) => 'right: ${m.group(1)}.w');
      inner = inner.replaceAllMapped(RegExp(r'top:\s*([\d\.]+)'), (m) => 'top: ${m.group(1)}.h');
      inner = inner.replaceAllMapped(RegExp(r'bottom:\s*([\d\.]+)'), (m) => 'bottom: ${m.group(1)}.h');
      inner = inner.replaceAll(RegExp(r'\.w\.w'), '.w').replaceAll(RegExp(r'\.h\.h'), '.h');
      return 'EdgeInsets.only($inner)';
    });

    // EdgeInsets.fromLTRB
    content = content.replaceAllMapped(RegExp(r'EdgeInsets\.fromLTRB\(\s*([\d\.]+)\s*,\s*([\d\.]+)\s*,\s*([\d\.]+)\s*,\s*([\d\.]+)\s*\)'), (match) {
      return 'EdgeInsets.fromLTRB(${match.group(1)}.w, ${match.group(2)}.h, ${match.group(3)}.w, ${match.group(4)}.h)';
    });

    // SizedBox height
    content = content.replaceAllMapped(RegExp(r'SizedBox\(\s*height:\s*([\d\.]+)\s*\)'), (match) {
      return 'SizedBox(height: ${match.group(1)}.h)';
    });

    // SizedBox width
    content = content.replaceAllMapped(RegExp(r'SizedBox\(\s*width:\s*([\d\.]+)\s*\)'), (match) {
      return 'SizedBox(width: ${match.group(1)}.w)';
    });
    
    // SizedBox height & width
    content = content.replaceAllMapped(RegExp(r'SizedBox\(\s*width:\s*([\d\.]+)\s*,\s*height:\s*([\d\.]+)\s*\)'), (match) {
      return 'SizedBox(width: ${match.group(1)}.w, height: ${match.group(2)}.h)';
    });

    // fontSize
    content = content.replaceAllMapped(RegExp(r'fontSize:\s*([\d\.]+)(?!\s*\.sp)'), (match) {
      return 'fontSize: ${match.group(1)}.sp';
    });

    // BorderRadius.circular
    content = content.replaceAllMapped(RegExp(r'BorderRadius\.circular\(\s*([\d\.]+)\s*\)'), (match) {
      return 'BorderRadius.circular(${match.group(1)}.r)';
    });

    // Radius.circular
    content = content.replaceAllMapped(RegExp(r'Radius\.circular\(\s*([\d\.]+)\s*\)'), (match) {
      return 'Radius.circular(${match.group(1)}.r)';
    });

    // Cleanup already double extensions that might exist
    content = content.replaceAll('.w.w', '.w').replaceAll('.h.h', '.h').replaceAll('.sp.sp', '.sp').replaceAll('.r.r', '.r');

    if (content != originalContent) {
      file.writeAsStringSync(content);
      processed++;
    }
  }

  print('Successfully processed $processed files.');
}
