import 'package:flutter/material.dart';

import '../../../../domain/models/site.dart';
import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/choice_chip.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/monogram.dart';
import 'form_input.dart';

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
    this.addressFocus,
  });

  final FocusNode? addressFocus;
  final TextEditingController urlController;
  final TextEditingController nameController;
  final String monogram;
  final List<Workspace> workspaces;
  final String workspaceId;
  final ValueChanged<String> onWorkspaceChanged;
  final CookiePolicy cookiePolicy;
  final ValueChanged<CookiePolicy> onCookiePolicyChanged;

  static final _label = T.sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ADDRESS', style: _label),
        const SizedBox(height: 8),
        FormInput(
          child: TextField(
            key: const Key('add-site-address'),
            controller: urlController,
            focusNode: addressFocus,
            style: T.value.copyWith(color: C.textPrimary),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
        const SizedBox(height: 20),
        Text('NAME', style: _label),
        const SizedBox(height: 8),
        FormInput(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('add-site-name'),
                  controller: nameController,
                  style: T.body.copyWith(color: C.textPrimary),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Monogram(monogram, size: 32, radius: R.monogram, fontSize: 13),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('WORKSPACE', style: _label),
        const SizedBox(height: 4),
        // Up to three share the row as the spec draws them; more scroll
        // sideways at their own width, so no name is clipped.
        if (workspaces.length <= 3)
          Row(
            children: [
              for (final workspace in workspaces) ...[
                if (workspace != workspaces.first) const SizedBox(width: 8),
                Flexible(child: _workspaceChip(workspace)),
              ],
            ],
          )
        else
          SingleChildScrollView(
            key: const Key('workspace-chips-scroll'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final workspace in workspaces) ...[
                  if (workspace != workspaces.first) const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: _workspaceChip(workspace),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text('COOKIES', style: _label),
        const SizedBox(height: 8),
        Group(
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
      ],
    );
  }

  Widget _workspaceChip(Workspace workspace) => AppChip(
        label: workspace.name,
        selected: workspace.id == workspaceId,
        onTap: () => onWorkspaceChanged(workspace.id),
      );

  Widget _cookieRow({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: selected ? T.rowTitle : T.rowTitleIdle),
                      const SizedBox(height: 2),
                      Text(subtitle, style: T.sub),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _radio(selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Restyle v2 §5: a 20 dp edge ring; selected, a text-1 ring and dot.
  Widget _radio(bool selected) => Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? C.textPrimary : C.edge, width: 2),
        ),
        child: selected
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: C.textPrimary),
              )
            : null,
      );
}
