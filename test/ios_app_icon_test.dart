import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import '../tool/validate_ios_app_icons.dart';

Uint8List fixturePng({int colorType = 2, bool transparency = false}) {
  // Valid PNG chunks; alpha bytes are opaque even for the rejected RGBA case.
  List<int> chunk(String type, List<int> contents) {
    final body = [...ascii.encode(type), ...contents];
    var crc = 0xffffffff;
    for (final byte in body) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    final size = ByteData(4)..setUint32(0, contents.length);
    final checksum = ByteData(4)..setUint32(0, crc ^ 0xffffffff);
    return [
      ...size.buffer.asUint8List(),
      ...body,
      ...checksum.buffer.asUint8List(),
    ];
  }

  final header = ByteData(13)
    ..setUint32(0, 1)
    ..setUint32(4, 1);
  header.setUint8(8, 8);
  header.setUint8(9, colorType);
  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ...chunk('IHDR', header.buffer.asUint8List()),
    if (transparency) ...chunk('tRNS', [0, 0, 0, 0, 0, 0]),
    ...chunk(
      'IDAT',
      ZLibEncoder().convert([0, 255, 255, 255, if (colorType == 6) 255]),
    ),
    ...chunk('IEND', []),
  ]);
}

void main() {
  test('all shipped iOS icons are RGB and match their catalog dimensions', () {
    expect(
      validateIosAppIcons(
        Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset'),
      ),
      15,
    );
  });
  test('opaque RGB PNG passes without an alpha channel', () {
    expect(inspectOpaqueIcon(fixturePng(), 'fixture.png'), (
      width: 1,
      height: 1,
    ));
  });
  for (final type in [4, 6]) {
    test(
      'alpha channel is rejected even when no pixels are transparent: $type',
      () {
        expect(
          () => inspectOpaqueIcon(fixturePng(colorType: type), 'fixture.png'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('alpha channel'),
            ),
          ),
        );
      },
    );
  }
  test('RGB PNG with a transparency chunk is rejected', () {
    expect(
      () => inspectOpaqueIcon(fixturePng(transparency: true), 'fixture.png'),
      throwsFormatException,
    );
  });
  test('palette encoding is rejected in this RGB-only catalog', () {
    expect(
      () => inspectOpaqueIcon(fixturePng(colorType: 3), 'fixture.png'),
      throwsFormatException,
    );
  });
  test(
    'invalid signature, truncated chunks and missing end chunk are rejected',
    () {
      final bytes = fixturePng();
      for (final invalid in [
        Uint8List(33),
        Uint8List.fromList(bytes.sublist(0, 34)),
        Uint8List.fromList(bytes.sublist(0, bytes.length - 12)),
      ]) {
        expect(
          () => inspectOpaqueIcon(invalid, 'fixture.png'),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'catalog requires a 1024px App Store icon and valid local file paths',
    () {
      final catalog = Directory.systemTemp.createTempSync(
        'rider-icon-fixture-',
      );
      addTearDown(() => catalog.deleteSync(recursive: true));
      File('${catalog.path}/fixture.png').writeAsBytesSync(fixturePng());
      for (final entry in [
        {
          'filename': 'fixture.png',
          'size': '1x1',
          'scale': '1x',
          'idiom': 'ios-marketing',
        },
        {
          'filename': 'fixture.png',
          'size': '2x2',
          'scale': '1x',
          'idiom': 'iphone',
        },
        {
          'filename': '../fixture.png',
          'size': '1x1',
          'scale': '1x',
          'idiom': 'iphone',
        },
        {
          'filename': 'fixture.png',
          'size': '1x1',
          'scale': '1x',
          'idiom': 'iphone',
        },
      ]) {
        File('${catalog.path}/Contents.json').writeAsStringSync(
          jsonEncode({
            'images': [entry],
          }),
        );
        expect(() => validateIosAppIcons(catalog), throwsFormatException);
      }
    },
  );
  test('both iOS release workflows validate icons before building the IPA', () {
    final yaml = File('codemagic.yaml').readAsStringSync();
    for (final workflow in [
      yaml.split('  ios-release:').last.split('  default-workflow:').first,
      yaml.split('  default-workflow:').last,
    ]) {
      final check = workflow.indexOf(
        'dart run tool/validate_ios_app_icons.dart',
      );
      expect(check, greaterThanOrEqualTo(0));
      expect(check, lessThan(workflow.indexOf('flutter build ipa')));
    }
  });
}
