import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every [AppIcon] drawing [glyph].
Finder findGlyph(AppGlyph glyph) =>
    find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph);

/// The [IconTap] a screen reader announces as [label].
Finder findIconTap(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);
