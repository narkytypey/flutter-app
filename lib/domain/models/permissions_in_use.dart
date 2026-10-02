import 'permissions.dart';
import 'site.dart';

/// One row of `6c`'s permissions (privacy-controls spec §3).
class PermissionInUse {
  const PermissionInUse(this.kind, {required this.whileOpen});
  final PermissionKind kind;

  /// True for an "allow while this site is open" grant, which can be
  /// revoked; false for a grant stored in `2a`, changed only through Edit.
  final bool whileOpen;
}

/// What [site] may use now, in `2a`'s HARDWARE order: its stored grants and
/// this session's [grants]. "Allow once" is never tracked, so never listed.
List<PermissionInUse> permissionsInUse(Site site, Set<PermissionKind> grants) {
  bool stored(PermissionKind kind) => switch (kind) {
        PermissionKind.camera => site.allowCamera,
        PermissionKind.microphone => site.allowMicrophone,
        PermissionKind.location => site.allowLocation,
        PermissionKind.clipboard => site.allowClipboard,
      };
  return [
    for (final kind in PermissionKind.values)
      if (stored(kind))
        PermissionInUse(kind, whileOpen: false)
      else if (grants.contains(kind))
        PermissionInUse(kind, whileOpen: true),
  ];
}
