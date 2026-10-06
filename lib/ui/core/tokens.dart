import 'dart:ui';

/// Colour tokens for the Isolated Web Container — restyle v2 ("Instrument").
///
/// Every value comes from `docs/superpowers/specs/2026-10-05-restyle-v2-design.md`
/// §2. Dark only: four surfaces, three text tones (each ≥ 4.5:1 wherever the
/// spec lets it sit), jade for live state or the one affirmative action and
/// never for a position. If a screen needs a colour that is not here, that is a
/// design question, not an implementation one.
abstract final class C {
  // Surfaces (spec §2.1)
  /// Ink: the page.
  static const bg = Color(0xFF121110);
  static const bgReader = Color(0xFF15120E);

  /// Group: grouped rows, the address pill, inputs on the page, keypad keys.
  static const surface = Color(0xFF22201D);
  static const sheet = Color(0xFF302D29);

  /// Raised: selected fills, neutral buttons, open monograms.
  static const button = Color(0xFF403C37);
  static const selected = Color(0xFF403C37);
  static const monogramOpen = Color(0xFF403C37);

  /// An off switch's knob (text-3).
  static const knobOff = Color(0xFFA8A095);
  static const skeleton = Color(0xFF22201D);
  static const barTrack = Color(0xFF22201D);

  /// The sheet handle (edge).
  static const handle = Color(0xFF958D82);

  // Lines and edges (spec §2.4)
  /// Rule between rows inside a group: text-1 at 8 %.
  static const lineSoft = Color(0x14EDEAE4);

  /// A group's outline, a header's rule, an unselected chip: text-1 at 14 %.
  static const line = Color(0x24EDEAE4);

  /// Anything that must read as a boundary: off-switch outline, input
  /// border, empty PIN dot, idle light. ≥ 3.34:1 on every surface.
  static const edge = Color(0xFF958D82);

  /// 2 dp focus ring.
  static const focus = Color(0xFFEDEAE4);

  // Text (spec §2.2)
  static const textPrimary = Color(0xFFEDEAE4);
  static const textSecondary = Color(0xFFEDEAE4);
  static const textTertiary = Color(0xFFCBC4B9);
  static const textMuted = Color(0xFFCBC4B9);

  /// Text-3. Never on [button]/[selected] (4.23:1): use [textMuted] there.
  static const textFaint = Color(0xFFA8A095);
  static const monogramText = Color(0xFFEDEAE4);
  static const icon = Color(0xFFCBC4B9);
  static const chevron = Color(0xFFA8A095);
  static const tabInactive = Color(0xFFCBC4B9);

  /// The host in an address pill (`2b`, `8a`).
  static const pillText = Color(0xFFEDEAE4);

  // Reader mode (spec §2.5)
  static const readerMuted = Color(0xFFA39A8C);
  static const readerTitle = Color(0xFFEFE8DC);
  static const readerBody = Color(0xFFD3CBBE);

  // State (spec §2.3)
  static const jade = Color(0xFF7FC8A9);

  /// A label on a jade fill.
  static const onJade = Color(0xFF121110);

  /// Code text (`2a` custom CSS/JS, `10e`). Not jade: code is not live.
  static const code = Color(0xFFD9CFB8);
  static const idleDot = Color(0xFF958D82);
  static const pinEmpty = Color(0xFF958D82);
  static const danger = Color(0xFFEE8D79);

  /// Danger-wash: a small tinted panel, never a screen.
  static const dangerSurface = Color(0xFF2C201D);
  static const warning = Color(0xFFE0B266);

  /// `4c`'s dot rings after a wrong PIN.
  static const pinError = Color(0xFFEE8D79);

  /// Workspace markers, in the order the picker shows them (spec `10b`,
  /// v2 §2.6). Data, not identity colour; none is jade.
  static const markers = <Color>[
    Color(0xFFC9B48A),
    Color(0xFF8FA5C8),
    Color(0xFFE0B266),
    Color(0xFFC89BB4),
    Color(0xFFA8A095),
  ];
}

/// Spacing scale, dp (spec §4).
abstract final class S {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s7 = 32.0;
  static const s8 = 48.0;
}

/// Corner radii, dp (spec §4). Seven values, down from nineteen.
abstract final class R {
  static const badge = 6.0;
  static const monogram = 10.0;
  static const input = 14.0;
  static const group = 18.0;
  static const sheet = 28.0;
  static const full = 999.0;
}
