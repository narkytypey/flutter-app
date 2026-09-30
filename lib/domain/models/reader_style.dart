/// Reader mode's text size (spec `6b`'s `Aa`; user's ruling, 2026-09-30):
/// three steps, starting at the spec's own sizes.
enum ReaderTextSize {
  standard(15.5, 25),
  larger(17.5, 28),
  largest(19.5, 31);

  const ReaderTextSize(this.body, this.title);

  /// Paragraph and headline sizes, in logical pixels.
  final double body;
  final double title;
}

/// How reader mode draws an article: `Aa` cycles [size], `◑` switches [soft]
/// between the spec's colours and a softer, lower-contrast pair from the same
/// warm palette. Dark only: there is no light reader. Saved per vault.
class ReaderStyle {
  const ReaderStyle({required this.size, required this.soft});

  static const standard = ReaderStyle(size: ReaderTextSize.standard, soft: false);

  final ReaderTextSize size;
  final bool soft;

  ReaderStyle withNextSize() => ReaderStyle(
        size: ReaderTextSize.values[(size.index + 1) % ReaderTextSize.values.length],
        soft: soft,
      );

  ReaderStyle withToggledContrast() => ReaderStyle(size: size, soft: !soft);

  /// The vault's `reader_text_size` and `reader_contrast` settings.
  String get storedSize => size.name;
  String get storedContrast => soft ? 'soft' : 'standard';

  /// Anything unrecognised, including no setting at all, is [standard]'s.
  static ReaderStyle fromStored({required String? size, required String? contrast}) =>
      ReaderStyle(
        size: ReaderTextSize.values.firstWhere((s) => s.name == size,
            orElse: () => ReaderTextSize.standard),
        soft: contrast == 'soft',
      );
}
