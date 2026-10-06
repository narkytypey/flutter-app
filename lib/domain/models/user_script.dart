/// What a library script is. The badge's colour is the view's choice
/// (restyle v2 §2.8): a domain model holds no colours.
enum ScriptKind {
  css('CSS'),
  js('JS');

  const ScriptKind(this.badge);
  final String badge;
}

class UserScript {
  const UserScript({
    required this.id,
    required this.name,
    required this.kind,
    required this.code,
    required this.runAtDocumentStart,
    required this.enabled,
    required this.appliedSiteIds,
  });

  final String id;
  final String name;
  final ScriptKind kind;
  final String code;

  /// Feeds Plan 3's `Shields.apply` -> `addDocumentStartJavaScript` seam.
  final bool runAtDocumentStart;
  final bool enabled;
  final List<String> appliedSiteIds;

  UserScript copyWith({
    String? name,
    ScriptKind? kind,
    String? code,
    bool? runAtDocumentStart,
    bool? enabled,
    List<String>? appliedSiteIds,
  }) {
    return UserScript(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      code: code ?? this.code,
      runAtDocumentStart: runAtDocumentStart ?? this.runAtDocumentStart,
      enabled: enabled ?? this.enabled,
      appliedSiteIds: appliedSiteIds ?? this.appliedSiteIds,
    );
  }
}
