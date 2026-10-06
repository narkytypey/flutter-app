import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/models/monogram_suggestion.dart';
import '../../../../domain/models/proxy_route.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/workspace.dart';
import '../../../../domain/onion.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import '../view_models/add_site_view.dart';
import 'appearance_tab.dart';
import 'basics_tab.dart';
import 'form_segment.dart';
import 'network_tab.dart';
import 'privacy_tab.dart';

/// Spec `2a` — all four tabs visible from the start (turn 2's title), not a
/// wizard. Every field from Task 1's extended `Site` becomes editable here.
class AddSiteScreen extends StatefulWidget {
  const AddSiteScreen({
    super.key,
    this.initial,
    required this.workspaces,
    required this.onSave,
    this.initialTab = 0,
    this.initialWorkspaceId,
    this.defaultRoute = ProxyRoute.direct,
    this.rulesMatchedToday,
    this.savesAsNew = false,
  });

  final Site? initial;
  final List<Workspace> workspaces;
  /// Save is ignored while a returned future is still running, so a double
  /// tap writes (and pops) once.
  final FutureOr<void> Function(Site site) onSave;

  /// The tab the form opens on: 0 Basics, 1 Network, 2 Privacy, 3 Appearance.
  /// `8b`'s "Change proxy settings" opens on Network.
  final int initialTab;

  /// The workspace a new site starts in: the dashboard's viewed chip (spec
  /// §6). Ignored when editing, or when it is not among [workspaces].
  final String? initialWorkspaceId;

  /// Where a new site's Network tab starts (spec §6): the vault's default
  /// route. An edited site shows its own.
  final ProxyRoute defaultRoute;

  /// A saved site's filter-list blocks today, for the Network tab's
  /// `Block trackers and ads`; null shows no count (a new site, a throwaway).
  final int? rulesMatchedToday;

  /// True when [initial] is a throwaway being saved as a site: the form adds
  /// one, so it reads `Add site`.
  final bool savesAsNew;

  @override
  State<AddSiteScreen> createState() => _AddSiteScreenState();
}

class _AddSiteScreenState extends State<AddSiteScreen> {
  static const _tabs = ['Basics', 'Network', 'Privacy', 'Appearance'];

  late final _urlController = TextEditingController(text: widget.initial?.url ?? '');
  late final _nameController = TextEditingController(text: widget.initial?.name ?? '');
  /// The route the Network tab starts from.
  late final ProxyRoute _startRoute =
      widget.initial == null ? widget.defaultRoute : ProxyRoute.of(widget.initial!);
  late final _hostController = TextEditingController(text: _startRoute.host ?? '127.0.0.1');
  late final _portController =
      TextEditingController(text: (_startRoute.port ?? 9050).toString());
  late final _userController = TextEditingController(text: _startRoute.user ?? '');
  late final _passwordController = TextEditingController(text: _startRoute.password ?? '');
  late final _cssController = TextEditingController(text: widget.initial?.customCss ?? '');
  late final _jsController = TextEditingController(text: widget.initial?.customJs ?? '');

  late int _tabIndex = widget.initialTab;
  late String _monogram = widget.initial?.monogram ?? '';
  late String _workspaceId = widget.initial?.workspaceId ?? _startWorkspace();
  late CookiePolicy _cookiePolicy = widget.initial?.cookiePolicy ?? CookiePolicy.keep;
  late bool _proxyEnabled = _startRoute.mode != ProxyMode.direct;
  late ProxyMode _proxyMode =
      _startRoute.mode == ProxyMode.direct ? ProxyMode.socks5 : _startRoute.mode;
  late bool _loginPerSite = _startRoute.loginPerSite;

  /// The keyboard is up on ADDRESS when a new site's form opens (spec §6).
  final _addressFocus = FocusNode();

