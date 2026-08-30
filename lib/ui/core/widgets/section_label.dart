import 'package:flutter/widgets.dart';

import '../typography.dart';

/// The 10px letterspaced caps label. [text] must already be uppercase — copy
/// is verbatim from the spec, so casing is not this widget's decision.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.live = false});

  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: live ? T.sectionLabelLive : T.sectionLabel);
}
