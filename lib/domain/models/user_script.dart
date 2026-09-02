import 'package:flutter/material.dart' show Color;

/// Spec `10d`'s badge colours: CSS reads `#9FD8C0` (the jade-code tone code
/// blocks use elsewhere), JS reads `#D6A45B` (warning).
enum ScriptKind {
  css('CSS'),
  js('JS');

  const ScriptKind(this.badge);
  final String badge;

  Color get badgeColor => switch (this) {
        ScriptKind.css => const Color(0xFF9FD8C0),
        ScriptKind.js => const Color(0xFFD6A45B),
      };
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
