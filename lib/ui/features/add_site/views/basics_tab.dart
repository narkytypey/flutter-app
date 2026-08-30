import 'package:flutter/material.dart';

import '../../../../domain/models/site.dart';
import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `2a`, Basics tab: address, name (with a live monogram chip),
/// workspace choice and cookie policy.
class BasicsTab extends StatelessWidget {
  const BasicsTab({
    super.key,
    required this.urlController,
    required this.nameController,
    required this.monogram,
    required this.workspaces,
    required this.workspaceId,
    required this.onWorkspaceChanged,
    required this.cookiePolicy,
    required this.onCookiePolicyChanged,
  });

  final TextEditingController urlController;
  final TextEditingController nameController;
  final String monogram;
  final List<Workspace> workspaces;
  final String workspaceId;
  final ValueChanged<String> onWorkspaceChanged;
  final CookiePolicy cookiePolicy;
  final ValueChanged<CookiePolicy> onCookiePolicyChanged;

  static const _label = TextStyle(
    fontFamily: 'Figtree',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    color: C.textFaint,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ADDRESS', style: _label),
        const SizedBox(height: 7),
        _field(key: const Key('add-site-address'), controller: urlController),
        const SizedBox(height: 18),
        const Text('NAME', style: _label),
        const SizedBox(height: 7),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.line09),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('add-site-name'),
                  controller: nameController,
                  style: ui(size: 14, color: C.textSecondary),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.monogramOpen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(monogram, style: ui(size: 12, weight: 600, color: C.monogramText)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('WORKSPACE', style: _label),
        const SizedBox(height: 7),
        Row(
          children: [
            for (final workspace in workspaces) ...[
              if (workspace != workspaces.first) const SizedBox(width: 8),
              Expanded(child: _workspaceChip(workspace)),
            ],
          ],
        ),
        const SizedBox(height: 18),
        const Text('COOKIES', style: _label),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.line08),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _cookieRow(
                title: 'Keep for this site',
                subtitle: 'Stays signed in, isolated from other sites',
                selected: cookiePolicy == CookiePolicy.keep,
                onTap: () => onCookiePolicyChanged(CookiePolicy.keep),
              ),
              _cookieRow(
                title: 'Wipe on exit',
                subtitle: 'Cookies, cache and form history destroyed',
                selected: cookiePolicy == CookiePolicy.wipeOnExit,
                onTap: () => onCookiePolicyChanged(CookiePolicy.wipeOnExit),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field({required Key key, required TextEditingController controller}) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line09),
        ),
        child: TextField(
          key: key,
          controller: controller,
          style: ui(size: 13, color: C.textSecondary),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      );

  Widget _workspaceChip(Workspace workspace) {
    final selected = workspace.id == workspaceId;
    return GestureDetector(
      onTap: () => onWorkspaceChanged(workspace.id),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.selected : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? C.line10 : C.line07),
        ),
        child: Text(workspace.name,
            style: ui(size: 13, color: selected ? C.textPrimary : C.tabInactive)),
      ),
    );
  }

  Widget _cookieRow({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: C.surface,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: ui(size: 13.5, color: selected ? C.textPrimary : C.textTertiary)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: ui(size: 11, color: C.textFaint)),
                ],
              ),
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.bg,
                border: Border.all(color: selected ? C.jade : C.pinEmpty, width: selected ? 5 : 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
