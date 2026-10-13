import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Validates the legacy PNG app-icon catalog used by this app, without edits.
/// RGB encoding is required even when every pixel in an RGBA file is opaque.
({int width, int height}) inspectOpaqueIcon(Uint8List bytes, String filename) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  Never fail(String message) => throw FormatException('$filename: $message');
  if (bytes.length < 33 ||
      !List.generate(
        8,
        (i) => bytes[i],
      ).asMap().entries.every((entry) => entry.value == signature[entry.key])) {
    fail('not a complete PNG file');
  }
  final data = ByteData.sublistView(bytes);
  ({int width, int height})? size;
  var hasImageData = false;
  var offset = 8;
  while (offset + 12 <= bytes.length) {
    final length = data.getUint32(offset);
    final end = offset + length + 12;
    if (end > bytes.length) fail('truncated PNG chunk');
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    if (offset == 8 && type != 'IHDR') fail('missing PNG header');
    if (type == 'IHDR') {
      if (size != null || length != 13) fail('invalid PNG header');
      size = (
        width: data.getUint32(offset + 8),
        height: data.getUint32(offset + 12),
      );
      if (size.width <= 0 || size.height <= 0) fail('invalid image dimensions');
      if (bytes[offset + 17] == 4 || bytes[offset + 17] == 6) {
        fail('contains an alpha channel; export as opaque RGB PNG');
      }
      if (bytes[offset + 16] != 8 || bytes[offset + 17] != 2) {
        fail('must be an 8-bit RGB PNG');
      }
    }
    if (type == 'tRNS') fail('contains a transparency chunk');
    if (type == 'IDAT' && length > 0) hasImageData = true;
    if (type == 'IEND') {
      if (length != 0 || size == null || !hasImageData) {
        fail('incomplete PNG image');
      }
      return size;
    }
    offset = end;
  }
  fail('missing PNG end chunk');
}

int validateIosAppIcons(Directory catalog) {
  final contents = jsonDecode(
    File('${catalog.path}/Contents.json').readAsStringSync(),
  );
  if (contents is! Map || contents['images'] is! List) {
    throw const FormatException('App icon catalog has no image entries');
  }
  final checked = <String>{};
  var marketingCount = 0;
  for (final entry in contents['images'] as List) {
    if (entry is! Map) throw const FormatException('Invalid app icon entry');
    final filename = entry['filename'];
    if (filename is! String ||
        !RegExp(r'^[A-Za-z0-9_.@-]+\.png$').hasMatch(filename)) {
      throw const FormatException('App icon filename is missing or invalid');
    }
    final dimensions = '${entry['size']}'.split('x');
    final scale = double.tryParse(
      '${entry['scale']}'.replaceFirst(RegExp(r'x$'), ''),
    );
    final width = dimensions.length == 2
        ? double.tryParse(dimensions[0])
        : null;
    final height = dimensions.length == 2
        ? double.tryParse(dimensions[1])
        : null;
    if (width == null ||
        height == null ||
        scale == null ||
        !width.isFinite ||
        !height.isFinite ||
        !scale.isFinite ||
        width <= 0 ||
        height <= 0 ||
        scale <= 0) {
      throw FormatException('$filename: invalid catalog dimensions');
    }
    final size = inspectOpaqueIcon(
      File('${catalog.path}/$filename').readAsBytesSync(),
      filename,
    );
    if (size.width != (width * scale).round() ||
        size.height != (height * scale).round() ||
        size.width != size.height) {
      throw FormatException('$filename: image dimensions do not match catalog');
    }
    if (entry['idiom'] == 'ios-marketing') {
      marketingCount++;
      if (size.width != 1024 || scale != 1) {
        throw FormatException(
          '$filename: App Store icon must be 1024x1024 at 1x',
        );
      }
    }
    checked.add(filename);
  }
  if (marketingCount != 1) {
    throw const FormatException('Catalog must contain one App Store icon');
  }
  return checked.length;
}

void main() {
  try {
    final count = validateIosAppIcons(
      Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset'),
    );
    stdout.writeln(
      'Validated $count opaque RGB iOS app icons, including the App Store icon.',
    );
  } catch (error) {
    stderr.writeln('iOS app icon validation failed: $error');
    exitCode = 1;
  }
}
