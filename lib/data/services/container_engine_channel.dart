import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/held_download.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/route_decision.dart';
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

RouteFailure? _failure(String? name) => switch (name) {
      'proxyUnreachable' => RouteFailure.proxyUnreachable,
      'proxyRefused' => RouteFailure.proxyRefused,
      'upstreamTimeout' => RouteFailure.upstreamTimeout,
      'tlsFailure' => RouteFailure.tlsFailure,
      'misconfigured' => RouteFailure.misconfigured,
      _ => null,
    };

BlockedCategory? _category(String name) => switch (name) {
      'trackers' => BlockedCategory.trackers,
      'ads' => BlockedCategory.ads,
      'fingerprinting' => BlockedCategory.fingerprinting,
      'permissionAsks' => BlockedCategory.permissionAsks,
      _ => null,
    };

PermissionKind _kind(String name) => switch (name) {
      'microphone' => PermissionKind.microphone,
      'location' => PermissionKind.location,
      'clipboard' => PermissionKind.clipboard,
      _ => PermissionKind.camera,
    };

Map<BlockedCategory, int> _categoryCountsFrom(Object? raw) {
  final map = (raw as Map<Object?, Object?>?) ?? const {};
  final result = <BlockedCategory, int>{};
  for (final entry in map.entries) {
    final category = _category(entry.key! as String);
    if (category != null) result[category] = entry.value as int;
  }
  return result;
}

ContainerSession _sessionFrom(Map<Object?, Object?> map) => ContainerSession(
      siteId: map['siteId']! as String,
      phase: _phase(map['phase']! as String),
      lastActiveAt: map['lastActiveAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt']! as int),
      blockedCount: (map['blockedCount'] as int?) ?? 0,
      categoryCounts: _categoryCountsFrom(map['categoryCounts']),
      failure: _failure(map['failure'] as String?),
    );

/// Exposed for testing — decodes a `type: "sessions"` event's payload.
List<ContainerSession> sessionsFromEvent(Map<Object?, Object?> event) =>
    (event['sessions']! as List<Object?>)
        .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
        .toList();

/// Exposed for testing — decodes a `type: "permission_request"` event.
PendingPermissionRequest permissionRequestFromEvent(Map<Object?, Object?> event) =>
    PendingPermissionRequest(
      siteId: event['siteId']! as String,
      host: event['host']! as String,
      kind: _kind(event['kind']! as String),
      requestId: event['requestId']! as String,
    );

/// Exposed for testing — decodes a `type: "download"` event.
HeldDownloadEvent downloadFromEvent(Map<Object?, Object?> event) => HeldDownloadEvent(
      siteId: event['siteId']! as String,
      download: HeldDownload(
        fileName: event['fileName']! as String,
        sizeBytes: event['sizeBytes']! as int,
        sourceHost: event['sourceHost']! as String,
        kindLabel: event['kindLabel']! as String,
      ),
    );

/// Exposed for testing — decodes a `type: "tunnel_dropped"` event.
TunnelDroppedEvent tunnelDroppedFromEvent(Map<Object?, Object?> event) => TunnelDroppedEvent(
      siteId: event['siteId']! as String,
      host: event['host']! as String,
      droppedAt: DateTime.fromMillisecondsSinceEpoch(event['droppedAtMs']! as int),
    );

class ChannelContainerEngine implements ContainerEngine {
  ChannelContainerEngine() {
    _events.receiveBroadcastStream().listen((event) {
      final map = event as Map<Object?, Object?>;
      switch (map['type']) {
        case 'permission_request':
          _permissionController.add(permissionRequestFromEvent(map));
        case 'download':
          _downloadController.add(downloadFromEvent(map));
        case 'tunnel_dropped':
          _tunnelDroppedController.add(tunnelDroppedFromEvent(map));
        default:
          _sessionsController.add(sessionsFromEvent(map));
      }
    });
  }

  final _sessionsController = StreamController<List<ContainerSession>>.broadcast();
  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();

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
  Stream<List<ContainerSession>> sessions() => _sessionsController.stream;

  @override
  Future<List<ContainerSession>> liveSessions() async {
    final result = await _method.invokeListMethod<Object?>('liveSessions');
    return (result ?? const <Object?>[])
        .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Stream<PendingPermissionRequest> permissionRequests() => _permissionController.stream;

  @override
  Future<void> resolvePermission(String requestId, PermissionDecision decision) =>
      _method.invokeMethod('resolvePermission', {
        'requestId': requestId,
        'decision': decision.name,
      });

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  @override
  Future<ReaderArticle?> extractArticle(String siteId) async {
    final result = await _method
        .invokeMapMethod<Object?, Object?>('extractArticle', {'siteId': siteId});
    if (result == null) return null;
    return ReaderArticle(
      host: result['host']! as String,
      title: result['title']! as String,
      paragraphs: (result['paragraphs']! as List<Object?>).cast<String>(),
      minutesToRead: result['minutesToRead']! as int,
    );
  }
}
