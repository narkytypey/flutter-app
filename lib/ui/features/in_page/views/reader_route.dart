import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/reader_article.dart';
import '../../../../domain/models/reader_style.dart';
import '../../settings/view_models/providers.dart' show settingsRepositoryProvider;
import 'reader_screen.dart';

/// Spec `6b` against the open vault: `Aa` and `◑` change the page at once and
/// are saved in the vault's settings, so the next article opens the same way
/// (user's ruling, 2026-09-30).
class ReaderRoute extends ConsumerStatefulWidget {
  const ReaderRoute({super.key, required this.article, required this.onClose});

  final ReaderArticle article;
  final VoidCallback onClose;

  @override
  ConsumerState<ReaderRoute> createState() => _ReaderRouteState();
}

class _ReaderRouteState extends ConsumerState<ReaderRoute> {
  ReaderStyle _style = ReaderStyle.standard;

  /// Set by the first tap, so a slow read of the saved style cannot undo it.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// A vault that cannot be read (it closed under the reader) leaves the
  /// standard style: the article still reads.
  Future<void> _load() async {
    final ReaderStyle stored;
    try {
      final settings = ref.read(settingsRepositoryProvider);
      stored = ReaderStyle.fromStored(
        size: await settings.getString('reader_text_size'),
        contrast: await settings.getString('reader_contrast'),
      );
    } catch (_) {
      return;
    }
    if (mounted && !_changed) setState(() => _style = stored);
  }

  Future<void> _apply(ReaderStyle style) async {
    setState(() {
      _changed = true;
      _style = style;
    });
    // The page has changed either way; a vault that closed keeps nothing.
    try {
      final settings = ref.read(settingsRepositoryProvider);
      await settings.setString('reader_text_size', style.storedSize);
      await settings.setString('reader_contrast', style.storedContrast);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => ReaderScreen(
        article: widget.article,
        style: _style,
        onClose: widget.onClose,
        onTextSize: () => _apply(_style.withNextSize()),
        onTheme: () => _apply(_style.withToggledContrast()),
      );
}