  /// `Add site`, or the edited site's stored name; its host if that is blank.
  String _title() {
    final site = widget.initial;
    if (site == null || widget.savesAsNew) return 'Add site';
    if (site.name.trim().isNotEmpty) return site.name;
    return Uri.tryParse(site.url)?.host ?? site.url;
  }

  String _startWorkspace() {
    for (final workspace in widget.workspaces) {
      if (workspace.id == widget.initialWorkspaceId) return workspace.id;
    }
    // A vault always has a workspace (`ensureWorkspace`); never crash if not.
    return widget.workspaces.isEmpty ? '' : widget.workspaces.first.id;
  }
  late bool _blockWebRtc = widget.initial?.blockWebRtc ?? true;
  late bool _blockTrackers = widget.initial?.blockTrackers ?? true;
  late bool _allowCamera = widget.initial?.allowCamera ?? false;
  late bool _allowMicrophone = widget.initial?.allowMicrophone ?? false;
  late bool _allowLocation = widget.initial?.allowLocation ?? false;
  late bool _allowClipboard = widget.initial?.allowClipboard ?? false;
  late bool _antiFingerprinting = widget.initial?.antiFingerprinting ?? true;
  late bool _requirePin = widget.initial?.requirePin ?? false;
  late bool _showInDecoy = widget.initial?.showInDecoy ?? false;
  late UserAgentMode _userAgentMode = widget.initial?.userAgentMode ?? UserAgentMode.android;
  late bool _forceDark = widget.initial?.forceDark ?? true;
  late bool _openInReader = widget.initial?.openInReader ?? false;
  late int _pageZoom = widget.initial?.pageZoom ?? 100;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _cssController.dispose();
    _jsController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateMonogram);
    _updateMonogram();
    _urlController.addListener(_onionNeedsTor);
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addressFocus.requestFocus();
      });
    }
  }

  void _updateMonogram() {
    final suggestion = suggestMonogram(_nameController.text);
    if (suggestion != _monogram) setState(() => _monogram = suggestion);
  }

  /// Built-in Tor spec §5.3, plan D7: an onion address cannot be saved on
  /// Direct, so typing one turns the proxy on, on Tor.
  void _onionNeedsTor() {
    final host = Uri.tryParse(_address ?? '')?.host ?? '';
    if (_proxyEnabled || !isOnionHost(host)) return;
    setState(() {
      _proxyEnabled = true;
      _proxyMode = ProxyMode.tor;
    });
  }

  /// The address Save writes, or null while the field holds no web address.
  String? get _address => siteAddress(_urlController.text);

  bool _saving = false;

  Future<void> _save() async {
    final address = _address;
    if (address == null || _saving || _workspaceId.isEmpty) return;
    _saving = true;
    try {
      await _submit(address);
    } finally {
      if (mounted) _saving = false;
    }
  }

  FutureOr<void> _submit(String address) => widget.onSave(buildSite(
      initial: widget.initial,
      url: address,
      name: _nameController.text,
      monogram: _monogram,
      workspaceId: _workspaceId,
      cookiePolicy: _cookiePolicy,
      proxyMode: _proxyEnabled ? _proxyMode : ProxyMode.direct,
      proxyHost: _proxyEnabled ? _hostController.text : null,
      proxyPort: _proxyEnabled ? int.tryParse(_portController.text) : null,
      proxyUser: _userController.text,
      proxyPassword: _passwordController.text,
      proxyLoginPerSite: _loginPerSite,
      blockWebRtc: _blockWebRtc,
      blockTrackers: _blockTrackers,
      antiFingerprinting: _antiFingerprinting,
      allowCamera: _allowCamera,
      allowMicrophone: _allowMicrophone,
      allowLocation: _allowLocation,
      allowClipboard: _allowClipboard,
      requirePin: _requirePin,
      showInDecoy: _showInDecoy,
      userAgentMode: _userAgentMode,
      forceDark: _forceDark,
      openInReader: _openInReader,
      pageZoom: _pageZoom,
      customCss: _cssController.text,
      customJs: _jsController.text,
    ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(
                children: [
                  // Leaves without saving, like `10b`'s × (and system back).
                  IconTap(
                    glyph: AppGlyph.close,
                    label: 'Close',
                    onTap: () => Navigator.pop(context),
                    iconSize: 22,
                  ),
                  // An edited site's form is titled with its name (user's
                  // ruling 2026-10-05); only a new site's reads `Add site`.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _title(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: T.appBarTitle,
                      ),
                    ),
                  ),
                  // The screen's one jade (restyle v2 §8). Dimmed and inert,
                  // like an inert toggle, while the address is not one the
                  // engine would load.
                  ListenableBuilder(
                    listenable: _urlController,
                    builder: (context, _) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _address == null ? null : _save,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Opacity(
                              opacity: _address == null ? 0.4 : 1,
                              child: Text('Save', style: T.label.copyWith(color: C.jade)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: FormSegment(
                          label: _tabs[i],
                          selected: i == _tabIndex,
                          outlined: false,
                          onTap: () => setState(() => _tabIndex = i),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_tabIndex) {
      0 => BasicsTab(
          addressFocus: _addressFocus,
          urlController: _urlController,
          nameController: _nameController,
          monogram: _monogram,
          workspaces: widget.workspaces,
          workspaceId: _workspaceId,
          onWorkspaceChanged: (id) => setState(() => _workspaceId = id),
          cookiePolicy: _cookiePolicy,
          onCookiePolicyChanged: (v) => setState(() => _cookiePolicy = v),
        ),
      1 => NetworkTab(
          proxyEnabled: _proxyEnabled,
          onProxyEnabledChanged: (v) => setState(() => _proxyEnabled = v),
          proxyMode: _proxyMode,
          onProxyModeChanged: (v) => setState(() => _proxyMode = v),
          hostController: _hostController,
          portController: _portController,
          loginPerSite: _loginPerSite,
          onLoginPerSiteChanged: (v) => setState(() => _loginPerSite = v),
          userController: _userController,
          passwordController: _passwordController,
          blockWebRtc: _blockWebRtc,
          onBlockWebRtcChanged: (v) => setState(() => _blockWebRtc = v),
          blockTrackers: _blockTrackers,
          onBlockTrackersChanged: (v) => setState(() => _blockTrackers = v),
          rulesMatchedToday: widget.rulesMatchedToday,
        ),
      2 => PrivacyTab(
          allowCamera: _allowCamera,
          onAllowCameraChanged: (v) => setState(() => _allowCamera = v),
          allowMicrophone: _allowMicrophone,
          onAllowMicrophoneChanged: (v) => setState(() => _allowMicrophone = v),
          allowLocation: _allowLocation,
          onAllowLocationChanged: (v) => setState(() => _allowLocation = v),
          allowClipboard: _allowClipboard,
          onAllowClipboardChanged: (v) => setState(() => _allowClipboard = v),
          antiFingerprinting: _antiFingerprinting,
          onAntiFingerprintingChanged: (v) => setState(() => _antiFingerprinting = v),
          requirePin: _requirePin,
          onRequirePinChanged: (v) => setState(() => _requirePin = v),
          showInDecoy: _showInDecoy,
          onShowInDecoyChanged: (v) => setState(() => _showInDecoy = v),
        ),
      _ => AppearanceTab(
          userAgentMode: _userAgentMode,
          onUserAgentModeChanged: (v) => setState(() => _userAgentMode = v),
          forceDark: _forceDark,
          onForceDarkChanged: (v) => setState(() => _forceDark = v),
          openInReader: _openInReader,
          onOpenInReaderChanged: (v) => setState(() => _openInReader = v),
          pageZoom: _pageZoom,
          onPageZoomChanged: (v) => setState(() => _pageZoom = v),
          cssController: _cssController,
          jsController: _jsController,
        ),
    };
  }
}
