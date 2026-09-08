import 'package:container/data/services/container_engine_channel.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
