import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/container_session.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/open_page.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(String id) => Site(
      id: id, workspaceId: 'w', name: id, monogram: 'Xx',
      url: 'https://$id.example.com', profileId: 'p-$id',
    );

void main() {
  test('page ids are never reused across opens', () async {
    final engine = FakeContainerEngine();

    final first = await engine.open(_site('s1'));
    await engine.close('s1');
    final second = await engine.open(_site('s1'));

    expect(first.pages, const [OpenPage(pageId: 's1-p1')]);
    expect(second.pages, const [OpenPage(pageId: 's1-p2')]);
    expect(engine.firstPageOf('s1'), 's1-p2');
    final linked = engine.openPageFromLink('s1', openerPageId: 's1-p2');
    expect(linked, 's1-p3');
  });

  test('a refused open has no page', () async {
    final engine = FakeContainerEngine(proxyReachable: false);
    final site = _site('s1').copyWith(
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050);

    final session = await engine.open(site);

    expect(session.phase, SessionPhase.refused);
    expect(session.pages, isEmpty);
  });

  test('a page opened from a link reports PageOpened, then the sessions list', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('s1'));
    final seen = <Object>[];
    final pageSub = engine.pageOpened().listen(seen.add);
    final sessionSub = engine.sessions().listen(seen.add);

    final pageId = engine.openPageFromLink('s1', openerPageId: 's1-p1');
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(2));
    final opened = seen.first as PageOpened;
    expect((opened.siteId, opened.pageId, opened.openerPageId), ('s1', pageId, 's1-p1'));
    final sessions = seen.last as List<ContainerSession>;
    expect(sessions.single.pages, [
      const OpenPage(pageId: 's1-p1'),
      OpenPage(pageId: pageId, openerPageId: 's1-p1'),
    ]);
    await pageSub.cancel();
    await sessionSub.cancel();
  });

  test('closePage on one of two pages leaves the session', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('s1'));
    final second = engine.openPageFromLink('s1', openerPageId: 's1-p1');

    await engine.closePage('s1-p1');

    expect(engine.closedPages, ['s1-p1']);
    expect(engine.closed, isEmpty);
    expect(engine.pagesOf('s1'), [OpenPage(pageId: second, openerPageId: 's1-p1')]);
  });

  test('closePage on the last page closes the session', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('s1'));

    await engine.closePage('s1-p1');

    expect(engine.closedPages, ['s1-p1']);
    expect(engine.closed, ['s1']);
    expect(await engine.liveSessions(), isEmpty);
  });

  test('close records its wipe argument', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('s1'));
    await engine.open(_site('s2'));

    await engine.close('s1', wipe: true);
    await engine.close('s2');

    expect(engine.closedWith, {'s1': true, 's2': null});
  });

  test('closeAll closes every session and counts once', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('s1'));
    await engine.open(_site('s2'));
    engine.seedBackground('s3');

    await engine.closeAll();

    expect(engine.closedAll, 1);
    expect(engine.closed, unorderedEquals(['s1', 's2', 's3']));
    expect(await engine.liveSessions(), isEmpty);
  });

  test('the in-page controls record page ids', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('s1'));
    final page = engine.firstPageOf('s1');

    await engine.reload(page);
    await engine.goBack(page);
    await engine.loadUrl(page, 'https://s1.example.com/a');

    expect(engine.reloaded, ['s1-p1']);
    expect(engine.wentBack, ['s1-p1']);
    expect(engine.loaded, [(pageId: 's1-p1', url: 'https://s1.example.com/a')]);
  });
}
