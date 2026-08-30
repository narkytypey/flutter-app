import 'package:flutter/material.dart';

import '../../../../domain/models/site.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `2a`, Appearance tab. `CUSTOM JS`'s empty placeholder ("Runs at
/// document start") is the promise Plan 3 Task 5 keeps via
/// `addDocumentStartJavaScript`.
class AppearanceTab extends StatelessWidget {
  const AppearanceTab({
    super.key,
    required this.userAgentMode,
    required this.onUserAgentModeChanged,
    required this.forceDark,
    required this.onForceDarkChanged,
    required this.openInReader,
    required this.onOpenInReaderChanged,
    required this.pageZoom,
    required this.onPageZoomChanged,
    required this.cssController,
    required this.jsController,
  });

  final UserAgentMode userAgentMode;
  final ValueChanged<UserAgentMode> onUserAgentModeChanged;
  final bool forceDark;
  final ValueChanged<bool> onForceDarkChanged;
  final bool openInReader;
  final ValueChanged<bool> onOpenInReaderChanged;
  final int pageZoom;
  final ValueChanged<int> onPageZoomChanged;
  final TextEditingController cssController;
  final TextEditingController jsController;

  static const _label = TextStyle(
    fontFamily: 'Figtree',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    color: C.textFaint,
  );

  static const _uaLabels = {
    UserAgentMode.android: 'Android',
    UserAgentMode.desktop: 'Desktop',
    UserAgentMode.minimal: 'Minimal',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('USER AGENT', style: _label),
        const SizedBox(height: 7),
        Row(
          children: [
            for (final mode in UserAgentMode.values) ...[
              if (mode != UserAgentMode.values.first) const SizedBox(width: 8),
              Expanded(child: _uaChip(mode)),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _toggleRow(
          title: 'Force dark mode',
          subtitle: 'For sites with no dark theme',
          value: forceDark,
          onChanged: onForceDarkChanged,
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Open in reader mode', style: ui(size: 14, color: C.textPrimary)),
            _switch(value: openInReader, onChanged: onOpenInReaderChanged),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Page zoom', style: ui(size: 14, color: C.textPrimary)),
            Text('$pageZoom%', style: ui(size: 12, weight: 500, color: C.jade)),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: C.jade,
            inactiveTrackColor: C.trackOff,
            thumbColor: C.textPrimary,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            min: 50,
            max: 200,
            value: pageZoom.toDouble().clamp(50, 200),
            onChanged: (v) => onPageZoomChanged(v.round()),
          ),
        ),
        const SizedBox(height: 18),
        const Text('CUSTOM CSS', style: _label),
        const SizedBox(height: 7),
        _codeBox(cssController, color: C.jadeCode, useMono: true),
        const SizedBox(height: 18),
        const Text('CUSTOM JS', style: _label),
        const SizedBox(height: 7),
        _codeBox(jsController, color: C.textFaint, useMono: false, hint: 'Runs at document start'),
      ],
    );
  }

  Widget _uaChip(UserAgentMode mode) {
    final selected = mode == userAgentMode;
    return GestureDetector(
      onTap: () => onUserAgentModeChanged(mode),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.selected : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: C.line08),
        ),
        child: Text(_uaLabels[mode]!,
            style: ui(size: 13, color: selected ? C.textPrimary : C.tabInactive)),
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ui(size: 14, color: C.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: ui(size: 11, color: C.textFaint)),
            ],
          ),
        ),
        _switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _switch({required bool value, required ValueChanged<bool> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 44,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? C.jade : C.trackOff,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? C.bg : C.knobOff,
          ),
        ),
      ),
    );
  }

  Widget _codeBox(TextEditingController controller,
      {required Color color, required bool useMono, String? hint}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line09),
      ),
      child: TextField(
        controller: controller,
        maxLines: null,
        minLines: 3,
        style: useMono
            ? mono(size: 11.5, height: 1.6, color: color)
            : ui(size: 11.5, height: 1.6, color: color),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle: ui(size: 11.5, color: C.textFaint),
        ),
      ),
    );
  }
}
