import 'models/navigation_state.dart';
import 'models/open_container.dart';
import 'models/site.dart';
import 'models/switcher_entry.dart';

/// `2c`'s background age (user's ruling, 2026-10-02): `now` under a minute,
/// `N min` under an hour, then `N h` — `1a`'s units. A [then] in the future
/// (a clock change) reads as `now`.
String backgroundAge(DateTime now, DateTime then) {
  final elapsed = now.difference(then);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} min';
  return '${elapsed.inHours} h';
}

/// Tabs spec §5.7: what closes an open container when saved — its route
/// (mode, host, port and Plan 14's login) or its cookie policy. Nothing else.
bool routeOrCookiePolicyChanged(Site before, Site after) =>
    before.proxyMode != after.proxyMode ||
    before.proxyHost != after.proxyHost ||
    before.proxyPort != after.proxyPort ||
    before.proxyUser != after.proxyUser ||
    before.proxyPassword != after.proxyPassword ||
    before.proxyLoginPerSite != after.proxyLoginPerSite ||
    before.cookiePolicy != after.cookiePolicy;

/// Where system back goes from a page with nothing to leave in the chrome
/// (tabs spec §5.3).
sealed class BackTarget {
  const BackTarget();
}

/// The page has history.
class BackInPage extends BackTarget {
  const BackInPage();
}

/// Close this page and show [openerPageId], in the same container.
class ClosePageToOpener extends BackTarget {
  const ClosePageToOpener(this.openerPageId);
  final String openerPageId;
}

/// A saved container's first page: the dashboard, the container left open.
class LeaveToDashboard extends BackTarget {
  const LeaveToDashboard();
}

/// A throwaway's first page: show [siteId]'s container.
class ViewContainer extends BackTarget {
  const ViewContainer(this.siteId);
  final String siteId;
}

/// A throwaway with nothing else open: closed, wiped, dashboard.
class CloseThrowawayToDashboard extends BackTarget {
  const CloseThrowawayToDashboard();
}

/// [others] is every other listed open container's last-viewed time, by
/// site id.
BackTarget backTarget({
  required bool canGoBack,
  required OpenContainer container,
  required String pageId,
  required Map<String, DateTime> others,
}) {
  if (canGoBack) return const BackInPage();
  final opener = container.page(pageId)?.openerPageId;
  if (opener != null && container.page(opener) != null) return ClosePageToOpener(opener);
  if (!container.throwaway) return const LeaveToDashboard();
  final openerSite = container.openerSiteId;
  if (openerSite != null && others.containsKey(openerSite)) return ViewContainer(openerSite);
  final recent = mostRecent(others);
  return recent == null ? const CloseThrowawayToDashboard() : ViewContainer(recent);
}

/// The key with the latest time, or null for an empty map.
String? mostRecent(Map<String, DateTime> times) {
  String? best;
  DateTime? bestAt;
  for (final entry in times.entries) {
    if (bestAt == null || entry.value.isAfter(bestAt)) {
      best = entry.key;
      bestAt = entry.value;
    }
  }
  return best;
}

/// `2c`'s rows (tabs spec §5.1): the viewed container first, then the rest,
/// most recently viewed first; only listed containers; page rows only under a
/// container with two or more pages, in opening order.
List<SwitcherEntry> switcherEntries({
  required List<OpenContainer> containers,
  required String? viewedSiteId,
  required Map<String, NavigationState> navigation,
  required DateTime now,
}) {
  final listed = [for (final c in containers) if (c.listed) c];
  listed.sort((a, b) {
    if (a.siteId == viewedSiteId) return -1;
    if (b.siteId == viewedSiteId) return 1;
    return b.lastViewedAt.compareTo(a.lastViewedAt);
  });
  return [
    for (final c in listed)
      SwitcherEntry(
        siteId: c.siteId,
        name: c.opened.name,
        monogram: c.opened.monogram,
        meta: c.siteId == viewedSiteId
            ? 'viewing now · ${c.opened.proxyMode.name}'
            : 'background · ${backgroundAge(now, c.lastViewedAt)}',
        live: c.siteId == viewedSiteId,
        pages: c.pages.length < 2
            ? const []
            : [
                for (final page in c.pages)
                  _pageRow(page.pageId, navigation[page.pageId], c,
                      current: page.pageId == c.viewedPageId),
              ],
      ),
  ];
}

SwitcherPage _pageRow(String pageId, NavigationState? nav, OpenContainer c,
    {required bool current}) {
  final pageHost = nav?.host ?? '';
  final host = pageHost.isEmpty ? c.opened.host : pageHost;
  final title = nav?.title.trim() ?? '';
  return SwitcherPage(
    pageId: pageId,
    title: title.isEmpty ? host : title,
    host: host,
    current: current,
  );
}
