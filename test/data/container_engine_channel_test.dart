import 'package:container/data/services/container_engine_channel.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/open_page.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/security_level.dart';
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

  test('a rejected login decodes on a session and on a download result', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <Object?, Object?>{},
          'failure': 'proxyLoginRejected',
        },
      ],
    };
    expect(sessionsFromEvent(event).single.failure, RouteFailure.proxyLoginRejected);
    final download = downloadResultFromEvent(<Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-9',
      'outcome': 'failed', 'reason': 'proxyLoginRejected',
    });
    expect(download.reason, RouteFailure.proxyLoginRejected);
  });

  test('a session refused for want of a proxy override decodes as unsupported', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{},
          'failure': 'unsupported',
        },
      ],
    };
    expect(sessionsFromEvent(event).single.failure, RouteFailure.unsupported);
  });

  test('a sessions map with two pages decodes both, in order, with the opener', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'live', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
          'pages': [
            {'pageId': 'pg-1', 'openerPageId': null},
            {'pageId': 'pg-2', 'openerPageId': 'pg-1'},
          ],
        },
      ],
    };
    expect(sessionsFromEvent(event).single.pages, const [
      OpenPage(pageId: 'pg-1'),
      OpenPage(pageId: 'pg-2', openerPageId: 'pg-1'),
    ]);
  });

  test('a session map with no pages decodes none', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{},
          'failure': 'proxyUnreachable', 'pages': <Object?>[],
        },
      ],
    };
    expect(sessionsFromEvent(event).single.pages, isEmpty);
  });

  test("a session map's grants decode to their PermissionKind, unknown names dropped", () {
    Map<Object?, Object?> event(Object? grants) => <Object?, Object?>{
          'type': 'sessions',
          'sessions': [
            {
              'siteId': 's1', 'phase': 'live', 'lastActiveAt': null,
              'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
              if (grants != null) 'grants': grants,
            },
          ],
        };
    expect(sessionsFromEvent(event(['camera', 'location', 'bogus'])).single.grants,
        {PermissionKind.camera, PermissionKind.location});
    expect(sessionsFromEvent(event(null)).single.grants, isEmpty);
  });

  test('navigation, find_result, permission_request and download decode their page', () {
    final navigation = navigationFromEvent(<Object?, Object?>{
      'type': 'navigation', 'siteId': 's1', 'pageId': 'pg-2', 'url': 'https://a.example/',
    });
    final find = findResultFromEvent(<Object?, Object?>{
      'type': 'find_result', 'siteId': 's1', 'pageId': 'pg-3', 'activeMatch': 0, 'matchCount': 1,
    });
    final permission = permissionRequestFromEvent(<Object?, Object?>{
      'type': 'permission_request', 'siteId': 's1', 'pageId': 'pg-4',
      'host': 'meet.example.com', 'kind': 'microphone', 'requestId': 'r1',
    });
    final download = downloadFromEvent(<Object?, Object?>{
      'type': 'download', 'siteId': 's1', 'pageId': 'pg-5', 'fileName': 'a.pdf',
      'sizeBytes': 1, 'sourceHost': 'a.example', 'kindLabel': 'PDF', 'requestId': 'r2',
    });
    expect([navigation.pageId, find.pageId, permission.pageId, download.pageId],
        ['pg-2', 'pg-3', 'pg-4', 'pg-5']);
  });

  test('a page_opened event decodes its page and opener', () {
    final opened = pageOpenedFromEvent(<Object?, Object?>{
      'type': 'page_opened', 'siteId': 's1', 'pageId': 'pg-2', 'openerPageId': 'pg-1',
    });
    expect((opened.siteId, opened.pageId, opened.openerPageId), ('s1', 'pg-2', 'pg-1'));
  });

  test('a permission_request event decodes the pending ask', () {
    final event = <Object?, Object?>{
      'type': 'permission_request',
      'siteId': 's1', 'pageId': 'pg-1', 'host': 'meet.example.com', 'kind': 'camera',
      'requestId': 'r1',
    };
    final request = permissionRequestFromEvent(event);
    expect(request.host, 'meet.example.com');
    expect(request.kind, PermissionKind.camera);
  });

  test('a download event decodes its requestId', () {
    final event = <Object?, Object?>{
      'type': 'download',
      'siteId': 's1', 'pageId': 'pg-1', 'fileName': 'report.pdf', 'sizeBytes': 1024,
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
      'siteId': 's1', 'pageId': 'pg-1', 'fileName': 'report.pdf', 'sizeBytes': null,
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
      'type': 'navigation', 'siteId': 's1', 'pageId': 'pg-1',
      'url': 'https://forum.example.com/t/9',
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
      'type': 'find_result', 'siteId': 's1', 'pageId': 'pg-1', 'activeMatch': 2, 'matchCount': 7,
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
          'type': 'navigation', 'siteId': 's1', 'pageId': 'pg-1', 'url': 'https://a.example/x',
          'title': '', 'canGoBack': true, 'canGoForward': false,
          'loading': false, 'progress': 100,
        });
        sink.success(<String, Object?>{
          'type': 'find_result', 'siteId': 's1', 'pageId': 'pg-1', 'activeMatch': 0, 'matchCount': 3,
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

      await engine.goBack('pg-1');
      await engine.goForward('pg-1');
      await engine.stop('pg-1');
      await engine.loadUrl('pg-1', 'https://a.example/x');
      await engine.find('pg-1', 'fox');
      await engine.findNext('pg-1', forward: false);
      await engine.clearFind('pg-1');
      await engine.keep('s1');
      expect(await engine.navigationState('pg-1'), isNull);
      await engine.reload('pg-1');
      expect(await engine.extractArticle('pg-1'), isNull);

      expect(calls.map((c) => c.method), [
        'goBack', 'goForward', 'stop', 'loadUrl', 'find', 'findNext',
        'clearFind', 'keep', 'navigationState', 'reload', 'extractArticle',
      ]);
      expect(calls[0].arguments, {'pageId': 'pg-1'});
      expect(calls[3].arguments, {'pageId': 'pg-1', 'url': 'https://a.example/x'});
      expect(calls[4].arguments, {'pageId': 'pg-1', 'query': 'fox'});
      expect(calls[5].arguments, {'pageId': 'pg-1', 'forward': false});
      expect(calls[7].arguments, {'siteId': 's1'});
      expect(calls[8].arguments, {'pageId': 'pg-1'});
      expect(calls[9].arguments, {'pageId': 'pg-1'});
      expect(calls[10].arguments, {'pageId': 'pg-1'});
    });

    test('revokeGrant sends the site and the kind by name', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return null;
      });
      final engine = ChannelContainerEngine();

      await engine.revokeGrant('s1', PermissionKind.microphone);

      expect(calls.single.method, 'revokeGrant');
      expect(calls.single.arguments, {'siteId': 's1', 'kind': 'microphone'});
    });

    test('close, closePage and closeAll send what Kotlin reads', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return null;
      });
      final engine = ChannelContainerEngine();

      await engine.close('s1');
      await engine.close('s1', wipe: true);
      await engine.close('s1', wipe: false);
      await engine.closePage('pg-2');
      await engine.closeAll();

      expect(calls.map((c) => c.method), ['close', 'close', 'close', 'closePage', 'closeAll']);
      // No `wipe` key leaves it to the session's own wipe-on-exit.
      expect(calls[0].arguments, {'siteId': 's1'});
      expect(calls[1].arguments, {'siteId': 's1', 'wipe': true});
      expect(calls[2].arguments, {'siteId': 's1', 'wipe': false});
      expect(calls[3].arguments, {'pageId': 'pg-2'});
      expect(calls[4].arguments, isNull);
    });

    test('a page_opened event reaches its own stream', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, sink) {
        sink.success(<String, Object?>{
          'type': 'page_opened', 'siteId': 's1', 'pageId': 'pg-2', 'openerPageId': 'pg-1',
        });
      }));
      final engine = ChannelContainerEngine();

      final opened = await engine.pageOpened().first;

      expect((opened.siteId, opened.pageId, opened.openerPageId), ('s1', 'pg-2', 'pg-1'));
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

    test('open sends the typed address apart from the stored url', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return <String, Object?>{
          'siteId': 's1', 'phase': 'opening', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
        };
      });
      const site = Site(
        id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p',
      );

      await ChannelContainerEngine().open(site, initialUrl: 'https://forum.example.com/t/9');
      await ChannelContainerEngine().open(site);

      final args = [for (final c in calls) c.arguments as Map<Object?, Object?>];
      expect(args.map((a) => a['initialUrl']), ['https://forum.example.com/t/9', null]);
      expect(args.map((a) => a['url']), ['https://forum.example.com', 'https://forum.example.com']);
    });

    test('open sends the proxy login and the per-site choice', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return <String, Object?>{
          'siteId': 's1', 'phase': 'opening', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
        };
      });
      const typed = Site(
        id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p',
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        proxyUser: 'alice', proxyPassword: 's3cret',
      );

      await ChannelContainerEngine().open(typed);
      await ChannelContainerEngine().open(typed.copyWith(proxyLoginPerSite: true));

      final args = [for (final c in calls) c.arguments as Map<Object?, Object?>];
      expect(args.first['proxyUser'], 'alice');
      expect(args.first['proxyPassword'], 's3cret');
      expect(args.map((a) => a['proxyLoginPerSite']), [false, true]);
    });

    test('open sends the effective security level', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return <String, Object?>{
          'siteId': 's1', 'phase': 'opening', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
        };
      });
      const site = Site(
        id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p',
      );

      await ChannelContainerEngine().open(site,
          extras: const EngineExtras(securityLevel: SecurityLevel.safer));
      await ChannelContainerEngine().open(site);

      final args = [for (final c in calls) c.arguments as Map<Object?, Object?>];
      expect(args.map((a) => a['securityLevel']), ['safer', 'standard']);
    });
  });
}
