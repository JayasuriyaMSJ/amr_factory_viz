import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:amr_factory_viz/MapPainter.dart';
import 'package:amr_factory_viz/app_drawer.dart';
import 'package:amr_factory_viz/core/themes/app_themes.dart';
import 'package:amr_factory_viz/models/routes.dart';
import 'package:amr_factory_viz/models/waypoints.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter/gestures.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

class FactoryMapPage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const FactoryMapPage({Key? key, required this.themeProvider})
    : super(key: key);

  @override
  State<FactoryMapPage> createState() => _FactoryMapPageState();
}

class _FactoryMapPageState extends State<FactoryMapPage>
    with TickerProviderStateMixin {
  String? _factoryPath;
  ui.Image? _loadedMapImage;
  MapMetadata? _mapMetadata;
  List<Waypoint> _waypoints = [];
  List<Route> _routes = [];
  bool _isLoading = false;
  late SharedPreferences _prefs;

  Waypoint? _selectedWaypoint;
  bool _showRoutes = true;
  double? _cursorWorldX;
  double? _cursorWorldY;
  List<Offset> _ZoneCoOrdinates = [];
  Map<String, List<Offset>> _ZoneHistory = {};
  bool _isZoneMode = false; // Toggle for zone creation mode
  String? _currentZoneName;

  late TransformationController _transformationController;
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _cursorWorldX = null;
    _cursorWorldY = null;
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final savedPath = _prefs.getString('factory_path');
    if (savedPath != null) {
      await _loadFactory(savedPath);
      await _loadSavedZones();
    }
  }

  Future<void> _pickFactory() async {
    setState(() {
      _isLoading = true;
      _cursorWorldX = null;
      _cursorWorldY = null;
    });

    try {
      final rootDirectory = await _getDefaultRootDirectory();
      final startDirectory = await _getStartDirectory();

      if (!mounted) return;

      String? path = await FilesystemPicker.open(
        title: 'Select Factory Folder',
        context: context,
        rootDirectory: rootDirectory,
        directory: startDirectory,
        fsType: FilesystemType.folder,
        pickText: 'Select this factory',
        folderIconColor: Theme.of(context).colorScheme.primary,
        requestPermission: () async => true,
        fileTileSelectMode: FileTileSelectMode.wholeTile,
        showGoUp: true,
      );

      if (mounted && path != null) {
        await _prefs.setString('factory_path', path);
        await _prefs.setString('last_browsed_path', path);
        await _loadFactory(path);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error picking factory: ${e.toString()}');
      }
    }
  }

  Future<void> _loadFactory(String path) async {
    try {
      setState(() {
        _factoryPath = path;
        _isLoading = true;
        _waypoints.clear();
        _routes.clear();
        _loadedMapImage = null;
        _mapMetadata = null;
        _cursorWorldX = null;
        _cursorWorldY = null;
        _selectedWaypoint = null;
        _ZoneCoOrdinates.clear();
        _ZoneHistory.clear();
      });

      // Load map image and metadata
      final mapDir = Directory('$path/map_data');
      if (await mapDir.exists()) {
        final mapFile = File('${mapDir.path}/map.png');
        final mapYamlFile = File('${mapDir.path}/map.yaml');
        if (await mapFile.exists()) {
          final image = await MapImageLoader.loadMapImage(mapFile);
          MapMetadata metadata = MapMetadata(
            resolution: 0.05,
            origin: Offset.zero,
          );
          if (await mapYamlFile.exists()) {
            final yamlContent = await mapYamlFile.readAsString();
            metadata = MapImageLoader.parseMapYaml(yamlContent);
          }
          if (mounted) {
            setState(() {
              _loadedMapImage = image;
              _mapMetadata = metadata;
            });
          }
        }
      }

      // Load waypoints
      final cpFile = File('$path/cp.yaml');
      if (await cpFile.exists()) {
        await _loadWaypoints(cpFile);
      }

      // Load routes
      final routesDir = Directory('$path/routes');
      if (await routesDir.exists()) {
        await _loadRoutes(routesDir);
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factory loaded: ${path.split('/').last}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Error loading factory: ${e.toString()}');
    }
  }

  Future<void> _loadWaypoints(File cpFile) async {
    final content = await cpFile.readAsString();
    final yaml = loadYaml(content);

    final totalPoints = yaml['total_points'] as int?;
    if (totalPoints == null) return;

    final waypoints = <Waypoint>[];

    for (int i = 0; i < totalPoints; i++) {
      waypoints.add(
        Waypoint(
          id: i,
          nickname: yaml['nickname$i']?.toString() ?? 'WP$i',
          x: _parseDouble(yaml['X$i']),
          y: _parseDouble(yaml['Y$i']),
          theta: _parseDouble(yaml['theta$i']),
          wpType: yaml['wp_type$i']?.toString() ?? 'WAYPOINT',
          isEnabled: true,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _waypoints = waypoints;
      });
    }
  }

  Future<void> _loadRoutes(Directory routesDir) async {
    final routes = <Route>[];

    await for (final file in routesDir.list()) {
      if (file is File && file.path.endsWith('.yaml')) {
        try {
          final content = await file.readAsString();
          final yaml = loadYaml(content);

          final totalPaths = yaml['total_paths'] as int?;
          if (totalPaths == null) continue;

          final points = <RoutePoint>[];

          for (int i = 0; i < totalPaths; i++) {
            points.add(
              RoutePoint(
                pts: yaml['pts$i'] as int? ?? 0,
                dir: yaml['dir$i']?.toString() ?? 'F',
                layer: yaml['layer$i']?.toString() ?? 'E',
              ),
            );
          }

          routes.add(
            Route(
              name: file.path.split('/').last.replaceAll('.yaml', ''),
              points: points,
              stoppingDistance: _parseDouble(yaml['stopping_distance']),
              isEnabled: true,
            ),
          );
        } catch (e) {
          debugPrint('Error loading route ${file.path}: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _routes = routes;
      });
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<Directory> _getDefaultRootDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0');
      if (await dir.exists()) return dir;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        final homeDir = Directory(home);
        if (await homeDir.exists()) return homeDir;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<Directory> _getStartDirectory() async {
    final savedPath = _prefs.getString('last_browsed_path');
    if (savedPath != null) {
      final dir = Directory(savedPath);
      if (await dir.exists()) return dir;
    }
    return await _getDefaultRootDirectory();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (_loadedMapImage == null || _mapMetadata == null) return;

    final RenderBox? renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPos = renderBox.globalToLocal(event.position);

    // Get the transformation matrix
    final matrix = _transformationController.value;

    // Get the map dimensions
    final mapWidth = _loadedMapImage!.width.toDouble();
    final mapHeight = _loadedMapImage!.height.toDouble();

    // Transform the local position to map coordinates
    final scaleX = matrix.getMaxScaleOnAxis();
    final translationX = matrix.getTranslation().x;
    final translationY = matrix.getTranslation().y;

    // Calculate position in map pixel space
    final mapPixelX = (localPos.dx - translationX) / scaleX;
    final mapPixelY = (localPos.dy - translationY) / scaleX;

    // Check if cursor is within map bounds
    if (mapPixelX < 0 ||
        mapPixelX > mapWidth ||
        mapPixelY < 0 ||
        mapPixelY > mapHeight) {
      if (mounted) {
        setState(() {
          _cursorWorldX = null;
          _cursorWorldY = null;
        });
      }
      return;
    }

    // Convert map pixel coordinates to world coordinates
    // Map Y is from top to bottom, world Y is from bottom to top
    final pixelYFromBottom = mapHeight - mapPixelY;
    final worldX =
        _mapMetadata!.origin.dx + mapPixelX * _mapMetadata!.resolution;
    final worldY =
        _mapMetadata!.origin.dy + pixelYFromBottom * _mapMetadata!.resolution;

    if (mounted) {
      setState(() {
        _cursorWorldX = worldX;
        _cursorWorldY = worldY;
      });
    }
  }

  void _handleDoubleTap() {
    if (_loadedMapImage == null || _mapMetadata == null) {
      return;
    }

    if (_cursorWorldX == null || _cursorWorldY == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No map coordinates found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      if (_ZoneCoOrdinates.length < 4) {
        _ZoneCoOrdinates.add(Offset(_cursorWorldX!, _cursorWorldY!));

        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Point ${_ZoneCoOrdinates.length}/4 added'),
            duration: const Duration(milliseconds: 500),
            backgroundColor: Colors.blue,
          ),
        );

        // Show zone complete dialog when 4 points are added
        if (_ZoneCoOrdinates.length == 4) {
          _showZoneCompleteDialog();
        }
      }
      if (_ZoneCoOrdinates.length >= 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Clear existing points to create further Zone points',
            ),
            duration: const Duration(milliseconds: 2000),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _handleTap(TapDownDetails details) {
    if (_loadedMapImage == null || _mapMetadata == null || _waypoints.isEmpty) {
      print("Hello");
      return;
    }
    final RenderBox? renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);

    // Get the transformation matrix
    final matrix = _transformationController.value;
    final scaleX = matrix.getMaxScaleOnAxis();
    final translationX = matrix.getTranslation().x;
    final translationY = matrix.getTranslation().y;

    // Calculate position in map pixel space
    final mapPixelX = (localPos.dx - translationX) / scaleX;
    final mapPixelY = (localPos.dy - translationY) / scaleX;

    final mapWidth = _loadedMapImage!.width.toDouble();
    final mapHeight = _loadedMapImage!.height.toDouble();

    // Find waypoints near the tap location
    List<Waypoint> nearbyWaypoints = [];
    const double threshold = 15.0; // pixels threshold in map space

    for (final wp in _waypoints.where((wp) => wp.isEnabled)) {
      // Convert waypoint world coordinates to map pixel coordinates
      final wpPixelX =
          (wp.x - _mapMetadata!.origin.dx) / _mapMetadata!.resolution;
      final wpPixelYFromBottom =
          (wp.y - _mapMetadata!.origin.dy) / _mapMetadata!.resolution;
      final wpPixelY = mapHeight - wpPixelYFromBottom;

      final dist = math.sqrt(
        math.pow(mapPixelX - wpPixelX, 2) + math.pow(mapPixelY - wpPixelY, 2),
      );

      if (dist < threshold) {
        nearbyWaypoints.add(wp);
      }
    }

    if (nearbyWaypoints.isEmpty) {
      setState(() {
        _selectedWaypoint = null;
      });
      return;
    }

    // If only one waypoint nearby, select it
    if (nearbyWaypoints.length == 1) {
      setState(() {
        _selectedWaypoint = nearbyWaypoints[0];
      });
      return;
    }

    // Multiple waypoints nearby - show selection dialog
    _showWaypointSelectionDialog(nearbyWaypoints);
  }

  void _showWaypointSelectionDialog(List<Waypoint> waypoints) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Waypoint'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: waypoints.length,
            itemBuilder: (context, index) {
              final wp = waypoints[index];
              return ListTile(
                leading: Icon(
                  Icons.location_on,
                  color: _getWaypointColorFromPainter(wp),
                ),
                title: Text(wp.nickname),
                subtitle: Text(
                  'ID: ${wp.id} | (${wp.x.toStringAsFixed(2)}, ${wp.y.toStringAsFixed(2)})',
                ),
                onTap: () {
                  setState(() {
                    _selectedWaypoint = wp;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Color _getWaypointColorFromPainter(Waypoint wp) {
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

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale < 10.0) {
      final newScale = (currentScale * 1.5).clamp(0.5, 10.0);
      final currentTranslation = _transformationController.value
          .getTranslation();
      _transformationController.value = Matrix4.identity()
        ..translate(currentTranslation.x, currentTranslation.y)
        ..scale(newScale);
    }
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 0.5) {
      final newScale = (currentScale / 1.5).clamp(0.5, 10.0);
      final currentTranslation = _transformationController.value
          .getTranslation();
      _transformationController.value = Matrix4.identity()
        ..translate(currentTranslation.x, currentTranslation.y)
        ..scale(newScale);
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeOption.values.map((option) {
            return RadioListTile<ThemeOption>(
              title: Text(option.name.toUpperCase()),
              value: option,
              groupValue: widget.themeProvider.themeOption,
              onChanged: (value) {
                if (value != null) {
                  widget.themeProvider.setTheme(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_factoryPath?.split('/').last ?? 'AMR Factory Map'),
        actions: [
          if (_loadedMapImage != null) ...[
            // _ZoneCoOrdinates.length == 4 ?
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Zone Mode: Double-tap to add points (4 points needed)',
                    ),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              tooltip: 'Zone Creation INFO',
            ),
            // : SizedBox.shrink(),
            // IconButton(
            //   icon: const Icon(Icons.add_to_photos_rounded),
            //   onPressed: () {},
            //   tooltip: 'Zones',
            // ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _zoomIn,
              tooltip: 'Zoom In',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _zoomOut,
              tooltip: 'Zoom Out',
            ),
            IconButton(
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _resetZoom,
              tooltip: 'Reset Zoom',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickFactory,
            tooltip: 'Select Factory',
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showThemeDialog,
            tooltip: 'Change Theme',
          ),
        ],
      ),
      drawer: Drawer(child: AppDrawer()),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _factoryPath == null
          ? _buildWelcomeScreen()
          : Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildMapView(constraints);
                    },
                  ),
                ),

                _buildSidebar(),
              ],
            ),
      floatingActionButton: _ZoneCoOrdinates.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _ZoneCoOrdinates.clear();
                  _currentZoneName = null;
                });
              },
              child: const Icon(Icons.clear),
              tooltip: 'Clear Zone Points',
            )
          : null,
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.factory,
            size: 100,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Select a Factory',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickFactory,
            icon: const Icon(Icons.folder_open),
            label: const Text('Browse Factories'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(BoxConstraints constraints) {
    if (_loadedMapImage == null) {
      return const Center(child: Text('No map image found'));
    }

    return Center(
      child: MouseRegion(
        onHover: _onPointerHover,
        child: GestureDetector(
          onTapDown: _handleTap,
          onDoubleTap: _handleDoubleTap,
          child: ClipRect(
            child: InteractiveViewer(
              key: _mapKey,
              transformationController: _transformationController,
              minScale: 0.1,
              maxScale: 17.0,
              constrained: false,
              child: CustomPaint(
                size: Size(
                  // constraints.maxWidth,
                  // constraints.maxHeight,
                  _loadedMapImage!.width.toDouble(),
                  _loadedMapImage!.height.toDouble(),
                ),
                painter: MapPainter(
                  mapImage: _loadedMapImage,
                  mapResolution: _mapMetadata!.resolution,
                  mapOrigin: _mapMetadata!.origin,
                  waypoints: _waypoints,
                  routes: _routes,
                  selectedWaypoint: _selectedWaypoint,
                  showRoutes: _showRoutes,
                  zonePoints: _ZoneCoOrdinates,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          // Fixed section - Cursor position and selected waypoint
          _buildSelectedWaypointInfo(),
          _buildCursorPosition(),
          const Divider(height: 1),
          _buildRoutesToggle(),
          const Divider(height: 1),
          _buildZonesSection(),
          const Divider(height: 1),
          // Scrollable section - Waypoints and Routes lists
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ExpansionTile(
                    title: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Text(
                        'Waypoints',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    children: [_buildWaypointsList()],
                    initiallyExpanded:
                        true, // Optional: start expanded; set to false if preferred
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ExpansionTile(
                    title: const Padding(
                      padding: EdgeInsets.all(5.0),
                      child: Text(
                        'Routes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    children: [_buildRoutesList()],
                    initiallyExpanded:
                        false, // Optional: start expanded; set to false if preferred
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                  ),
                  // _buildRoutesList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedWaypointInfo() {
    if (_selectedWaypoint == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Tap on waypoint to view details',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final wp = _selectedWaypoint!;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wp.nickname,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('ID', wp.id.toString()),
            _buildInfoRow('X', wp.x.toStringAsFixed(3)),
            _buildInfoRow('Y', wp.y.toStringAsFixed(3)),
            _buildInfoRow(
              'Theta',
              '${(wp.theta * 180 / math.pi).toStringAsFixed(1)}°',
            ),
            _buildInfoRow('Type', wp.wpType),
          ],
        ),
      ),
    );
  }

  Widget _buildCursorPosition() {
    if (_cursorWorldX == null || _cursorWorldY == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.my_location,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cursor Position',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('X', _cursorWorldX!.toStringAsFixed(3)),
            _buildInfoRow('Y', _cursorWorldY!.toStringAsFixed(3)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesToggle() {
    return SwitchListTile(
      title: const Text('Show Routes'),
      value: _showRoutes,
      onChanged: (value) {
        setState(() {
          _showRoutes = value;
        });
      },
    );
  }

  Widget _buildWaypointsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _waypoints.length,
      itemBuilder: (context, index) {
        final wp = _waypoints[index];
        return ListTile(
          dense: true,
          leading: Icon(
            Icons.location_on,
            size: 20,
            color: wp.isEnabled
                ? (wp == _selectedWaypoint
                      ? Colors.red
                      : _getWaypointColorFromPainter(wp))
                : Colors.grey,
          ),
          title: Text(wp.nickname, style: TextStyle(fontSize: 13)),
          subtitle: Text(
            'ID: ${wp.id} | (${wp.x.toStringAsFixed(2)}, ${wp.y.toStringAsFixed(2)})',
            style: TextStyle(fontSize: 11),
          ),
          trailing: Switch(
            value: wp.isEnabled,
            onChanged: (value) {
              setState(() {
                wp.isEnabled = value;
                if (!value && wp == _selectedWaypoint) {
                  _selectedWaypoint = null;
                }
              });
            },
          ),
          selected: wp == _selectedWaypoint,
          onTap: () {
            if (wp.isEnabled) {
              setState(() {
                _selectedWaypoint = wp;
              });
            }
          },
        );
      },
    );
  }

  Widget _buildRoutesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _routes.length,
      itemBuilder: (context, index) {
        final route = _routes[index];
        return ListTile(
          dense: true,
          leading: Icon(
            Icons.route,
            size: 20,
            color: route.isEnabled
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          title: Text(route.name, style: TextStyle(fontSize: 13)),
          subtitle: Text(
            '${route.points.length} waypoints',
            style: TextStyle(fontSize: 11),
          ),
          trailing: Switch(
            value: route.isEnabled,
            onChanged: (value) {
              setState(() {
                route.isEnabled = value;
              });
            },
          ),
        );
      },
    );
  }

  ///////////////////////////////////* ZONE *//////////////////////////////////////////
  Future<void> _loadSavedZones() async {
    if (_factoryPath == null) return;

    final zoneKeys = _prefs.getStringList('zone_keys_$_factoryPath') ?? [];
    final Map<String, List<Offset>> loadedZones = {};

    for (final zoneName in zoneKeys) {
      final key = 'zone_${_factoryPath}_$zoneName';
      final zoneData = _prefs.getString(key);

      if (zoneData != null) {
        try {
          final points = zoneData.split(';').map((p) {
            final coords = p.split(',');
            return Offset(double.parse(coords[0]), double.parse(coords[1]));
          }).toList();

          if (points.length == 4) {
            loadedZones[zoneName] = points;
          }
        } catch (e) {
          debugPrint('Error loading zone $zoneName: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _ZoneHistory = loadedZones;
      });
    }
  }

  Widget _buildZonesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Zones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${_ZoneHistory.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showSavedZonesDialog,
            icon: const Icon(Icons.layers, size: 18),
            label: const Text('View All Zones'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 36),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavedZonesDialog() {
    if (_ZoneHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved zones found for this factory'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Zones'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _ZoneHistory.keys.length,
            itemBuilder: (context, index) {
              final zoneName = _ZoneHistory.keys.elementAt(index);
              final points = _ZoneHistory[zoneName]!;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ExpansionTile(
                  leading: const Icon(Icons.location_city, color: Colors.blue),
                  title: Text(
                    zoneName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('4 points'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < points.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'P${i + 1}: X=${points[i].dx.toStringAsFixed(3)}, '
                                'Y=${points[i].dy.toStringAsFixed(3)}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    // _ZoneCoOrdinates.clear();
                                    print(_ZoneHistory);
                                    print(points);

                                    _ZoneCoOrdinates = List.from(points);
                                    _isZoneMode = true;
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Zone "$zoneName" loaded.'),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                ),
                                label: const Text('Load'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  _deleteZone(zoneName);
                                  Navigator.pop(context);
                                  _showSavedZonesDialog(); // Refresh dialog
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _deleteZone(String zoneName) async {
    if (_factoryPath == null) return;

    // Remove from SharedPreferences
    final key = 'zone_${_factoryPath}_$zoneName';
    await _prefs.remove(key);

    // Update zone list
    final zoneKeys = _prefs.getStringList('zone_keys_$_factoryPath') ?? [];
    zoneKeys.remove(zoneName);
    await _prefs.setStringList('zone_keys_$_factoryPath', zoneKeys);

    // Update local state
    setState(() {
      _ZoneHistory.remove(zoneName);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Zone "$zoneName" deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _saveZone() async {
    if (_factoryPath == null || _ZoneCoOrdinates.length != 4) return;

    // Prompt user for zone name
    final zoneName = await _promptForZoneName();
    if (zoneName == null || zoneName.isEmpty) return;

    // Convert Offset list to string for storage
    final zoneData = _ZoneCoOrdinates.map((p) => '${p.dx},${p.dy}').join(';');

    // Save to SharedPreferences
    final key = 'zone_${_factoryPath}_$zoneName';
    await _prefs.setString(key, zoneData);

    // Update history
    setState(() {
      print("Saving ............. $_ZoneCoOrdinates");

      _ZoneHistory[zoneName] = List.from(_ZoneCoOrdinates);
      print("Saved .........;.... $_ZoneHistory");
    });

    // Save zone list
    final zoneKeys = _prefs.getStringList('zone_keys_$_factoryPath') ?? [];
    if (!zoneKeys.contains(zoneName)) {
      zoneKeys.add(zoneName);
      await _prefs.setStringList('zone_keys_$_factoryPath', zoneKeys);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zone "$zoneName" saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<String?> _promptForZoneName() async {
    final controller = TextEditingController(
      text: 'Zone_${DateTime.now().millisecondsSinceEpoch}',
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Zone'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Zone Name',
            hintText: 'Enter zone name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showZoneCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zone Co-Ordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const Text('4 points added successfully:'),
            const SizedBox(height: 8),
            for (int i = 0; i < _ZoneCoOrdinates.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'P${i + 1}: X=${_ZoneCoOrdinates[i].dx.toStringAsFixed(3)}, '
                  'Y=${_ZoneCoOrdinates[i].dy.toStringAsFixed(3)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 25),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _ZoneCoOrdinates.clear();
                _currentZoneName = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveZone();
              print("Saved ======= $_ZoneCoOrdinates");
              setState(() {
                // _ZoneCoOrdinates.clear();
                _currentZoneName = null;
              });
            },
            child: const Text('Save Zone'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}
