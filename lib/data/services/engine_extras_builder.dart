import '../../domain/models/engine_extras.dart';
import '../../domain/models/security_level.dart';
import '../../domain/models/site.dart';
import '../../domain/repositories/filter_list_repository.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/repositories/script_repository.dart';
import 'bundled_filter_lists.dart';

/// Reads the open vault's enabled lists, [site]'s scripts and the level it
/// runs at (its own, or the vault default in [settings]). Throws if the
/// vault or a bundled file cannot be read — the caller must not open the
/// site then, rather than open it unfiltered.
Future<EngineExtras> engineExtrasFor(
  Site site, {
  required FilterListRepository filterLists,
  required ScriptRepository scripts,
  required BundledFilterRules rules,
  required SettingsRepository settings,
}) async {
  final enabled = {
    for (final list in await filterLists.all())
      if (list.enabled) list.id,
  };
  final filterRules = <String, List<String>>{};
  for (final list in rules.lists) {
    if (!enabled.contains(list.id)) continue;
    (await rules.rulesFor(list)).forEach((category, listRules) {
      (filterRules[category] ??= []).addAll(listRules);
    });
  }
  // Read now, never cached: a default changed in Settings reaches the next
  // open (spec §2.4).
  final vaultDefault =
      SecurityLevel.vaultDefaultFrom(await settings.getString(securityLevelSettingKey));
  return EngineExtras(
    filterRules: filterRules,
    userScripts: [
      for (final script in selectUserScripts(site, await scripts.all()))
        InjectedScript.from(script),
    ],
    securityLevel: effectiveLevel(site, vaultDefault),
  );
}
