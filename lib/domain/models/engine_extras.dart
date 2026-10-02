import 'security_level.dart';
import 'site.dart';
import 'user_script.dart';

/// A library script as the engine receives it.
class InjectedScript {
  const InjectedScript({
    required this.kind,
    required this.code,
    required this.atDocumentStart,
  });

  InjectedScript.from(UserScript script)
      : kind = script.kind,
        code = script.code,
        atDocumentStart = script.runAtDocumentStart;

  final ScriptKind kind;
  final String code;
  final bool atDocumentStart;

  Map<String, Object> toMap() =>
      {'kind': kind.name, 'code': code, 'atDocumentStart': atDocumentStart};
}

/// What a site opens with beyond its own settings, read from the open vault:
/// the enabled filter lists' rules by category, the library scripts applied
/// to it, and the security level it runs at. Empty means nothing blocked,
/// nothing injected, and Standard.
class EngineExtras {
  const EngineExtras({
    this.filterRules = const {},
    this.userScripts = const [],
    this.securityLevel = SecurityLevel.standard,
  });

  static const none = EngineExtras();

  final Map<String, List<String>> filterRules;
  final List<InjectedScript> userScripts;

  /// The level this open runs at: the site's own, or the vault default
  /// (privacy-controls spec §2.2). Kotlin is never told "follow the default".
  final SecurityLevel securityLevel;
}

/// The library scripts that run on [site]: switched on and applied to it,
/// in library order.
List<UserScript> selectUserScripts(Site site, List<UserScript> scripts) => [
      for (final script in scripts)
        if (script.enabled && script.appliedSiteIds.contains(site.id)) script,
    ];
