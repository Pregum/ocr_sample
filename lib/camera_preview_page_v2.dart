import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:gap/gap.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:ocr_sample/detected_area.dart';
import 'package:ocr_sample/text_detector_painter.dart';
import 'package:path_provider/path_provider.dart';

class CameraPreviewPageV2 extends HookConsumerWidget {
  final Function(XFile)? onTakePicture;
  const CameraPreviewPageV2({
    super.key,
    this.onTakePicture,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usingCamera = useState<CameraDescription?>(null);
    final controller = useState<CameraController?>(null);
    final isInitializing = useState<bool>(false);
    final isInitialized = useState<bool>(false);
    final selectedImage = useState<InputImage?>(null);
    final selectedImageFile = useState<XFile?>(null);
    final recognizedText = useState<RecognizedText?>(null);
    final selectedImageSize = useState<Size?>(null);
    initialize() async {
      if (isInitializing.value || isInitialized.value) {
        return;
      }
      debugPrint('start initialize');
      isInitializing.value = true;

      final camera = await availableCameras();
      if (camera.isEmpty) {
        debugPrint('camera is empty');
        isInitialized.value = true;
        isInitializing.value = false;
      }
      final firstCamera = camera.first;
      usingCamera.value = firstCamera;

      controller.value = CameraController(
        // camera,
        firstCamera,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      // これが２回走ると、Androidでエラーになっていたので1回のみ走るように修正した
      await controller.value?.initialize();
      isInitializing.value = false;
      isInitialized.value = true;
    }

    final future = useFuture(
      useMemoized(() => initialize(), [isInitialized.value]),
    );

    final imageData = useFuture(useMemoized(() async {
      // return selectedImage.value?.readAsBytes();
      if (selectedImageFile.value != null) {
        final file = File(selectedImageFile.value!.path);
        final decodedImage =
            await decodeImageFromList(await file.readAsBytes());
        return decodedImage.width / decodedImage.height;
      }
      return null;
    }, [
      selectedImage.value,
    ]));

    useEffect(() {
      initialize();
      return () {
        controller.value?.dispose();
      };
    }, []);

    if (future.connectionState != ConnectionState.done ||
        controller.value == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return PlatformScaffold(
      iosContentPadding: true,
      appBar: PlatformAppBar(
        title: const Text('Camera Preview'),
        leading: IconButton(
          icon: Icon(context.platformIcons.back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        cupertino: (context, platform) {
          return CupertinoNavigationBarData(
            heroTag: 'camera-preview-route',
            transitionBetweenRoutes: false,
            backgroundColor: AppColors.primary,
            title: const Text('作品データ作成'),
          );
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SizedBox(
              child: selectedImage.value != null
                  ? AspectRatio(
                      aspectRatio: imageData.data ?? 1,
                      child: Image.file(File(selectedImageFile.value!.path)),
                    )
                  : CameraPreview(controller.value!),
            ),
          ),
          if (recognizedText.value != null)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: imageData.data ?? 1,
                child: CustomPaint(
                  // painter: DetectedArea(
                  //     textBlocks: recognizedText.value?.blocks ?? []),
                  painter: TextRecognizerPainter(
                    recognizedText.value!,
                    selectedImageSize.value!,
                    InputImageRotation.rotation0deg,
                    // selectedImage.value!.metadata!.size,
                    // selectedImage.value!.metadata!.rotation,
                    CameraLensDirection.back,
                  ),
                ),
                // child: Container(),
              ),
            ),
          if (selectedImage.value == null)
            _buildCaptureUI(context, controller, recognizedText, selectedImage,
                selectedImageFile, selectedImageSize),
          // else
          //   _buildRetakeOrOkButton(context, selectedImage),
        ],
      ),
    );
  }

  Positioned _buildCaptureUI(
    BuildContext context,
    ValueNotifier<CameraController?> controller,
    ValueNotifier<RecognizedText?> recognizedText,
    ValueNotifier<InputImage?> selectedImage,
    ValueNotifier<XFile?> selectedImageFile,
    ValueNotifier<Size?> selectedImageSize,
  ) {
    return Positioned(
      bottom: 0,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.3,
            width: MediaQuery.sizeOf(context).width * 0.3,
            child: PlatformIconButton(
              padding: const EdgeInsets.all(0),
              onPressed: () async {
                try {
                  final camera = controller.value;
                  if (camera == null) {
                    return;
                  }
                  final (result, file, inputImage, size) =
                      await _scanImage(context, camera);
                  debugPrint('result: ${result.text}');
                  recognizedText.value = result;
                  selectedImage.value = inputImage;
                  selectedImageFile.value = file;
                  selectedImageSize.value = size;
                } catch (e) {
                  debugPrint('error: $e');
                }
              },
              icon: const Icon(
                Icons.camera,
                color: Colors.blue,
              ),
            ),
          ),
          // const Spacer(),
        ],
      ),
    );
  }

  Positioned _buildRetakeOrOkButton(
      BuildContext context, ValueNotifier<XFile?> selectedImage) {
    return Positioned(
      height: MediaQuery.sizeOf(context).height * 0.2,
      bottom: 0,
      width: MediaQuery.sizeOf(context).width,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Gap(24),
          PlatformTextButton(
            child: const Text('再撮影'),
            onPressed: () {
              selectedImage.value = null;
            },
          ),
          const Spacer(),
          TextButton(
            child: const Text('決定'),
            onPressed: () {
              if (selectedImage.value == null) {
                return;
              }
              onTakePicture?.call(selectedImage.value!);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const Gap(24),
        ],
      ),
    );
  }

  Future<(RecognizedText, XFile, InputImage, Size)> _scanImage(
    BuildContext context,
    CameraController cameraController,
  ) async {
    // 写真を撮影する
    final pictureFile = await cameraController.takePicture();
    final file = File(pictureFile.path);
    // 撮影した写真を読み込む
    final inputImage = InputImage.fromFile(file);
    // メタデータを取得する
    final decodedImage = await decodeImageFromList(await file.readAsBytes());
    final uint8List = await file.readAsBytes();
    final size =
        Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
    final inputImageMetadata = InputImageMetadata(
      size: size,
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: decodedImage.width,
    );
    final inputImageWithMeta =
        InputImage.fromBytes(metadata: inputImageMetadata, bytes: uint8List);
    // TextRecognizerの初期化（scriptで日本語の読み取りを指定しています※androidは日本語指定は失敗するのでデフォルトで使用すること）
    final textRecognizer =
        TextRecognizer(script: TextRecognitionScript.japanese);
    // 画像から文字を読み取る（OCR処理）
    final recognizedText = await textRecognizer.processImage(inputImage);
    return (recognizedText, pictureFile, inputImage, size);
  }
}

class AppColors {
  static const black = Colors.black;
  static const primary = Colors.deepPurple;
}
