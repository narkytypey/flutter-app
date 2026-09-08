import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/status_rail.dart';
import '../view_models/search_view.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.results,
    required this.onQueryChanged,
    required this.onOpen,
    required this.onBack,
  });

  final TextEditingController controller;
  final List<SearchResultEntry> results;
  final ValueChanged<String> onQueryChanged;
  final void Function(String siteId) onOpen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final showNoMatch = results.isEmpty && controller.text.isNotEmpty;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Text('‹', style: TextStyle(fontSize: 16, color: C.icon)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.line09),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: C.icon),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const Key('search-field'),
                              controller: controller,
                              autofocus: true,
                              onChanged: onQueryChanged,
                              style: ui(size: 14, color: C.textSecondary),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'Search sites',
                                hintStyle: ui(size: 14, color: C.textFaint),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: showNoMatch
                  ? Center(
                      child: Text('No sites match "${controller.text}"',
                          style: ui(size: 13, color: C.textDim)),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children: [
                        for (final entry in results)
                          _SearchResultRow(entry: entry, onTap: () => onOpen(entry.siteId)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.entry, required this.onTap});

  final SearchResultEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line05)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              StatusRail(live: entry.live),
              const SizedBox(width: 12),
              Monogram(entry.monogram, open: entry.live),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: entry.live ? T.rowTitle : T.rowTitleIdle),
                    const SizedBox(height: 3),
                    Text(
                      entry.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: entry.live ? T.meta : T.metaIdle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: C.markers[entry.markerIndex],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(entry.workspaceName, style: ui(size: 11, color: C.textFaint)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
