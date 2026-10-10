import 'dart:ui';

/// Colour tokens for the Isolated Web Container — restyle v2 ("Instrument")
/// with the cyberpunk dark palette.
///
/// Dark values come from `docs/superpowers/specs/2026-10-10-cyberpunk-palette-design.md`
/// §2, light values from `docs/superpowers/specs/2026-10-05-restyle-v2-design.md`
/// §9. Four surfaces, three text tones (each ≥ 4.5:1
/// wherever the spec lets it sit), jade for live state or the one affirmative
/// action and never for a position. If a screen needs a colour that is not
/// here, that is a design question, not an implementation one.
///
/// [Palette.dark] and [Palette.light] give every role its two values; [C]
/// reads the active one. The app follows the phone's system setting
/// (`PaletteScope` calls [C.use]); nothing about it differs by vault.
final class Palette {
  const Palette({
    required this.bg,
    required this.bgReader,
    required this.surface,
    required this.sheet,
    required this.button,
    required this.selected,
    required this.monogramOpen,
    required this.knobOff,
    required this.skeleton,
    required this.barTrack,
    required this.handle,
    required this.lineSoft,
    required this.line,
    required this.edge,
    required this.focus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.textFaint,
    required this.monogramText,
    required this.icon,
    required this.chevron,
    required this.tabInactive,
    required this.pillText,
    required this.readerMuted,
    required this.readerTitle,
    required this.readerBody,
    required this.jade,
    required this.onJade,
    required this.code,
    required this.idleDot,
    required this.pinEmpty,
    required this.danger,
    required this.dangerSurface,
    required this.warning,
    required this.pinError,
    required this.markers,
  });

  final Color bg;
  final Color bgReader;
  final Color surface;
  final Color sheet;
  final Color button;
  final Color selected;
  final Color monogramOpen;
  final Color knobOff;
  final Color skeleton;
  final Color barTrack;
  final Color handle;
  final Color lineSoft;
  final Color line;
  final Color edge;
  final Color focus;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;
  final Color textFaint;
  final Color monogramText;
  final Color icon;
  final Color chevron;
  final Color tabInactive;
  final Color pillText;
  final Color readerMuted;
  final Color readerTitle;
  final Color readerBody;
  final Color jade;
  final Color onJade;
  final Color code;
  final Color idleDot;
  final Color pinEmpty;
  final Color danger;
  final Color dangerSurface;
  final Color warning;
  final Color pinError;
  final List<Color> markers;

  /// Cyberpunk spec (`2026-10-10-cyberpunk-palette-design.md`) §2: cool
  /// blue-black surfaces and a neon live colour. Reader keeps v2 §2.5's warm
  /// values.
  static const dark = Palette(
    bg: Color(0xFF0B0D12),
    bgReader: Color(0xFF15120E),
    surface: Color(0xFF1A1F2A),
    sheet: Color(0xFF252B39),
    button: Color(0xFF31394A),
    selected: Color(0xFF31394A),
    monogramOpen: Color(0xFF31394A),
    knobOff: Color(0xFF97A3BA),
    skeleton: Color(0xFF1A1F2A),
    barTrack: Color(0xFF1A1F2A),
    handle: Color(0xFF7A87A0),
    lineSoft: Color(0x14E6EDF7),
    line: Color(0x24E6EDF7),
    edge: Color(0xFF7A87A0),
    focus: Color(0xFFE6EDF7),
    textPrimary: Color(0xFFE6EDF7),
    textSecondary: Color(0xFFE6EDF7),
    textTertiary: Color(0xFFB8C3D6),
    textMuted: Color(0xFFB8C3D6),
    textFaint: Color(0xFF97A3BA),
    monogramText: Color(0xFFE6EDF7),
    icon: Color(0xFFB8C3D6),
    chevron: Color(0xFF97A3BA),
    tabInactive: Color(0xFFB8C3D6),
    pillText: Color(0xFFE6EDF7),
    readerMuted: Color(0xFFA39A8C),
    readerTitle: Color(0xFFEFE8DC),
    readerBody: Color(0xFFD3CBBE),
    jade: Color(0xFF3DF5D0),
    onJade: Color(0xFF0B0D12),
    code: Color(0xFFC9B8FF),
    idleDot: Color(0xFF7A87A0),
    pinEmpty: Color(0xFF7A87A0),
    danger: Color(0xFFFF7AA6),
    dangerSurface: Color(0xFF2A1520),
    warning: Color(0xFFF5D13D),
    pinError: Color(0xFFFF7AA6),
    markers: <Color>[
      Color(0xFFFF8FCF),
      Color(0xFF8FB0FF),
      Color(0xFFF5D13D),
      Color(0xFFC49BFF),
      Color(0xFF97A3BA),
    ],
  );

