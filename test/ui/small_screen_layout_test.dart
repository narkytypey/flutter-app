import 'package:container/domain/models/held_download.dart';
import 'package:container/domain/models/open_step.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/ui/features/container/views/opening_screen.dart';
import 'package:container/ui/features/dashboard/views/site_row_menu.dart';
import 'package:container/ui/features/in_page/views/held_download_sheet.dart';
import 'package:container/ui/features/in_page/views/proxy_unreachable_screen.dart';
import 'package:container/ui/features/lock/views/lock_body.dart';
import 'package:container/ui/features/setup/views/setup_pin_screen.dart';
import 'package:container/ui/features/workspaces/views/delete_workspace_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small phone (320x568) at a 1.3 text scale, with long user content: none
/// of these screens may overflow. Any RenderFlex overflow fails the test.
const _onion = 'duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion';
const _longName = 'A workspace with a remarkably long and descriptive name';

Future<void> _pump(WidgetTester tester, Widget child, {bool sheet = false}) async {
  tester.view.physicalSize = const Size(320 * 3, 568 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(
    home: sheet
        ? Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              // A modal sheet's default cap: 9/16 of the screen.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 568 * 9 / 16),
                child: child,
              ),
            ),
          )
        : child,
  ));
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('8b with a long proxy host and every button', (tester) async {
    await _pump(
      tester,
      ProxyUnreachableScreen(
        host: _onion,
        siteName: 'Forum',
        failure: RouteFailure.proxyUnreachable,
        tunnelDescriptor: 'SOCKS5 · a-very-long-proxy-hostname.example.net:1080',
        lastWorkedLabel: 'never',
        onTryAgain: () {},
        onChangeProxySettings: () {},
        onOpenWithoutTunnel: () {},
      ),
    );
  });

  testWidgets('4b with its notice', (tester) async {
    await _pump(
      tester,
      SetupPinScreen(
        filled: 3,
        onKey: (_) {},
        onContinue: null,
        notice: 'Choose a different PIN',
      ),
    );
  });

  for (final mood in LockMood.values) {
    testWidgets('lock screen, $mood, with fingerprint', (tester) async {
      await _pump(
        tester,
        LockBody(
          mood: mood,
          filled: 2,
          onKey: (_) {},
          onBiometric: () {},
          openSessions: 4,
          secondsUntilLock: 42,
          biometricAvailable: true,
        ),
      );
    });
  }

  testWidgets('8a with an onion host and a long tunnel step', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: OpeningBody(
          host: _onion,
          steps: const [
            OpenStep('Fresh session, no shared cookies', OpenStepState.done),
            OpenStep('Connecting through a-very-long-proxy-hostname.example.net:1080',
                OpenStepState.running),
          ],
          progress: 0.4,
          onCancel: () {},
        ),
      ),
    );
  });

  testWidgets('7b row menu in a modal sheet', (tester) async {
    await _pump(
      tester,
      SiteRowMenu(
        monogram: 'Fo',
        name: _longName,
        subtitle: 'https://$_onion/some/very/long/path',
        onAction: (_) {},
        onCancel: () {},
      ),
      sheet: true,
    );
  });

  testWidgets('7c held download in a modal sheet', (tester) async {
    await _pump(
      tester,
      HeldDownloadSheet(
        download: const HeldDownload(
          fileName: 'a-very-long-file-name-for-an-annual-report-2026-final-v3.pdf',
          sizeBytes: 1400000,
          sourceHost: _onion,
          kindLabel: 'PDF',
        ),
        onDecision: (_) {},
      ),
      sheet: true,
    );
  });

  testWidgets('10c delete workspace in a modal sheet', (tester) async {
    await _pump(
      tester,
      DeleteWorkspaceSheet(
        workspaceName: _longName,
        sitesRemoved: 12,
        onCancel: () {},
        onDelete: () {},
      ),
      sheet: true,
    );
  });
}
