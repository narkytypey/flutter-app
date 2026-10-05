import 'package:flutter/material.dart';

import '../../../../domain/models/address_suggestion.dart';
import '../../../../domain/models/destination.dart';
import '../../../../domain/models/find_result.dart';
import '../../../../domain/models/navigation_state.dart';
import '../../../../domain/models/switcher_entry.dart';
import '../../../core/tokens.dart';
import 'address_edit_bar.dart';
import 'address_suggestions.dart';
import 'browser_menu_sheet.dart';
import 'container_bottom_bar.dart';
import 'container_top_bar.dart';
import 'find_bar.dart';
import 'load_line.dart';
import 'switcher_sheet.dart';
import 'throwaway_save_bar.dart';

/// Which bar sits above the page.
enum _Chrome { page, editing, find }

/// The container (browser-chrome spec §6, layout C, which supersedes `2b`):
/// the top bar or the find bar, the page, a throwaway's save bar, and the
/// bottom bar, with the `2c` switcher and the ☰ menu as sheets.
///
/// Owns only which chrome shows. What the page does, and every screen the
/// chrome opens, belongs to the route, through the callbacks.
///
/// **[body] never moves in the tree.** Rebuilding the page view detaches and
/// reattaches the page; nothing is lost, but it flickers. So the bar above the
/// page is swapped within one slot, and everything that comes and goes around
/// the page is laid out after it.
class ContainerScreen extends StatefulWidget {
  const ContainerScreen({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.navigation,
    required this.openCount,
    required this.body,
    required this.entries,
    required this.workspaceName,
    required this.siteMonogram,
    required this.siteName,
    required this.siteSubtitle,
    required this.blockedToday,
    required this.securityLevelMeta,
    required this.findResult,
    required this.showSaveBar,
    required this.address,
    required this.suggest,
    required this.onOpen,
    required this.onBack,
    required this.onLeave,
    required this.onForward,
    required this.onStop,
    required this.onReload,
    required this.onPanic,
    this.onNextContainer,
    this.onPreviousContainer,
    required this.onSiteDetails,
    required this.onReader,
    required this.onCopyLink,
    required this.onToday,
    required this.onScripts,
    required this.onWorkspaces,
    required this.onSettings,
    required this.onAllSites,
    required this.onSecurityLevel,
    required this.onNewIdentity,
    required this.onFind,
    required this.onFindNext,
    required this.onClearFind,
    required this.onSaveAsSite,
    required this.onDismissSaveBar,
    required this.onViewContainer,
    required this.onViewPage,
    required this.onCloseSession,
    required this.onClosePage,
    required this.onCloseAllAndWipe,
  });

  /// The page's host, for the pill.
  final String host;

  /// `SOCKS5`, `HTTP`, or empty for a direct site — see [ContainerTopBar].
  final String routeLabel;
  final bool live;

  /// What the page is doing, or null before its first report.
  final NavigationState? navigation;
  final int openCount;

  /// The page itself: the native WebView platform view on a device.
  final Widget body;

  final List<SwitcherEntry> entries;
  final String workspaceName;

  /// The ☰ menu's header (spec §6.4).
  final String siteMonogram;
  final String siteName;
  final String siteSubtitle;

  /// Today's blocked total, for the menu's `Today` row.
  final int blockedToday;

  /// The menu's `Security level` meta: `STANDARD`, `SAFER` or `SAFEST`
  /// (privacy-controls spec §4.1).
  final String securityLevelMeta;

  /// The page's count for what the find bar holds; null until it reports.
  final FindResult? findResult;

  /// A throwaway's save bar (spec §5.3), directly above the bottom bar.
  final bool showSaveBar;

  /// What the address field starts from, selected: the page's address.
  final String address;

  /// What typed text would open (spec §4.4), from the open vault only.
  final List<AddressSuggestion> Function(String text) suggest;

  /// A suggestion picked, or the keyboard's action on the field (§6.2).
  final ValueChanged<Destination> onOpen;

  /// Back in the page: the bottom bar's back, and system back while the page
  /// can go back.
  final VoidCallback onBack;

