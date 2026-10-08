import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/permissions_in_use.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/features/in_page/views/site_sheet.dart';

void main() {
  Widget host({
    bool forceDark = true,
    bool desktopView = false,
    VoidCallback? onEdit,
    ValueChanged<bool>? onForceDarkChanged,
    ValueChanged<bool>? onDesktopViewChanged,
    VoidCallback? onCloseAndWipe,
    String securityLevelValue = 'Standard · default',
    VoidCallback? onSecurityLevel,
    Map<BlockedCategory, int> categoryCounts = const {},
    int blockedCount = 164,
    VoidCallback? onProxy,
    bool blockWebRtc = true,
    bool lockWebRtc = false,
    bool blockTrackers = true,
    bool antiFingerprinting = true,
    ValueChanged<bool>? onBlockWebRtcChanged,
    ValueChanged<bool>? onBlockTrackersChanged,
    ValueChanged<bool>? onAntiFingerprintingChanged,
    List<PermissionInUse> permissions = const [],
    ValueChanged<PermissionKind>? onRevoke,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SiteSheet(
          monogram: 'Fr',
          name: 'Forum',
          subtitle: 'forum.example.com · Personal',
          proxyDescriptor: 'SOCKS5 · 127.0.0.1:9050',
          onProxy: onProxy ?? () {},
          cookiesDescriptor: 'Wipe on exit',
          blockedCount: blockedCount,
          forceDark: forceDark,
          desktopView: desktopView,
          onEdit: onEdit ?? () {},
          onForceDarkChanged: onForceDarkChanged ?? (_) {},
          onDesktopViewChanged: onDesktopViewChanged ?? (_) {},
          onCloseAndWipe: onCloseAndWipe ?? () {},
          securityLevelValue: securityLevelValue,
          onSecurityLevel: onSecurityLevel ?? () {},
          categoryCounts: categoryCounts,
          blockWebRtc: blockWebRtc,
          blockTrackers: blockTrackers,
          antiFingerprinting: antiFingerprinting,
          onBlockWebRtcChanged: lockWebRtc ? null : (onBlockWebRtcChanged ?? (_) {}),
          onBlockTrackersChanged: onBlockTrackersChanged ?? (_) {},
          onAntiFingerprintingChanged: onAntiFingerprintingChanged ?? (_) {},
          permissions: permissions,
          onRevoke: onRevoke ?? (_) {},
        ),
      ),
    );
  }

  // User's ruling 2026-10-08: `6c` is reached by tapping the pill's shield,
  // so it leads with protection. The four rows the canvas itself draws
  // (Proxy, Cookies, Force dark mode, Desktop view) stay together, in the
  // canvas's order, below them.
  testWidgets('6c leads with protection, then the container rows', (tester) async {
    await tester.pumpWidget(host(permissions: const [
      PermissionInUse(PermissionKind.camera, whileOpen: true),
    ]));

    double y(String label) => tester.getTopLeft(find.text(label)).dy;

    for (final (above, below) in const [
      ('Security level', 'Blocked here'),
      ('Blocked here', 'Block WebRTC'),
      ('Block WebRTC', 'Block trackers and ads'),
      ('Block trackers and ads', 'Anti-fingerprinting'),
      ('Anti-fingerprinting', 'Proxy'),
      ('Proxy', 'Cookies'),
      ('Cookies', 'Force dark mode'),
      ('Force dark mode', 'Desktop view'),
      ('Desktop view', 'Camera'),
      ('Camera', 'Close and wipe this session'),
    ]) {
      expect(y(above), lessThan(y(below)), reason: '$above must sit above $below');
    }
  });

  // User's ruling 2026-10-05: the route can change while browsing.
  testWidgets('a tap on the Proxy row reports it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onProxy: () => taps++));
    await tester.tap(find.text('Proxy'));
    await tester.tap(find.text('SOCKS5 · 127.0.0.1:9050'));
    expect(taps, 2);
  });

  // User's ruling 2026-10-05: one request reads singular.
  testWidgets('one blocked request reads "1 request"', (tester) async {
    await tester.pumpWidget(host(blockedCount: 1));
    expect(find.text('1 request'), findsOneWidget);
  });

  // Built-in Tor spec 5.4.
  testWidgets('a locked Block WebRTC is drawn on and inert', (tester) async {
    await tester.pumpWidget(host(blockWebRtc: true, lockWebRtc: true));

    final toggle = tester.widget<AppToggle>(find.descendant(
      of: find.ancestor(of: find.text('Block WebRTC'), matching: find.byType(Row)).first,
      matching: find.byType(AppToggle),
    ));
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNull);
  });

  testWidgets('renders the spec copy and values verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('sheet-handle')), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('SOCKS5 · 127.0.0.1:9050'), findsOneWidget);
    expect(find.text('Cookies'), findsOneWidget);
    expect(find.text('Wipe on exit'), findsOneWidget);
    expect(find.text('Blocked here'), findsOneWidget);
    expect(find.text('164 requests'), findsOneWidget);
    expect(find.text('Force dark mode'), findsOneWidget);
    expect(find.text('Desktop view'), findsOneWidget);
    expect(find.text('Close and wipe this session'), findsOneWidget);
  });

  testWidgets('Edit reports a tap', (tester) async {
    var edits = 0;
    await tester.pumpWidget(host(onEdit: () => edits++));
    await tester.tap(find.text('Edit'));
    expect(edits, 1);
  });

  testWidgets('each toggle reports its new value, not just that it changed', (tester) async {
    bool? forceDarkSeen;
    bool? desktopViewSeen;
    await tester.pumpWidget(host(
      forceDark: true,
      desktopView: false,
      onForceDarkChanged: (v) => forceDarkSeen = v,
      onDesktopViewChanged: (v) => desktopViewSeen = v,
    ));

    final forceDarkRow = find.ancestor(
      of: find.text('Force dark mode'),
      matching: find.byType(Row),
    ).first;
    final desktopViewRow = find.ancestor(
      of: find.text('Desktop view'),
      matching: find.byType(Row),
    ).first;

    // Tap the toggle by its own type, never by whatever it happens to be
    // built from. `AppToggle` is Plan 2's widget; a test reaching for its
    // inner `GestureDetector` passes today and breaks the moment Plan 2
    // rebuilds it on an `InkWell` — failing here, looking like a bug here.
    // The sheet scrolls now, so each row is brought into view first.
    await tester.ensureVisible(forceDarkRow);
    await tester.tap(find.descendant(of: forceDarkRow, matching: find.byType(AppToggle)));
    await tester.ensureVisible(desktopViewRow);
    await tester.tap(find.descendant(of: desktopViewRow, matching: find.byType(AppToggle)));

    expect(forceDarkSeen, isFalse); // was on, tapped once -> off
    expect(desktopViewSeen, isTrue); // was off, tapped once -> on
  });

  testWidgets("a tap on a switch row's label toggles it", (tester) async {
    // Only the switch itself toggled (seen on the emulator 2026-10-05).
    final seen = <String, bool>{};
    await tester.pumpWidget(host(
      onBlockWebRtcChanged: (v) => seen['webrtc'] = v,
      onBlockTrackersChanged: (v) => seen['trackers'] = v,
      onAntiFingerprintingChanged: (v) => seen['fingerprinting'] = v,
      onForceDarkChanged: (v) => seen['dark'] = v,
      onDesktopViewChanged: (v) => seen['desktop'] = v,
    ));

    for (final label in [
      'Block WebRTC',
      'Block trackers and ads',
      'Anti-fingerprinting',
      'Force dark mode',
      'Desktop view',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }

    expect(seen, {
      'webrtc': false,
      'trackers': false,
      'fingerprinting': false,
      'dark': false,
      'desktop': true,
    });
  });

  testWidgets("a locked Block WebRTC's label does nothing", (tester) async {
    await tester.pumpWidget(host(blockWebRtc: true, lockWebRtc: true));
    await tester.ensureVisible(find.text('Block WebRTC'));
    await tester.tap(find.text('Block WebRTC'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Close and wipe reports a tap', (tester) async {
    var wiped = 0;
    await tester.pumpWidget(host(onCloseAndWipe: () => wiped++));
    await tester.ensureVisible(find.text('Close and wipe this session'));
    await tester.tap(find.text('Close and wipe this session'));
    expect(wiped, 1);
  });

  testWidgets('the security level row shows its value and opens the picker', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(securityLevelValue: 'Safer', onSecurityLevel: () => taps++));
    expect(find.text('Security level'), findsOneWidget);
    expect(find.text('Safer'), findsOneWidget);
    await tester.tap(find.text('Security level'));
    expect(taps, 1);
  });

  testWidgets("blocked categories with a count above 0 are listed in 5c's order and words",
      (tester) async {
    await tester.pumpWidget(host(categoryCounts: const {
      BlockedCategory.ads: 30, BlockedCategory.trackers: 120, BlockedCategory.fingerprinting: 0,
    }));
    expect(find.text('Trackers'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Ads'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Fingerprinting'), findsNothing);
    expect(find.text('Permission asks'), findsNothing);
    expect(tester.getTopLeft(find.text('Trackers')).dy,
        lessThan(tester.getTopLeft(find.text('Ads')).dy));
  });

  testWidgets('the three shield switches report their new value', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(host(
      onBlockWebRtcChanged: (v) => changes.add('webrtc $v'),
      onBlockTrackersChanged: (v) => changes.add('trackers $v'),
      onAntiFingerprintingChanged: (v) => changes.add('fp $v'),
    ));
    for (final title in ['Block WebRTC', 'Block trackers and ads', 'Anti-fingerprinting']) {
      final row = find.ancestor(of: find.text(title), matching: find.byType(Row)).first;
      await tester.ensureVisible(row);
      await tester.tap(find.descendant(of: row, matching: find.byType(AppToggle)));
    }
    expect(changes, ['webrtc false', 'trackers false', 'fp false']);
  });

  testWidgets('a stored grant reads Allowed; a while-open grant offers Revoke', (tester) async {
    final revoked = <PermissionKind>[];
    await tester.pumpWidget(host(
      permissions: const [
        PermissionInUse(PermissionKind.camera, whileOpen: false),
        PermissionInUse(PermissionKind.microphone, whileOpen: true),
      ],
      onRevoke: revoked.add,
    ));
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Microphone'), findsOneWidget);
    await tester.ensureVisible(find.text('Revoke'));
    await tester.tap(find.text('Revoke'));
    expect(revoked, [PermissionKind.microphone]);
    expect(find.text('Location'), findsNothing);
  });

  testWidgets('no jade but Edit', (tester) async {
    await tester.pumpWidget(host(permissions: const [
      PermissionInUse(PermissionKind.microphone, whileOpen: true),
    ]));
    final jade = tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.color == C.jade);
    expect(jade.map((t) => t.data), ['Edit']);
  });

  testWidgets('on a small phone the sheet scrolls to Close and wipe, with no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(
      categoryCounts: const {BlockedCategory.trackers: 1, BlockedCategory.ads: 2,
          BlockedCategory.fingerprinting: 3, BlockedCategory.permissionAsks: 4},
      permissions: const [
        PermissionInUse(PermissionKind.camera, whileOpen: false),
        PermissionInUse(PermissionKind.microphone, whileOpen: true),
        PermissionInUse(PermissionKind.location, whileOpen: true),
        PermissionInUse(PermissionKind.clipboard, whileOpen: false),
      ],
    ));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Close and wipe this session'), 100);
    expect(find.text('Close and wipe this session'), findsOneWidget);
  });
}
