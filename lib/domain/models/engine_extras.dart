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
/// the enabled filter lists' rules by category, and the library scripts
/// applied to it. Empty means nothing blocked and nothing injected.
class EngineExtras {
  const EngineExtras({this.filterRules = const {}, this.userScripts = const []});

  static const none = EngineExtras();

  final Map<String, List<String>> filterRules;
  final List<InjectedScript> userScripts;
}

/// The library scripts that run on [site]: switched on and applied to it,
/// in library order.
List<UserScript> selectUserScripts(Site site, List<UserScript> scripts) => [
      for (final script in scripts)
        if (script.enabled && script.appliedSiteIds.contains(site.id)) script,
    ];
