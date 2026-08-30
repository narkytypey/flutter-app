import 'package:flutter/material.dart';

import '../../../../domain/models/monogram_suggestion.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../view_models/add_site_view.dart';
import 'appearance_tab.dart';
import 'basics_tab.dart';
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
  });

  final Site? initial;
  final List<Workspace> workspaces;
  final ValueChanged<Site> onSave;

  @override
  State<AddSiteScreen> createState() => _AddSiteScreenState();
}

class _AddSiteScreenState extends State<AddSiteScreen> {
  static const _tabs = ['Basics', 'Network', 'Privacy', 'Appearance'];

  late final _urlController = TextEditingController(text: widget.initial?.url ?? '');
  late final _nameController = TextEditingController(text: widget.initial?.name ?? '');
  late final _hostController =
      TextEditingController(text: widget.initial?.proxyHost ?? '127.0.0.1');
  late final _portController =
      TextEditingController(text: (widget.initial?.proxyPort ?? 9050).toString());
  late final _cssController = TextEditingController(text: widget.initial?.customCss ?? '');
  late final _jsController = TextEditingController(text: widget.initial?.customJs ?? '');

  int _tabIndex = 0;
  late String _monogram = widget.initial?.monogram ?? '';
  late String _workspaceId = widget.initial?.workspaceId ?? widget.workspaces.first.id;
  late CookiePolicy _cookiePolicy = widget.initial?.cookiePolicy ?? CookiePolicy.keep;
  late bool _proxyEnabled = (widget.initial?.proxyMode ?? ProxyMode.direct) != ProxyMode.direct;
  late ProxyMode _proxyMode =
      widget.initial?.proxyMode == ProxyMode.http ? ProxyMode.http : ProxyMode.socks5;
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
    _cssController.dispose();
    _jsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateMonogram);
    _updateMonogram();
  }

  void _updateMonogram() {
    final suggestion = suggestMonogram(_nameController.text);
    if (suggestion != _monogram) setState(() => _monogram = suggestion);
  }

  void _save() {
    widget.onSave(buildSite(
      initial: widget.initial,
      url: _urlController.text,
      name: _nameController.text,
      monogram: _monogram,
      workspaceId: _workspaceId,
      cookiePolicy: _cookiePolicy,
      proxyMode: _proxyEnabled ? _proxyMode : ProxyMode.direct,
      proxyHost: _proxyEnabled ? _hostController.text : null,
      proxyPort: _proxyEnabled ? int.tryParse(_portController.text) : null,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('×', style: TextStyle(fontSize: 20, color: C.icon)),
                  Text('Add site', style: ui(size: 15, weight: 600, color: C.textPrimary)),
                  GestureDetector(
                    onTap: _save,
                    child: Text('Save', style: ui(size: 14, weight: 500, color: C.jade)),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line07))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++) Expanded(child: _tab(i)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(int index) {
    final active = index == _tabIndex;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 11, 0, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? C.jade : Colors.transparent, width: 2)),
        ),
        alignment: Alignment.center,
        child: Text(_tabs[index],
            style: ui(size: 12.5, weight: 500, color: active ? C.textPrimary : C.tabInactive)),
      ),
    );
  }

  Widget _body() {
    return switch (_tabIndex) {
      0 => BasicsTab(
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
          blockWebRtc: _blockWebRtc,
          onBlockWebRtcChanged: (v) => setState(() => _blockWebRtc = v),
          blockTrackers: _blockTrackers,
          onBlockTrackersChanged: (v) => setState(() => _blockTrackers = v),
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
