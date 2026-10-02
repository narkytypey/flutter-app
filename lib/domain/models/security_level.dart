import 'site.dart';

/// The `app_settings` key of the open vault's default level (spec §2.1).
const securityLevelSettingKey = 'security_level';

/// What a site may run (privacy-controls spec §1). The names and intent are
/// Mullvad Browser's; what each switches off is what WebView can switch off.
enum SecurityLevel {
  standard('Standard', 'STANDARD', 'Every site feature is on'),
  safer('Safer', 'SAFER', 'JavaScript off on http pages · no WebGL or WebAssembly'),
  safest('Safest', 'SAFEST', 'JavaScript and images off on every page');

  const SecurityLevel(this.label, this.meta, this.description);

  /// The level's name: pickers, `6c` and Settings (spec §5).
  final String label;

  /// The ☰ row's mono meta (spec §5).
  final String meta;

  /// The picker's second line (spec §5).
  final String description;

  /// A stored or sent name. Nothing stored is null ("follow the default"
  /// for a site). Any other name fails closed to [safest] (spec §1.5): only a
  /// downgrade or a damaged row can produce one.
  static SecurityLevel? fromStored(String? name) {
    if (name == null) return null;
    for (final level in values) {
      if (level.name == name) return level;
    }
    return safest;
  }

  /// The vault default: [standard] until one is stored (spec §2.1).
  static SecurityLevel vaultDefaultFrom(String? name) => fromStored(name) ?? standard;
}

/// What [site] runs at: its own level, or else the vault default (spec §2.2).
SecurityLevel effectiveLevel(Site site, SecurityLevel vaultDefault) =>
    site.securityLevel ?? vaultDefault;

/// `6c`'s Security level value (spec §5): `<Level>` for a site's own level,
/// `<Level> · default` while it follows the vault default.
String securityLevelValue(Site site, SecurityLevel vaultDefault) =>
    site.securityLevel?.label ?? '${vaultDefault.label} · default';
