import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPngPath = 'assets/icon/app_icon.png';
  final inputFile = File(inputPngPath);
  if (!inputFile.existsSync()) {
    print('Error: Input file $inputPngPath does not exist.');
    exit(1);
  }

  print('Reading $inputPngPath...');
  final imageBytes = inputFile.readAsBytesSync();
  final original = img.decodeImage(imageBytes);
  if (original == null) {
    print('Error: Could not decode PNG.');
    exit(1);
  }

  print('Original dimensions: ${original.width}x${original.height}');
  final truePngBytes = img.encodePng(original);
  inputFile.writeAsBytesSync(truePngBytes);
  print('Re-encoded assets/icon/app_icon.png as true PNG (${truePngBytes.length} bytes)');

  final sizes = [256, 128, 64, 48, 32, 24, 16];
  final images = <img.Image>[];

  for (final size in sizes) {
    print('Resizing to ${size}x$size...');
    final resized = img.copyResize(
      original,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    images.add(resized);
  }

  print('Encoding ICO with ${images.length} resolutions...');
  final encoder = img.IcoEncoder();
  final icoBytes = encoder.encodeImages(images);

  // Write to c:\Users\tatai\Downloads\flutter_application_1\windows\runner\resources\app_icon.ico
  final target1 = File('windows/runner/resources/app_icon.ico');
  target1.writeAsBytesSync(icoBytes);
  print('Successfully wrote ${icoBytes.length} bytes to ${target1.path}');

  // Also write to e:\Programming Codes\T5-PASSWORD-MANAGER-CLOUD if present
  final target2 = File(r'e:\Programming Codes\T5-PASSWORD-MANAGER-CLOUD\windows\runner\resources\app_icon.ico');
  if (target2.parent.existsSync()) {
    target2.writeAsBytesSync(icoBytes);
    print('Successfully wrote ${icoBytes.length} bytes to ${target2.path}');
  }
}