  /// System back with no history in the page (tabs spec §5.3).
  final VoidCallback onLeave;
  final VoidCallback onForward;
  final VoidCallback onStop;
  final VoidCallback onReload;
  final VoidCallback onPanic;

  /// Dashboard spec §9's swipe on the bottom bar. Null at that end.
  final VoidCallback? onNextContainer;
  final VoidCallback? onPreviousContainer;

  /// The shield: `6c`.
  final VoidCallback onSiteDetails;
  final VoidCallback onReader;
  final VoidCallback onCopyLink;
  final VoidCallback onToday;
  final VoidCallback onScripts;
  final VoidCallback onWorkspaces;
  final VoidCallback onSettings;
  final VoidCallback onAllSites;

  /// The menu's `Security level` and `New identity` rows (privacy-controls
  /// spec §4.1).
  final VoidCallback onSecurityLevel;
  final VoidCallback onNewIdentity;

  /// The find bar's text on every change — empty once it is cleared.
  final ValueChanged<String> onFind;

  /// True steps forward.
  final ValueChanged<bool> onFindNext;

  /// Find closed.
  final VoidCallback onClearFind;
  final VoidCallback onSaveAsSite;
  final VoidCallback onDismissSaveBar;
  /// `2c`'s container row: view that container on its last viewed page.
  final void Function(String siteId) onViewContainer;

  /// `2c`'s page row: view that page.
  final void Function(String siteId, String pageId) onViewPage;
  final void Function(String siteId) onCloseSession;

  /// `2c`'s × on a page row: close that page only.
  final void Function(String siteId, String pageId) onClosePage;
  final VoidCallback onCloseAllAndWipe;

  @override
  State<ContainerScreen> createState() => _ContainerScreenState();
}

class _ContainerScreenState extends State<ContainerScreen> {
  _Chrome _chrome = _Chrome.page;
  final _addressText = TextEditingController();
  final _findText = TextEditingController();

  @override
  void dispose() {
    _addressText.dispose();
    _findText.dispose();
    super.dispose();
  }

  /// Spec §6.2: the field starts from the page's address, selected, so
  /// typing replaces it.
  void _startEditing() {
    final address = widget.address;
    _addressText.value = TextEditingValue(
      text: address,
      selection: TextSelection(baseOffset: 0, extentOffset: address.length),
    );
    setState(() => _chrome = _Chrome.editing);
  }

  void _stopEditing() => setState(() => _chrome = _Chrome.page);

  void _open(AddressSuggestion suggestion) {
    _stopEditing();
    widget.onOpen(suggestion.destination);
  }

  /// The keyboard's action opens the address row if there is one, otherwise
  /// the search row. With nothing typed there is neither, and editing ends.
  void _submitAddress(String text) {
    final pick = submittedSuggestion(widget.suggest(text));
    if (pick == null) {
      _stopEditing();
    } else {
      _open(pick);
    }
  }

  void _startFind() {
    _findText.clear();
    setState(() => _chrome = _Chrome.find);
  }

  void _closeFind() {
    widget.onClearFind();
    setState(() => _chrome = _Chrome.page);
  }

  /// Every system back, which [PopScope] keeps from popping the route: out of
  /// editing or find first, then back in the page (spec §3.3, §6.2), then
  /// [ContainerScreen.onLeave], which decides where back goes (tabs spec
  /// §5.3). The route never pops by itself.
  void _handleBack() {
    switch (_chrome) {
      case _Chrome.editing:
        _stopEditing();
      case _Chrome.find:
        _closeFind();
      case _Chrome.page:
        if (widget.navigation?.canGoBack ?? false) {
          widget.onBack();
        } else {
          widget.onLeave();
        }
    }
  }

