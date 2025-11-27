import 'package:flutter/material.dart';
import 'package:amr_factory_viz/models/waypoints.dart';

class WaypointSearchDialog extends StatefulWidget {
  final List<Waypoint> waypoints;
  final Function(Waypoint) onWaypointSelected;

  const WaypointSearchDialog({
    Key? key,
    required this.waypoints,
    required this.onWaypointSelected,
  }) : super(key: key);

  @override
  State<WaypointSearchDialog> createState() => _WaypointSearchDialogState();
}

class _WaypointSearchDialogState extends State<WaypointSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Waypoint> _filteredWaypoints = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredWaypoints = widget.waypoints.where((wp) => wp.isEnabled).toList();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredWaypoints = widget.waypoints
            .where((wp) => wp.isEnabled)
            .toList();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Efficient filtering for large lists
    final results = <Waypoint>[];

    for (final wp in widget.waypoints) {
      if (!wp.isEnabled) continue;

      // Search by nickname (most common)
      if (wp.nickname.toLowerCase().contains(query)) {
        results.add(wp);
        continue;
      }

      // Search by ID
      if (wp.id.toString().contains(query)) {
        results.add(wp);
        continue;
      }

      // Search by type
      if (wp.wpType.toLowerCase().contains(query)) {
        results.add(wp);
        continue;
      }

      // Search by coordinates (for precise searches)
      if (wp.x.toStringAsFixed(2).contains(query) ||
          wp.y.toStringAsFixed(2).contains(query)) {
        results.add(wp);
      }

      // Limit results for performance (show first 100 matches)
      if (results.length >= 100) break;
    }

    setState(() {
      _filteredWaypoints = results;
      _isSearching = false;
    });
  }

  Color _getWaypointColor(Waypoint wp) {
    switch (wp.wpType) {
      case 'CHARGING':
        return Colors.green;
      case 'PARKING':
        return Colors.orange;
      case 'LOADING':
        return Colors.purple;
      case 'UNLOADING':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.search, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Search Waypoints',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name, ID, type, or coordinates...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results info
            Row(
              children: [
                Text(
                  '${_filteredWaypoints.length} waypoint${_filteredWaypoints.length == 1 ? '' : 's'} found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_isSearching) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),

            // Results list
            Expanded(
              child: _filteredWaypoints.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No waypoints found',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredWaypoints.length,
                      itemBuilder: (context, index) {
                        final wp = _filteredWaypoints[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getWaypointColor(wp),
                              child: Text(
                                wp.id.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              wp.nickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Type: ${wp.wpType}'),
                                Text(
                                  'Position: (${wp.x.toStringAsFixed(2)}, ${wp.y.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onTap: () {
                              widget.onWaypointSelected(wp);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
