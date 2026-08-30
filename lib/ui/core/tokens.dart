import 'dart:ui';

/// Colour tokens for the Isolated Web Container.
///
/// Every value is copied verbatim from the design source
/// (`Sandbox Container -canvas-.dc.html`). If a screen needs a colour that is
/// not here, that is a design question, not an implementation one.
abstract final class C {
  // Surfaces
  static const bg = Color(0xFF0F1113);
  static const bgPanic = Color(0xFF0C0E10);
  static const bgRecents = Color(0xFF0A0B0C);
  static const bgReader = Color(0xFF12100D);
  static const surface = Color(0xFF15181B);
  static const sheet = Color(0xFF141719);
  static const raised = Color(0xFF181B1E);
  static const button = Color(0xFF1C2124);
  static const selected = Color(0xFF20262A);
  static const monogramOpen = Color(0xFF20252A);
  static const footer = Color(0xFF111417);
  static const trackOff = Color(0xFF232729);
  static const knobOff = Color(0xFF4A5150);
  static const skeleton = Color(0xFF1B1F22);
  static const barTrack = Color(0xFF1A1E21);

  // Hairlines — white at the alphas the spec uses. The number is the
  // percentage: line06 is rgba(255,255,255,.06).
  static const line05 = Color(0x0DFFFFFF);
  static const line06 = Color(0x0FFFFFFF);
  static const line07 = Color(0x12FFFFFF);
  static const line08 = Color(0x14FFFFFF);
  static const line09 = Color(0x17FFFFFF);
  static const line10 = Color(0x1AFFFFFF);
  static const line12 = Color(0x1FFFFFFF);
  static const line13 = Color(0x21FFFFFF);
  static const line16 = Color(0x29FFFFFF);

  // Text
  static const textPrimary = Color(0xFFE8E9E7);
  static const textSecondary = Color(0xFFD7DCDA);
  static const textTertiary = Color(0xFFB9BFBD);
  static const textMuted = Color(0xFF8A918F);
  static const textFaint = Color(0xFF6E7573);
  static const textDim = Color(0xFF5F6664);
  static const textDisabled = Color(0xFF4A5150);
  static const monogramText = Color(0xFFC7CECC);
  static const icon = Color(0xFF9AA1A0);
  static const chevron = Color(0xFF7E8583);
  static const tabInactive = Color(0xFF767D7B);

  // Reader mode — its own warm palette, spec `6b` only.
  static const readerMuted = Color(0xFF8A857C);
  static const readerTitle = Color(0xFFEDE7DC);
  static const readerBody = Color(0xFFCFC8BC);
  static const readerHost = Color(0xFF7C776E);

  // State
  static const jade = Color(0xFF7FC8A9);
  static const jadeCode = Color(0xFF9FD8C0);
  static const idleDot = Color(0xFF3E4644);
  static const pinEmpty = Color(0xFF3A403E);
  static const danger = Color(0xFFD66A5A);
  static const dangerSurface = Color(0xFF241C1D);
  static const dangerMuted = Color(0xFF8A6A62);
  static const warning = Color(0xFFD6A45B);

  /// Workspace markers, in the order the picker shows them (spec `10b`).
  static const markers = <Color>[
    Color(0xFF7FC8A9),
    Color(0xFF8FA5C8),
    Color(0xFFD6A45B),
    Color(0xFFC89BB4),
    Color(0xFF8A918F),
  ];
}
