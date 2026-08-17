// Host-side driver for C-00 Lane A2 on-device capture.
// Receives the base64-packed rendered designs from the integration test's
// binding.reportData and writes them to the repo for decoding.
//
// Runs on the HOST (CWD = apps/mobile_flutter), so the repo-relative path works.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (Map<String, dynamic>? data) async {
        final capture = data?['capture'];
        if (capture == null) {
          // ignore: avoid_print
          print('[device-capture] no capture data in reportData');
          return;
        }
        final dir = Directory(
            '../../design_studio/generated_batches/rendered_device')
          ..createSync(recursive: true);
        File('${dir.path}/report.json')
            .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(capture));
        // ignore: avoid_print
        print('[device-capture] wrote ${dir.path}/report.json '
            '(${capture['count']} designs) — now run '
            'design_studio/tools/decode_device_capture.sh');
      },
    );
