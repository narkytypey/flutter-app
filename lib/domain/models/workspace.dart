/// Whether a workspace keeps its storage between runs of the app.
enum StorageRule { keep, wipeOnExit }

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.markerIndex,
    required this.storageRule,
    this.requirePin = false,
    this.showInDecoy = false,
    this.sortIndex = 0,
  });

  final String id;
  final String name;

  /// Index into `C.markers` — the five swatches in the picker (spec `10b`).
  final int markerIndex;
  final StorageRule storageRule;

  /// "Ask for PIN to enter · Applies to the whole workspace" (spec `10b`).
  final bool requirePin;

  /// "Show in decoy vault · Off keeps it invisible behind the second PIN".
  final bool showInDecoy;
  final int sortIndex;

  Workspace copyWith({
    String? name,
    int? markerIndex,
    StorageRule? storageRule,
    bool? requirePin,
    bool? showInDecoy,
    int? sortIndex,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      markerIndex: markerIndex ?? this.markerIndex,
      storageRule: storageRule ?? this.storageRule,
      requirePin: requirePin ?? this.requirePin,
      showInDecoy: showInDecoy ?? this.showInDecoy,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Workspace &&
      other.id == id &&
      other.name == name &&
      other.markerIndex == markerIndex &&
      other.storageRule == storageRule &&
      other.requirePin == requirePin &&
      other.showInDecoy == showInDecoy &&
      other.sortIndex == sortIndex;

  @override
  int get hashCode => Object.hash(
      id, name, markerIndex, storageRule, requirePin, showInDecoy, sortIndex);
}
