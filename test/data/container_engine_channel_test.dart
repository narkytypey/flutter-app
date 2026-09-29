import 'package:container/data/services/container_engine_channel.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a sessions event decodes category counts', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1',
          'phase': 'live',
          'lastActiveAt': null,
          'blockedCount': 9,
          'categoryCounts': {'trackers': 6, 'ads': 3},
          'failure': null,
        },
      ],
    };
    final sessions = sessionsFromEvent(event);
    expect(sessions.single.categoryCounts[BlockedCategory.trackers], 6);
    expect(sessions.single.categoryCounts[BlockedCategory.ads], 3);
  });

  test('a refused session decodes its failure reason', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{},
          'failure': 'proxyUnreachable',
        },
      ],
    };
    expect(sessionsFromEvent(event).single.failure, RouteFailure.proxyUnreachable);
  });

  test('a permission_request event decodes the pending ask', () {
    final event = <Object?, Object?>{
      'type': 'permission_request',
      'siteId': 's1', 'host': 'meet.example.com', 'kind': 'camera',
      'requestId': 'r1',
    };
    final request = permissionRequestFromEvent(event);
    expect(request.host, 'meet.example.com');
    expect(request.kind, PermissionKind.camera);
  });

  test('a download event decodes its requestId', () {
    final event = <Object?, Object?>{
      'type': 'download',
      'siteId': 's1', 'fileName': 'report.pdf', 'sizeBytes': 1024,
      'sourceHost': 'forum.example.com', 'kindLabel': 'PDF',
      'requestId': 'r1',
    };
    final download = downloadFromEvent(event);
    expect(download.requestId, 'r1');
    expect(download.download.fileName, 'report.pdf');
  });

  test('a download event with no size decodes it as unknown', () {
    final event = <Object?, Object?>{
      'type': 'download',
      'siteId': 's1', 'fileName': 'report.pdf', 'sizeBytes': null,
      'sourceHost': 'forum.example.com', 'kindLabel': 'PDF',
      'requestId': 'r1',
    };
    expect(downloadFromEvent(event).download.sizeBytes, isNull);
  });

  test('a download_result event decodes a saved outcome', () {
    final event = <Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-1',
      'outcome': 'saved', 'reason': null,
    };
    final result = downloadResultFromEvent(event);
    expect(result.requestId, 'req-1');
    expect(result.outcome, DownloadOutcome.saved);
    expect(result.reason, isNull);
  });

  test('a download_result event decodes a kept outcome', () {
    final event = <Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-2',
      'outcome': 'kept', 'reason': null,
    };
    expect(downloadResultFromEvent(event).outcome, DownloadOutcome.kept);
  });

  test('a download_result event decodes a failed outcome with its reason', () {
    final event = <Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-3',
      'outcome': 'failed', 'reason': 'proxyUnreachable',
    };
    final result = downloadResultFromEvent(event);
    expect(result.outcome, DownloadOutcome.failed);
    expect(result.reason, RouteFailure.proxyUnreachable);
  });

  test('a navigation event decodes every field the chrome reads', () {
    final state = navigationFromEvent(<Object?, Object?>{
      'type': 'navigation', 'siteId': 's1', 'url': 'https://forum.example.com/t/9',
      'title': 'Thread', 'canGoBack': true, 'canGoForward': false,
      'loading': true, 'progress': 40,
    });
    expect(state.siteId, 's1');
    expect(state.url, 'https://forum.example.com/t/9');
    expect(state.host, 'forum.example.com');
    expect(state.title, 'Thread');
    expect(state.canGoBack, isTrue);
    expect(state.canGoForward, isFalse);
    expect(state.loading, isTrue);
    expect(state.progress, 40);
  });

  test('a find_result event decodes its counts', () {
    final result = findResultFromEvent(<Object?, Object?>{
      'type': 'find_result', 'siteId': 's1', 'activeMatch': 2, 'matchCount': 7,
    });
    expect((result.siteId, result.activeMatch, result.matchCount), ('s1', 2, 7));
  });

  group('over the channels', () {
    const methods = MethodChannel('com.mono.container/engine');
    const events = EventChannel('com.mono.container/sessions');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(events, null);
    });

    // Every event type the listener did not know fell through to the
    // sessions decoder, which throws on a map with no `sessions` key.
    test('navigation and find events reach their own streams', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, sink) {
        sink.success(<String, Object?>{
          'type': 'navigation', 'siteId': 's1', 'url': 'https://a.example/x',
          'title': '', 'canGoBack': true, 'canGoForward': false,
          'loading': false, 'progress': 100,
        });
        sink.success(<String, Object?>{
          'type': 'find_result', 'siteId': 's1', 'activeMatch': 0, 'matchCount': 3,
        });
      }));
      final engine = ChannelContainerEngine();
      final navigation = engine.navigation().first;
      final find = engine.findResults().first;

      expect((await navigation).canGoBack, isTrue);
      expect((await find).matchCount, 3);
    });

    test('the page controls reach the platform under the names Kotlin handles', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return null;
      });
      final engine = ChannelContainerEngine();

      await engine.goBack('s1');
      await engine.goForward('s1');
      await engine.stop('s1');
      await engine.loadUrl('s1', 'https://a.example/x');
      await engine.find('s1', 'fox');
      await engine.findNext('s1', forward: false);
      await engine.clearFind('s1');
      await engine.keep('s1');
      expect(await engine.navigationState('s1'), isNull);

      expect(calls.map((c) => c.method), [
        'goBack', 'goForward', 'stop', 'loadUrl', 'find', 'findNext',
        'clearFind', 'keep', 'navigationState',
      ]);
      expect(calls[3].arguments, {'siteId': 's1', 'url': 'https://a.example/x'});
      expect(calls[4].arguments, {'siteId': 's1', 'query': 'fox'});
      expect(calls[5].arguments, {'siteId': 's1', 'forward': false});
    });

    test('open says whether the site is a throwaway', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return <String, Object?>{
          'siteId': 't1', 'phase': 'opening', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
        };
      });
      const site = Site(
        id: 't1', workspaceId: 'w', name: 'news.example.org', monogram: 'Nw',
        url: 'https://news.example.org', profileId: 'p',
      );

      await ChannelContainerEngine().open(site, throwaway: true);
      await ChannelContainerEngine().open(site);

      expect(calls.map((c) => (c.arguments as Map<Object?, Object?>)['throwaway']),
          [true, false]);
    });
  });
}