  /// Spec §9: the light values. Same roles; jade darkened to spruce.
  static const light = Palette(
    bg: Color(0xFFF3F0EA),
    bgReader: Color(0xFFF6F1E7),
    surface: Color(0xFFFFFFFF),
    sheet: Color(0xFFFAF8F4),
    button: Color(0xFFE3DDD3),
    selected: Color(0xFFE3DDD3),
    monogramOpen: Color(0xFFE3DDD3),
    knobOff: Color(0xFF686157),
    skeleton: Color(0xFFE9E4DC),
    barTrack: Color(0xFFE9E4DC),
    handle: Color(0xFF857D72),
    lineSoft: Color(0x141C1A17),
    line: Color(0x241C1A17),
    edge: Color(0xFF857D72),
    focus: Color(0xFF1C1A17),
    textPrimary: Color(0xFF1C1A17),
    textSecondary: Color(0xFF1C1A17),
    textTertiary: Color(0xFF4B453D),
    textMuted: Color(0xFF4B453D),
    textFaint: Color(0xFF686157),
    monogramText: Color(0xFF1C1A17),
    icon: Color(0xFF4B453D),
    chevron: Color(0xFF686157),
    tabInactive: Color(0xFF4B453D),
    pillText: Color(0xFF1C1A17),
    readerMuted: Color(0xFF5E564B),
    readerTitle: Color(0xFF2B2620),
    readerBody: Color(0xFF3A342C),
    jade: Color(0xFF1D6B57),
    onJade: Color(0xFFFFFFFF),
    code: Color(0xFF7A5718),
    idleDot: Color(0xFF857D72),
    pinEmpty: Color(0xFF857D72),
    danger: Color(0xFFB3261E),
    dangerSurface: Color(0xFFFBEAE6),
    warning: Color(0xFF8A5800),
    pinError: Color(0xFFB3261E),
    markers: <Color>[
      Color(0xFF7D6532),
      Color(0xFF3D5F8F),
      Color(0xFF8A5800),
      Color(0xFF8A4F72),
      Color(0xFF6E675D),
    ],
  );
}

/// The active palette's colours, by role.
///
/// Not `const`: a value read here changes when the system setting does, so
/// never cache one in a `static` or `const` field (Plan 24 Handoff).
abstract final class C {
  static Palette _active = Palette.dark;
  static Brightness _brightness = Brightness.dark;

  /// Makes [brightness]'s palette the active one.
  static void use(Brightness brightness) {
    _brightness = brightness;
    _active = brightness == Brightness.light ? Palette.light : Palette.dark;
  }

  /// Which palette is active.
  static Brightness get brightness => _brightness;

  /// The active palette.
  static Palette get palette => _active;

  // Surfaces (spec §2.1)
  /// Ink: the page.
  static Color get bg => _active.bg;
  static Color get bgReader => _active.bgReader;

  /// Group: grouped rows, the address pill, inputs on the page, keypad keys.
  static Color get surface => _active.surface;
  static Color get sheet => _active.sheet;

  /// Raised: selected fills, neutral buttons, open monograms.
  static Color get button => _active.button;
  static Color get selected => _active.selected;
  static Color get monogramOpen => _active.monogramOpen;

  /// An off switch's knob (text-3).
  static Color get knobOff => _active.knobOff;
  static Color get skeleton => _active.skeleton;
  static Color get barTrack => _active.barTrack;

  /// The sheet handle (edge).
  static Color get handle => _active.handle;

  // Lines and edges (spec §2.4)
  /// Rule between rows inside a group: text-1 at 8 %.
  static Color get lineSoft => _active.lineSoft;

  /// A group's outline, a header's rule, an unselected chip: text-1 at 14 %.
  static Color get line => _active.line;

  /// Anything that must read as a boundary: off-switch outline, input
  /// border, empty PIN dot, idle light. ≥ 3:1 on every surface.
  static Color get edge => _active.edge;

  /// 2 dp focus ring.
  static Color get focus => _active.focus;

  // Text (spec §2.2)
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textTertiary => _active.textTertiary;
  static Color get textMuted => _active.textMuted;

  /// Text-3. In dark, never on [button]/[selected] (4.23:1): use [textMuted]
  /// there.
  static Color get textFaint => _active.textFaint;
  static Color get monogramText => _active.monogramText;
  static Color get icon => _active.icon;
  static Color get chevron => _active.chevron;
  static Color get tabInactive => _active.tabInactive;

  /// The host in an address pill (`2b`, `8a`).
  static Color get pillText => _active.pillText;

  // Reader mode (spec §2.5)
  static Color get readerMuted => _active.readerMuted;
  static Color get readerTitle => _active.readerTitle;
  static Color get readerBody => _active.readerBody;

  // State (spec §2.3)
  static Color get jade => _active.jade;

  /// A label on a jade fill.
  static Color get onJade => _active.onJade;

  /// Code text (`2a` custom CSS/JS, `10e`). Not jade: code is not live.
  static Color get code => _active.code;
  static Color get idleDot => _active.idleDot;
  static Color get pinEmpty => _active.pinEmpty;
  static Color get danger => _active.danger;

  /// Danger-wash: a small tinted panel, never a screen.
  static Color get dangerSurface => _active.dangerSurface;
  static Color get warning => _active.warning;

  /// `4c`'s dot rings after a wrong PIN.
  static Color get pinError => _active.pinError;

  /// Workspace markers, in the order the picker shows them (spec `10b`,
  /// v2 §2.6). Data, not identity colour; none is jade.
  static List<Color> get markers => _active.markers;
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
