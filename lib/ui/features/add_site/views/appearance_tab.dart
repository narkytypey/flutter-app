import 'package:flutter/material.dart';

import '../../../../domain/models/site.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import 'form_input.dart';
import 'form_segment.dart';
import 'form_toggle_row.dart';

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

  static final _label = T.sectionLabel;

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
        Text('USER AGENT', style: _label),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final mode in UserAgentMode.values) ...[
              if (mode != UserAgentMode.values.first) const SizedBox(width: 8),
              Expanded(
                child: FormSegment(
                  label: _uaLabels[mode]!,
                  selected: mode == userAgentMode,
                  onTap: () => onUserAgentModeChanged(mode),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FormToggleRow(
          title: 'Force dark mode',
          subtitle: 'For sites with no dark theme',
          value: forceDark,
          onChanged: onForceDarkChanged,
        ),
        FormToggleRow(
          title: 'Open in reader mode',
          value: openInReader,
          onChanged: onOpenInReaderChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Page zoom', style: T.body.copyWith(color: C.textPrimary))),
            Text('$pageZoom%', style: T.value.copyWith(color: C.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          // Restyle v2: a position, not live state, so not jade.
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: C.textPrimary,
            inactiveTrackColor: C.edge,
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
        const SizedBox(height: 20),
        Text('CUSTOM CSS', style: _label),
        const SizedBox(height: 8),
        _codeBox(cssController),
        const SizedBox(height: 20),
        Text('CUSTOM JS', style: _label),
        const SizedBox(height: 8),
        _codeBox(jsController, hint: 'Runs at document start'),
      ],
    );
  }

  /// Code text is `C.code`, never jade: code is not live (restyle v2 §2.3).
  Widget _codeBox(TextEditingController controller, {String? hint}) {
    return FormInput(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        maxLines: null,
        minLines: 3,
        style: T.code,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle: T.meta,
        ),
      ),
    );
  }
}
