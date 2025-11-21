import 'dart:io';

import 'package:amr_factory_viz/core/themes/app_themes.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FolderPickerPage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const FolderPickerPage({Key? key, required this.themeProvider})
      : super(key: key);

  @override
  State<FolderPickerPage> createState() => _FolderPickerPageState();
}

class _FolderPickerPageState extends State<FolderPickerPage> {
  String? _selectedPath;
  String? _lastBrowsedPath;
  bool _isLoading = false;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPath = _prefs.getString('selected_path');
      _lastBrowsedPath = _prefs.getString('last_browsed_path');
    });
  }

  Future<Directory> _getStartDirectory() async {
    // If we have a last browsed path, use it as starting point
    if (_lastBrowsedPath != null) {
      final dir = Directory(_lastBrowsedPath!);
      if (await dir.exists()) {
        return dir;
      }
    }

    // Otherwise, start from documents directory
    return await _getDefaultRootDirectory();
  }

  Future<Directory> _getDefaultRootDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Start from external storage root
        final dir = Directory('/storage/emulated/0');
        if (await dir.exists()) {
          return dir;
        }
        return await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Try to get user's home folder as root
        final home = Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'];
        if (home != null) {
          final homeDir = Directory(home);
          if (await homeDir.exists()) {
            return homeDir;
          }
        }
        return Directory.current;
      }
    } catch (e) {
      debugPrint('Error getting root directory: $e');
    }

    return await getApplicationDocumentsDirectory();
  }

  Future<void> _pickFolder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rootDirectory = await _getDefaultRootDirectory();
      final startDirectory = await _getStartDirectory();

      if (!mounted) return;

      String? path = await FilesystemPicker.open(
        title: 'Select Folder',
        context: context,
        rootDirectory: rootDirectory,
        directory: startDirectory,
        fsType: FilesystemType.folder,
        pickText: 'Select this folder',
        folderIconColor: Theme.of(context).colorScheme.primary,
        requestPermission: () async => true,
        fileTileSelectMode: FileTileSelectMode.wholeTile,
        showGoUp: true,
      );

      if (mounted && path != null) {
        await _prefs.setString('selected_path', path);
        await _prefs.setString('last_browsed_path', path);

        setState(() {
          _selectedPath = path;
          _lastBrowsedPath = path;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Folder selected successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeOption>(
              title: const Text('System Default'),
              value: ThemeOption.system,
              groupValue: widget.themeProvider.themeOption,
              onChanged: (value) {
                if (value != null) {
                  widget.themeProvider.setTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeOption>(
              title: const Text('Light'),
              value: ThemeOption.light,
              groupValue: widget.themeProvider.themeOption,
              onChanged: (value) {
                if (value != null) {
                  widget.themeProvider.setTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeOption>(
              title: const Text('Dark'),
              value: ThemeOption.dark,
              groupValue: widget.themeProvider.themeOption,
              onChanged: (value) {
                if (value != null) {
                  widget.themeProvider.setTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isMediumScreen = size.width >= 600 && size.width < 1024;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder Picker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Change Theme',
            onPressed: _showThemeDialog,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerHighest,
                  ]
                : [
                    theme.colorScheme.primaryContainer.withOpacity(0.3),
                    theme.colorScheme.secondaryContainer.withOpacity(0.3),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      isSmallScreen ? 24.0 : (isMediumScreen ? 48.0 : 64.0),
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icon
                      Icon(
                        Icons.folder_open,
                        size: isSmallScreen ? 80 : 100,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Folder Picker',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 32 : 42,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subtitle
                      Text(
                        'Select a folder from your device',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Pick Folder Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _pickFolder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 16 : 20,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.folder_outlined, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Browse Folders',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      // Selected Path Card
                      if (_selectedPath != null) ...[
                        const SizedBox(height: 32),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Selected Folder',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.folder,
                                        color: theme.colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedPath!,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontFamily: 'monospace',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}