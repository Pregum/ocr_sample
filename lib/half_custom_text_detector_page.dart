import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ocr_sample/detector_view.dart';
import 'package:ocr_sample/text_detector_painter.dart';

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
          Positioned.fill(
            child: Container(color: Colors.amber),
          ),
          Positioned(
            height: MediaQuery.of(context).size.height * 0.5,
            // height: 500,
            right: 0,
            left: 0,
            top: 0,
            child: DetectorView(
              title: 'テキスト検出',
              onImage: (InputImage inputImage) {
                _processImage(
                  context,
                  inputImage,
                  canProcess,
                  isBusy,
                  customPaint,
                  text,
                  cameraLensDirection,
                  textRecognizer,
                );
              },
              text: text.value,
              customPaint: customPaint.value,
              initialCameraLensDirection: cameraLensDirection.value,
              onCameraLensDirectionChanged: (value) =>
                  cameraLensDirection.value = value,
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
  ) async {
    if (!canProcess.value) return;
    if (isBusy.value) return;
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
      customPaint.value = CustomPaint(painter: painter);
    } else {
      text.value = 'Recognized text:\n\n${recognizedText.text}';
      // TODO: set _customPaint to draw boundingRect on top of image
      customPaint.value = null;
    }
    isBusy.value = false;
    // if (context.mounted) {
    //   setState(() {});
    // }
  }
}
