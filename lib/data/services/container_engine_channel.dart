import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/models/container_session.dart';
import '../../domain/models/site.dart';
import 'container_engine.dart';

const _method = MethodChannel('com.mono.container/engine');
const _events = EventChannel('com.mono.container/sessions');

SessionPhase _phase(String name) => switch (name) {
      'opening' => SessionPhase.opening,
      'background' => SessionPhase.background,
      'refused' => SessionPhase.refused,
      _ => SessionPhase.live,
    };

ContainerSession _sessionFrom(Map<Object?, Object?> map) => ContainerSession(
      siteId: map['siteId']! as String,
      phase: _phase(map['phase']! as String),
      lastActiveAt: map['lastActiveAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt']! as int),
      blockedCount: (map['blockedCount'] as int?) ?? 0,
    );

class ChannelContainerEngine implements ContainerEngine {
  @override
  Future<bool> isolationAvailable() async =>
      await _method.invokeMethod<bool>('isolationAvailable') ?? false;

  @override
  Future<ContainerSession> open(Site site) async {
    final result = await _method.invokeMapMethod<Object?, Object?>('open', {
      'siteId': site.id,
      'profileId': site.profileId,
      'url': site.url,
      'proxyMode': site.proxyMode.name,
      'proxyHost': site.proxyHost,
      'proxyPort': site.proxyPort,
      'blockWebRtc': site.blockWebRtc,
      'blockTrackers': site.blockTrackers,
      'antiFingerprinting': site.antiFingerprinting,
      'allowCamera': site.allowCamera,
      'allowMicrophone': site.allowMicrophone,
      'allowLocation': site.allowLocation,
      'allowClipboard': site.allowClipboard,
      'userAgentMode': site.userAgentMode.name,
      'forceDark': site.forceDark,
      'pageZoom': site.pageZoom,
      'customCss': site.customCss,
      'customJs': site.customJs,
      'wipeOnExit': site.cookiePolicy == CookiePolicy.wipeOnExit,
    });
    return _sessionFrom(result!);
  }

  @override
  Future<void> wipe(String profileId) =>
      _method.invokeMethod('wipe', {'profileId': profileId});

  @override
  Future<void> wipeAll() => _method.invokeMethod('wipeAll');

  @override
  Future<void> close(String siteId) =>
      _method.invokeMethod('close', {'siteId': siteId});

  @override
  Future<void> reload(String siteId) =>
      _method.invokeMethod('reload', {'siteId': siteId});

  @override
  Stream<List<ContainerSession>> sessions() =>
      _events.receiveBroadcastStream().map((event) => (event as List<Object?>)
          .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
          .toList());

  @override
  Future<List<ContainerSession>> liveSessions() async {
    final result = await _method.invokeListMethod<Object?>('liveSessions');
    return (result ?? const <Object?>[])
        .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
        .toList();
  }
}
