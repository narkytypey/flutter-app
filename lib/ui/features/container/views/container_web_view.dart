import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide PageView;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// One page of a container (tabs spec §3.1): the native WebView behind spec
/// `2b`'s page area — what [ContainerScreen.body] is given on a device.
///
/// The page outlives this view. Disposing it only detaches the page's
/// WebView and pauses it; building another for the same page attaches it
/// again, with nothing lost. Only `closePage`, `close` and `closeAll` destroy
/// a page.
///
/// It carries only the page id, which its own container's `open` returned or
/// `page_opened` reported (tabs spec §3.2). Everything else about the site was
/// registered by `ContainerEngine.open`, and re-sending it here would let the
/// view and the session disagree about the same site, so the platform refuses
/// a view for a page it does not hold rather than inventing a config for it.
///
/// Shares its name with Flutter's own `PageView`: a file using both imports
/// `package:flutter/material.dart` with `hide PageView`.
class PageView extends StatelessWidget {
  const PageView({super.key, required this.pageId});

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
