import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// The native WebView behind spec `2b`'s page area — what
/// [ContainerScreen.body] is given on a device.
///
/// It carries only the page id, which its own container's `open` returned
/// (tabs spec §3.2). Everything else about the site was registered by
/// `ContainerEngine.open`, and re-sending it here would let the view and the
/// session disagree about the same site, so the platform refuses a view for a
/// page it does not hold rather than inventing a config for it.
class ContainerWebView extends StatelessWidget {
  const ContainerWebView({super.key, required this.pageId});

  static const viewType = 'com.mono.container/view';

  final String pageId;

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        // The page owns every gesture inside its own rectangle; the chrome
        // around it is Flutter's.
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: <String, Object?>{'pageId': pageId},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
