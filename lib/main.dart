import 'package:amr_factory_viz/Factory_Map_Page.dart';
import 'package:amr_factory_viz/core/themes/app_themes.dart';
import 'package:amr_factory_viz/folder_picker.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AMR Factory Debug - MSJ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeProvider.themeMode,
      home: FactoryMapPage(
        themeProvider: _themeProvider,
      ), // FolderPickerPage(themeProvider: _themeProvider)
    );
  }
}
