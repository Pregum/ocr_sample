import 'dart:io';

import 'package:camera/camera.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ocr_sample/detector_view.dart';
import 'package:ocr_sample/text_detector_painter.dart';
import 'package:image/image.dart' as img;

class HalfCustomTextDetectorPage extends HookWidget {
  // bool _canProcess = true;
  // bool _isBusy = false;
  // CustomPaint? _customPaint;
  // const CustomTextDetectorPage({super.key});
  // var _script = TextRecognitionScript.japanese;
  // final _textRecognizer =
  //     TextRecognizer(script: TextRecognitionScript.japanese);

  const HalfCustomTextDetectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canProcess = useState(true);
    final isBusy = useState(false);
    final customPaint = useState<CustomPaint?>(null);
    final text = useState<String>('');
    final cameraLensDirection = useState(CameraLensDirection.back);
    final textRecognizer =
        useState(TextRecognizer(script: TextRecognitionScript.japanese));
    final enabledDetectPainter = useState(true);
    final selectedTextList = useState<List<(Rect, String)>>([]);

    useEffect(() {
      return () {
        debugPrint('[half_custom_text_detector]textRecognizer close');
        // _textRecognizer.close();
        textRecognizer.value.close();
        // customPaint.value = null;
      };
    }, []);

    return Scaffold(
      appBar: AppBar(title: const Text('Half Custom Text Detector')),
      body: Stack(
        children: [
          Positioned(
            height: MediaQuery.of(context).size.height * 0.5,
            // height: 500,
            right: 0,
            left: 0,
            top: 0,
            child: DetectorView(
              title: 'テキスト検出',
              onImage: (InputImage inputImage) {
                debugPrint('start processImage');
                _processImage(
                  context,
                  inputImage,
                  canProcess,
                  isBusy,
                  customPaint,
                  text,
                  cameraLensDirection,
                  textRecognizer,
                  enabledDetectPainter,
                );
              },
              text: text.value,
              customPaint: customPaint.value,
              initialCameraLensDirection: cameraLensDirection.value,
              onCameraLensDirectionChanged: (value) =>
                  cameraLensDirection.value = value,
              onTapCustomPaint: (blocks, details) {
                // debugPrint('text: ${text.value}');
                debugPrint('blocks: $blocks');
                debugPrint('details: $details');
                final first = blocks.firstWhereOrNull(
                    (element) => element.$1.contains(details.localPosition));
                debugPrint('containsBlock: $first');
                if (first != null) {
                  final newList =
                      List<(Rect, String)>.from(selectedTextList.value);
                  newList.add(first);
                  // selectedTextList.value.add(first);
                  selectedTextList.value = newList;
                }
              },
              onChangeVisibleDetectPainter: (bool enableDetect) {
                enabledDetectPainter.value = enableDetect;
                if (!enableDetect) {
                  customPaint.value = null;
                }
              },
            ),
          ),
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.5,
            child: Container(
              color: Colors.amber,
              child: ListView.builder(
                itemBuilder: (context, index) {
                  final item = selectedTextList.value[index];
                  return Dismissible(
                    key: ValueKey(item.$1),
                    onDismissed: (direction) {
                      final newList =
                          List<(Rect, String)>.from(selectedTextList.value);
                      newList.removeAt(index);
                      selectedTextList.value = newList;
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListTile(
                        // title: Text('Item $index'),
                        title: Text('Item name: ${item.$1}'),
                        subtitle: Text('Rect: ${item.$2}'),
                      ),
                    ),
                  );
                },
                itemCount: selectedTextList.value.length,
                // itemCount: 1000,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processImage(
    BuildContext context,
    InputImage inputImage,
    ValueNotifier<bool> canProcess,
    ValueNotifier<bool> isBusy,
    ValueNotifier<CustomPaint?> customPaint,
    ValueNotifier<String> text,
    ValueNotifier<CameraLensDirection> cameraLensDirection,
    ValueNotifier<TextRecognizer> textRecognizer,
    ValueNotifier<bool> enableDetect,
  ) async {
    if (!canProcess.value) return;
    if (isBusy.value) return;
    if (!enableDetect.value) return;
    isBusy.value = true;
    text.value = '';
    // setState(() {
    //   _text = '';
    // });
    final recognizedText = await textRecognizer.value.processImage(inputImage);

    if (!context.mounted) return;
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = TextRecognizerPainter(
        recognizedText,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        cameraLensDirection.value,
      );
      final size = MediaQuery.sizeOf(context);
      debugPrint(
          'mediaQuery: $size, size: ${inputImage.metadata?.size}, rotation: ${inputImage.metadata!.rotation}');
      customPaint.value = CustomPaint(painter: painter);
    } else {
      // text.value = 'Recognized text:\n\n${recognizedText.text}';
      // // TODO: set _customPaint to draw boundingRect on top of image
      // customPaint.value = null;
      // final bytes = inputImage.!;
      final image = File(inputImage.filePath!);
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(Uint8List.fromList(bytes))!;
      // 画像のサイズを取得する
      // final bytes = await image.readAsBytes();
      // final decodedImage = img.decodeImage(Uint8List.fromList(bytes))!;
      final size = MediaQuery.sizeOf(context);
      // debugPrint('mediaQuery: $size, Width: ${decodedImage.width}, Height: ${decodedImage.height}');
      debugPrint(
          'mediaQuery: $size, size: ${inputImage.metadata?.size}, rotation: ${inputImage.metadata?.rotation}');

      final painter = TextRecognizerPainter(
        recognizedText,
        // inputImage.metadata?.size ??
        Size(
          decodedImage.width.toDouble(),
          decodedImage.height.toDouble(),
          // 720,
          // 1280,
        ),
        // const Size(400, 400),
        inputImage.metadata?.rotation ?? InputImageRotation.rotation0deg,
        cameraLensDirection.value,
      );
      customPaint.value = CustomPaint(painter: painter);
    }
    isBusy.value = false;
    // if (context.mounted) {
    //   setState(() {});
    // }
  }
}
