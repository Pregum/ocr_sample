import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class CameraPreviewPage extends HookConsumerWidget {
  final Function(XFile)? onTakePicture;
  const CameraPreviewPage({
    super.key,
    this.onTakePicture,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usingCamera = useState<CameraDescription?>(null);
    final controller = useState<CameraController?>(null);
    final isInitializing = useState<bool>(false);
    final isInitialized = useState<bool>(false);
    final selectedImage = useState<XFile?>(null);
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

    useEffect(() {
      initialize();
      return () {
        controller.value?.dispose();
      };
    }, []);

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
        body: switch ((future.connectionState, controller.value)) {
          (
            ConnectionState.done || ConnectionState.active,
            CameraController? val
          )
              when val != null =>
            Column(
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.7,
                  width: MediaQuery.sizeOf(context).width,
                  child: selectedImage.value != null
                      ? Image.file(File(selectedImage.value!.path))
                      : CameraPreview(val),
                ),
                if (selectedImage.value == null)
                  Expanded(
                    child: Container(
                      color: AppColors.black,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.3,
                            width: MediaQuery.sizeOf(context).width * 0.3,
                            child: PlatformIconButton(
                              padding: const EdgeInsets.all(0),
                              onPressed: () async {
                                try {
                                  final path = [
                                    (await getTemporaryDirectory()).path,
                                    '${DateTime.now().toIso8601String()}.png'
                                  ].join('/');
                                  debugPrint('tmp path: $path');

                                  final file =
                                      await controller.value?.takePicture();
                                  debugPrint('file.path: ${file?.path}');
                                  if (file == null) {
                                    return;
                                  }
                                  selectedImage.value = file;
                                  // File imageFile = File(path);
                                } catch (e) {
                                  debugPrint('error: $e');
                                }
                              },
                              icon: Icon(
                                Icons.camera,
                                size: min(
                                    MediaQuery.sizeOf(context).height * 0.3,
                                    MediaQuery.sizeOf(context).width * 0.3),
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      color: AppColors.black,
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
                    ),
                  )
              ],
            ),
          (_, _) => const Center(child: CircularProgressIndicator.adaptive()),
        });
  }
}

class AppColors {
  static const black = Colors.black;
  static const primary = Colors.deepPurple;
}