  /// The two close actions dismiss the sheet by its own context before
  /// reporting, so a caller that then pops its route pops the route and not
  /// this sheet on top of it. Panic is passed through untouched: it replaces
  /// the whole open vault, sheet included.
  void _openSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => SwitcherSheet(
        entries: widget.entries,
        workspaceName: widget.workspaceName,
        // Each one closes the sheet by its own context first, so whatever it
        // does acts on the route under the sheet, never on the sheet.
        onViewContainer: (siteId) {
          Navigator.pop(sheetContext);
          widget.onViewContainer(siteId);
        },
        onViewPage: (siteId, pageId) {
          Navigator.pop(sheetContext);
          widget.onViewPage(siteId, pageId);
        },
        onCloseSession: (siteId) {
          Navigator.pop(sheetContext);
          widget.onCloseSession(siteId);
        },
        onClosePage: (siteId, pageId) {
          Navigator.pop(sheetContext);
          widget.onClosePage(siteId, pageId);
        },
        onCloseAllAndWipe: () {
          Navigator.pop(sheetContext);
          widget.onCloseAllAndWipe();
        },
        onPanic: widget.onPanic,
      ),
    );
  }

  /// Spec §6.4. Every entry closes the sheet by its own context before it
  /// acts, so a screen it opens lands above this container, not the sheet.
  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // Taller than a modal sheet's default cap of 9/16 of a small phone.
      isScrollControlled: true,
      // Kept below the status bar on a short screen or in landscape.
      useSafeArea: true,
      builder: (sheetContext) {
        VoidCallback closing(VoidCallback action) => () {
              Navigator.pop(sheetContext);
              action();
            };
        return BrowserMenuSheet(
          monogram: widget.siteMonogram,
          name: widget.siteName,
          subtitle: widget.siteSubtitle,
          blockedToday: widget.blockedToday,
          securityLevelMeta: widget.securityLevelMeta,
          onSecurityLevel: closing(widget.onSecurityLevel),
          onNewIdentity: closing(widget.onNewIdentity),
          onReload: closing(widget.onReload),
          onFind: closing(_startFind),
          onReader: closing(widget.onReader),
          onCopyLink: closing(widget.onCopyLink),
          onToday: closing(widget.onToday),
          onScripts: closing(widget.onScripts),
          onWorkspaces: closing(widget.onWorkspaces),
          onSettings: closing(widget.onSettings),
          onAllSites: closing(widget.onAllSites),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigation = widget.navigation;
    final canGoBack = navigation?.canGoBack ?? false;
    final canGoForward = navigation?.canGoForward ?? false;
    final loading = navigation?.loading ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              switch (_chrome) {
                _Chrome.page => ContainerTopBar(
                    host: widget.host,
                    routeLabel: widget.routeLabel,
                    live: widget.live,
                    loading: loading,
                    onEditAddress: _startEditing,
                    onStop: widget.onStop,
                    onReload: widget.onReload,
                    onSiteDetails: widget.onSiteDetails,
                    onPanic: widget.onPanic,
                  ),
                _Chrome.editing => AddressEditBar(
                    controller: _addressText,
                    // The suggestions below are worked out from the field
                    // at every build.
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _submitAddress,
                    onPanic: widget.onPanic,
                  ),
                _Chrome.find => FindBar(
                    controller: _findText,
                    result: widget.findResult,
                    onChanged: widget.onFind,
                    onPrevious: () => widget.onFindNext(false),
                    onNext: () => widget.onFindNext(true),
                    onClose: _closeFind,
                    onPanic: widget.onPanic,
                  ),
              },
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(child: widget.body),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: LoadLine(
                                      loading: loading,
                                      progress: navigation?.progress ?? 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.showSaveBar)
                            ThrowawaySaveBar(
                              onSave: widget.onSaveAsSite,
                              onDismiss: widget.onDismissSaveBar,
                            ),
                          ContainerBottomBar(
                            openCount: widget.openCount,
                            onBack: canGoBack ? widget.onBack : null,
                            onForward: canGoForward ? widget.onForward : null,
                            onOpenSwitcher: _openSwitcher,
                            onMenu: _openMenu,
                            onNextContainer: widget.onNextContainer,
                            onPreviousContainer: widget.onPreviousContainer,
                          ),
                        ],
                      ),
                    ),
                    // Spec §6.2: while typing, the suggestions cover the page
                    // and the bottom bar. Laid over them, after the page, so
                    // the page view keeps its place.
                    if (_chrome == _Chrome.editing)
                      Positioned.fill(
                        child: AddressSuggestions(
                          suggestions: widget.suggest(_addressText.text),
                          onPick: _open,
                          onDismiss: _stopEditing,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
