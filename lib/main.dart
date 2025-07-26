// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, avoid_print, use_build_context_synchronously, unused_local_variable, no_leading_underscores_for_local_identifiers, unused_element

import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:orgchart/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'models/employee.dart';
import 'models/tab.dart';
import 'db_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(),
    );
  }
}

class TabbedOrgChartScreen extends StatefulWidget {
  @override
  _TabbedOrgChartScreenState createState() => _TabbedOrgChartScreenState();
}

class _TabbedOrgChartScreenState extends State<TabbedOrgChartScreen>
    with TickerProviderStateMixin {
  final Graph graph = Graph();
  final BuchheimWalkerConfiguration config = BuchheimWalkerConfiguration();
  List<Employee> employees = [];
  List<TabModel> tabs = [];
  List<String> dynamicFieldNames = [];
  List<StaticField> staticFields = [];
  Map<int, bool> _expandedNodes = {};
  final Color defaultColor = Colors.blue[100]!;
  final List<Color> availableColors = [
    Colors.blue[100]!, // Default color
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.cyan,
    Colors.amber,
    Colors.indigo, // Added
    Colors.lime, // Added
    Colors.deepOrange, // Added
    Colors.blueGrey, // Added
    Colors.brown, // Added
    Colors.grey, // Added
    Colors.lightBlue, // Added
    Colors.deepPurple, // Added
    Colors.lightGreen, // Added
    Colors.redAccent,
  ];
  TabController? _tabController;
  int? currentTabId;
  String appBarTitle = 'چارت سازمانی';

  @override
  void initState() {
    super.initState();
    config
      ..siblingSeparation = 50
      ..levelSeparation = 100
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
    _loadTabsAndEmployees();
    _loadDynamicFieldNames();
    _loadStaticFields();
    _loadAppBarTitle(); // Load the title
  }

  String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString; // Fallback to raw string if parsing fails
    }
  }

  Future<void> _loadAppBarTitle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      appBarTitle = prefs.getString('appBarTitle') ?? 'چارت سازمانی';
    });
  }

  Future<void> _saveAppBarTitle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appBarTitle', title);
    setState(() {
      appBarTitle = title;
    });
  }

  Future<void> _loadDynamicFieldNames() async {
    try {
      final fieldNames = await DatabaseHelper.instance.getDynamicFieldNames();
      setState(() {
        dynamicFieldNames = fieldNames;
      });
    } catch (e) {
      print('Error loading dynamic field names: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری نام‌های فیلدهای پویا: $e')),
      );
    }
  }

  void _renameTab(BuildContext context, TabModel tab) {
    final _formKey = GlobalKey<FormState>();
    String tabName = tab.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغییر نام تب'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            initialValue: tabName,
            decoration: InputDecoration(labelText: 'نام تب'),
            textDirection: TextDirection.rtl,
            validator: (value) => value!.isEmpty ? 'نام تب را وارد کنید' : null,
            onSaved: (value) => tabName = value!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('کنسل'),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                try {
                  // Update the tab name in the database
                  final updatedTab = TabModel(id: tab.id, name: tabName);
                  await DatabaseHelper.instance.updateTab(updatedTab);
                  await _loadTabsAndEmployees();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('نام تب با موفقیت تغییر کرد')),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در تغییر نام تب: $e')),
                  );
                }
              }
            },
            child: Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStaticFields() async {
    try {
      final fields = await DatabaseHelper.instance.getStaticFields();
      setState(() {
        staticFields = fields;
      });
    } catch (e) {
      print('Error loading static fields: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری فیلدهای ثابت: $e')),
      );
    }
  }

  Future<void> _deleteTab(int tabId) async {
    if (tabs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حداقل باید یک تب وجود داشته باشد')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف تب'),
        content: Text(
            'آیا مطمئن هستید که می‌خواهید این تب و تمام کارمندان آن را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('خیر'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('بله', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteTab(tabId);
        await _loadTabsAndEmployees();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تب با موفقیت حذف شد')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف تب: $e')),
        );
      }
    }
  }

  Future<void> _loadTabsAndEmployees() async {
    try {
      final loadedTabs = await DatabaseHelper.instance.getTabs();
      final loadedEmployees = await DatabaseHelper.instance.getEmployees();

      setState(() {
        _tabController?.dispose();

        if (loadedTabs.isEmpty) {
          final defaultTab = TabModel(name: 'Tab 1');
          DatabaseHelper.instance.insertTab(defaultTab).then((insertedId) {
            defaultTab.id = insertedId;
            setState(() {
              tabs = [defaultTab];
              employees = loadedEmployees;
              currentTabId = defaultTab.id!;
              _expandedNodes = {for (var emp in employees) emp.id!: true};
              _tabController = TabController(length: tabs.length, vsync: this);
              _buildGraph();
              _tabController!.addListener(() {
                if (!_tabController!.indexIsChanging) {
                  setState(() {
                    currentTabId = tabs[_tabController!.index].id!;
                    _buildGraph();
                  });
                }
              });
            });
          });
        } else {
          tabs = loadedTabs;
          employees = loadedEmployees;
          _expandedNodes = {for (var emp in employees) emp.id!: true};
          currentTabId = currentTabId ?? tabs.first.id!;
          _tabController = TabController(length: tabs.length, vsync: this);

          final currentTabIndex =
              tabs.indexWhere((tab) => tab.id == currentTabId);
          _tabController!.index = currentTabIndex >= 0 ? currentTabIndex : 0;
          currentTabId = tabs[_tabController!.index].id!;
          _buildGraph();
          _tabController!.addListener(() {
            if (!_tabController!.indexIsChanging) {
              setState(() {
                currentTabId = tabs[_tabController!.index].id!;
                _buildGraph();
              });
            }
          });
        }
      });
    } catch (e) {
      print('ارور لود اطلاعات: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در بارگذاری اطلاعات: $e')),
      );
    }
  }

  void _editAppBarTitle(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    String newTitle = appBarTitle;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغییر عنوان برنامه'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            initialValue: appBarTitle,
            decoration: InputDecoration(labelText: 'عنوان برنامه'),
            textDirection: TextDirection.rtl,
            validator: (value) => value!.isEmpty ? 'عنوان را وارد کنید' : null,
            onSaved: (value) => newTitle = value!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('کنسل'),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                try {
                  await _saveAppBarTitle(newTitle);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('عنوان برنامه با موفقیت تغییر کرد')),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در تغییر عنوان برنامه: $e')),
                  );
                }
              }
            },
            child: Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _buildGraph() {
    graph.nodes.clear();
    graph.edges.clear();
    final Map<int, Node> nodeMap = {};

    final tabEmployees =
        employees.where((e) => e.tabId == currentTabId).toList();

    Set<int> getDescendants(int employeeId) {
      Set<int> descendants = {};
      for (var emp in tabEmployees) {
        if (emp.managerId == employeeId) {
          descendants.add(emp.id!);
          descendants.addAll(getDescendants(emp.id!));
        }
      }
      return descendants;
    }

    Set<int> visibleNodeIds = {};
    for (var emp in tabEmployees) {
      bool isVisible = true;
      int? currentId = emp.managerId;
      while (currentId != null) {
        if (!(_expandedNodes[currentId] ?? true)) {
          isVisible = false;
          break;
        }
        try {
          final currentEmp = employees.firstWhere((e) => e.id == currentId);
          currentId = currentEmp.managerId;
        } catch (e) {
          print('Error finding employee with ID $currentId: $e');
          isVisible = false;
          break;
        }
      }
      if (isVisible) {
        visibleNodeIds.add(emp.id!);
      }
    }

    for (var emp in tabEmployees) {
      if (visibleNodeIds.contains(emp.id)) {
        final node = Node.Id(emp.id!);
        nodeMap[emp.id!] = node;
        graph.addNode(node);
      }
    }

    for (var emp in tabEmployees) {
      if (emp.managerId != null &&
          visibleNodeIds.contains(emp.id) &&
          visibleNodeIds.contains(emp.managerId)) {
        graph.addEdge(nodeMap[emp.managerId]!, nodeMap[emp.id!]!);
      }
    }
  }

  void _toggleNode(int employeeId) {
    setState(() {
      _expandedNodes[employeeId] = !(_expandedNodes[employeeId] ?? true);
      _buildGraph();
    });
  }

  void _addNewTab() {
    final _formKey = GlobalKey<FormState>();
    String tabName = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('افزودن تب جدید'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            decoration: InputDecoration(labelText: 'نام تب'),
            validator: (value) => value!.isEmpty ? 'نام تب را وارد کنید' : null,
            onSaved: (value) => tabName = value!,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('کنسل'),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final newTab = TabModel(name: tabName);
                final insertedId =
                    await DatabaseHelper.instance.insertTab(newTab);
                newTab.id = insertedId;
                await _loadTabsAndEmployees();
                setState(() {
                  _tabController?.dispose();
                  _tabController =
                      TabController(length: tabs.length, vsync: this);
                  final newTabIndex =
                      tabs.indexWhere((tab) => tab.id == newTab.id);
                  _tabController!.index =
                      newTabIndex >= 0 ? newTabIndex : tabs.length - 1;
                  currentTabId = newTab.id!;
                  _buildGraph();
                });
                _tabController!.addListener(() {
                  if (!_tabController!.indexIsChanging) {
                    setState(() {
                      currentTabId = tabs[_tabController!.index].id!;
                      _buildGraph();
                    });
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تب جدید با موفقیت اضافه شد')),
                );
              }
            },
            child: Text('افزودن'),
          ),
        ],
      ),
    );
  }

  void _manageStaticFields() {
    final _formKey = GlobalKey<FormState>();
    String newFieldName = '';
    List<StaticField> localStaticFields = List.from(staticFields);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('مدیریت فیلدهای ثابت', textDirection: TextDirection.rtl),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Form(
                  key: _formKey,
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'نام فیلد جدید',
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    validator: (value) =>
                        value!.isEmpty ? 'نام فیلد را وارد کنید' : null,
                    onSaved: (value) => newFieldName = value!,
                  ),
                ),
                SizedBox(height: 10),
                ...localStaticFields.map((field) => ListTile(
                      title: Text(
                        '${field.displayName} (${field.isRequired ? "الزامی" : "اختیاری"})',
                        textDirection: TextDirection.rtl,
                      ),
                      trailing: field.isRequired
                          ? null
                          : IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await DatabaseHelper.instance
                                    .deleteStaticField(field.fieldName);
                                setState(() {
                                  localStaticFields.removeWhere(
                                      (f) => f.fieldName == field.fieldName);
                                });
                                await _loadStaticFields();
                                await _loadTabsAndEmployees();
                              },
                            ),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('کنسل', textDirection: TextDirection.rtl),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  if (!localStaticFields
                      .any((f) => f.fieldName == newFieldName)) {
                    await DatabaseHelper.instance.insertStaticField(StaticField(
                      fieldName: newFieldName,
                      isRequired: false,
                      displayName: newFieldName,
                      isVisible: true,
                    ));
                    setState(() {
                      localStaticFields.add(StaticField(
                        fieldName: newFieldName,
                        isRequired: false,
                        displayName: newFieldName,
                        isVisible: true,
                      ));
                    });
                    await _loadStaticFields();
                    await _loadTabsAndEmployees();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'فیلد ثابت جدید با موفقیت اضافه شد',
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: Text('افزودن', textDirection: TextDirection.rtl),
            ),
          ],
        ),
      ),
    );
  }

  void _exportDatabase() async {
    try {
      // Generate timestamp for the backup filename
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '').substring(0, 15);
      final backupFileName = 'org_chart_backup_$timestamp.sql';

      // Use folder picker to let user choose where to save the backup
      String? selectedFolder = await _pickFolder();

      // Fallback for Android or cancel case
      if (selectedFolder == null) {
        if (Platform.isAndroid) {
          selectedFolder = '/storage/emulated/0/org_chart_backups';
          await Directory(selectedFolder).create(recursive: true);
        } else {
          final defaultDir = await getApplicationSupportDirectory();
          selectedFolder = defaultDir.path;
        }
      }

      final filePathSql =
          path.join(selectedFolder, 'org_chart_backup_$timestamp.sql');
      final filePathJson =
          path.join(selectedFolder, 'org_chart_backup_$timestamp.json');

      // Export SQL
      await DatabaseHelper.instance.exportDatabase(filePathSql);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('دیتابیس با موفقیت به $filePathSql صادر شد')),
      );

      // Export JSON (optional)
      await DatabaseHelper.instance.exportDatabaseToJson(filePathJson);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('دیتابیس JSON با موفقیت به $filePathJson صادر شد')),
      );
    } catch (e) {
      print('Error exporting database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در صادر کردن دیتابیس: $e')),
      );
    }
  }

  void _importDatabase() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'SQL and JSON Files',
            extensions: ['sql', 'json'],
          ),
        ],
        confirmButtonText: 'انتخاب',
      );

      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هیچ فایلی انتخاب نشد')),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('وارد کردن دیتابیس'),
          content: Text(
              'این عمل دیتابیس فعلی را جایگزین می‌کند. آیا می‌خواهید فایل ${file.name} را وارد کنید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('خیر'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('بله', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          if (file.name.toLowerCase().endsWith('.json')) {
            await DatabaseHelper.instance.importDatabaseFromJson(file.path);
          } else {
            await DatabaseHelper.instance.importDatabase(file.path);
          }

          await _loadTabsAndEmployees();
          await _loadDynamicFieldNames();
          await _loadStaticFields();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('دیتابیس با موفقیت از ${file.name} وارد شد')),
          );
        } catch (e) {
          print(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در وارد کردن دیتابیس: $e')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در دسترسی به ذخیره‌سازی: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null || tabs.isEmpty) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs
              .map((tab) => Tab(
                    text: tab.name,
                    icon: tabs.length > 1
                        ? IconButton(
                            icon: Icon(Icons.close, size: 16),
                            onPressed: () => _deleteTab(tab.id!),
                          )
                        : null,
                  ))
              .toList(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (String value) {
              switch (value) {
                case 'add_tab':
                  _addNewTab();
                  break;
                case 'rename_tab':
                  _renameTab(context, tabs[_tabController!.index]);
                  break;
                case 'edit_title': // New option
                  _editAppBarTitle(context); // Call new method
                  break;
                case 'manage_fields':
                  _manageStaticFields();
                  break;
                case 'export_db':
                  _exportDatabase();
                  break;
                case 'import_db':
                  _importDatabase();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'add_tab',
                child: Row(
                  children: [
                    Icon(Icons.add, color: Colors.black),
                    SizedBox(width: 8),
                    Text('افزودن تب جدید'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'rename_tab',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.black),
                    SizedBox(width: 8),
                    Text('تغییر نام تب'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'edit_title', // New menu item
                child: Row(
                  children: [
                    Icon(Icons.title, color: Colors.black),
                    SizedBox(width: 8),
                    Text('تغییر عنوان برنامه'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'manage_fields',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.black),
                    SizedBox(width: 8),
                    Text('مدیریت فیلدهای ثابت'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'export_db',
                child: Row(
                  children: [
                    Icon(Icons.download_sharp, color: Colors.black),
                    SizedBox(width: 8),
                    Text('صادر کردن دیتابیس'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'import_db',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.black),
                    SizedBox(width: 8),
                    Text('وارد کردن دیتابیس'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: employees.where((e) => e.tabId == currentTabId).isEmpty
          ? Center(child: Text("دیتابیس خالی است"))
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: tabs.map((tab) {
                return InteractiveViewer(
                  constrained: false,
                  boundaryMargin: EdgeInsets.all(100),
                  minScale: 0.01,
                  maxScale: 5.0,
                  child: GraphView(
                    graph: graph,
                    algorithm: BuchheimWalkerAlgorithm(
                      config,
                      TreeEdgeRenderer(config),
                    ),
                    paint: Paint()
                      ..color = Colors.grey
                      ..strokeWidth = 2.0
                      ..style = PaintingStyle.stroke,
                    builder: (Node node) {
                      final emp =
                          employees.firstWhere((e) => e.id == node.key!.value);
                      return _buildNode(emp);
                    },
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEmployeeDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildNode(Employee emp) {
    bool hasSubordinates =
        employees.any((e) => e.managerId == emp.id && e.tabId == currentTabId);
    bool isExpanded = _expandedNodes[emp.id] ?? true;

    Color nodeColor = defaultColor;
    if (emp.staticFields.containsKey('color') &&
        emp.staticFields['color']?.isNotEmpty == true) {
      try {
        String hexColor = emp.staticFields['color']!.replaceFirst('0x', '');
        nodeColor = Color(int.parse(hexColor, radix: 16) | 0xFF000000);
      } catch (e) {
        print('Error parsing color for employee ${emp.id}: $e');
      }
    } else if (emp.managerId != null) {
      try {
        final parent = employees.firstWhere((e) => e.id == emp.managerId);
        if (parent.staticFields.containsKey('color') &&
            parent.staticFields['color']?.isNotEmpty == true) {
          String hexColor =
              parent.staticFields['color']!.replaceFirst('0x', '');
          nodeColor = Color(int.parse(hexColor, radix: 16) | 0xFF000000);
        }
      } catch (e) {
        print('Error parsing parent color for employee ${emp.id}: $e');
      }
    }

    List<Widget> nodeFields = [];
    if (emp.visibleFields.contains('profilePicture')) {
      if (emp.staticFields.containsKey('profilePicture') &&
          emp.staticFields['profilePicture']?.isNotEmpty == true &&
          File(emp.staticFields['profilePicture']!).existsSync()) {
        nodeFields.add(
          ClipOval(
            child: Image.file(
              File(emp.staticFields['profilePicture']!),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.person, size: 50),
            ),
          ),
        );
      } else {
        nodeFields.add(Icon(Icons.person, size: 50));
      }
    }
    for (var field in staticFields) {
      if (field.fieldName != 'color' &&
          field.fieldName != 'profilePicture' &&
          emp.visibleFields.contains(field.fieldName) &&
          emp.staticFields.containsKey(field.fieldName) &&
          emp.staticFields[field.fieldName]!.isNotEmpty) {
        nodeFields.add(Text(
          emp.staticFields[field.fieldName]!,
          style: TextStyle(fontSize: 12),
          textDirection: field.fieldName == 'phoneNumber' ||
                  field.fieldName == 'telegramId'
              ? TextDirection.ltr
              : TextDirection.rtl,
        ));
      }
    }
    for (var fieldName in dynamicFieldNames) {
      if (emp.visibleFields.contains(fieldName) &&
          emp.dynamicFields.containsKey(fieldName) &&
          emp.dynamicFields[fieldName]!.isNotEmpty) {
        nodeFields.add(Text(
          emp.dynamicFields[fieldName]!,
          style: TextStyle(fontSize: 12),
          textDirection: TextDirection.rtl, // Dynamic fields remain RTL
        ));
      }
    }

    return GestureDetector(
      onTap: () => _showEmployeeDetails(context, emp),
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: nodeColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: nodeColor == defaultColor ? Colors.blue : nodeColor),
        ),
        child: Column(
          children: [
            if (nodeFields.isNotEmpty)
              ...nodeFields
            else
              Text(
                emp.staticFields['name'] ?? 'بدون نام',
                style: TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
            if (hasSubordinates)
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                onPressed: () => _toggleNode(emp.id!),
              ),
          ],
        ),
      ),
    );
  }

  void _showEmployeeDetails(BuildContext context, Employee emp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(emp.staticFields['name'] ?? '',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: 'Vazir')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (emp.visibleFields.contains('profilePicture'))
                Center(
                  child: emp.staticFields.containsKey('profilePicture') &&
                          emp.staticFields['profilePicture']?.isNotEmpty ==
                              true &&
                          File(emp.staticFields['profilePicture']!).existsSync()
                      ? ClipOval(
                          child: Image.file(
                            File(emp.staticFields['profilePicture']!),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, size: 100),
                          ),
                        )
                      : Icon(Icons.person, size: 100),
                ),
              SizedBox(height: 10),
              ...staticFields
                  .where((field) =>
                      field.fieldName != 'color' &&
                      field.fieldName != 'profilePicture')
                  .map((field) {
                if (emp.staticFields.containsKey(field.fieldName) &&
                    emp.visibleFields.contains(field.fieldName)) {
                  final value = field.fieldName == 'managerId'
                      ? (employees
                              .firstWhere(
                                (e) => e.id == emp.managerId,
                                orElse: () => Employee(
                                  staticFields: {'name': 'مدیری نیست'},
                                  dynamicFields: {},
                                  visibleFields: [],
                                ),
                              )
                              .staticFields['name'] ??
                          '')
                      : (field.fieldName == 'joiningDate'
                          ? formatDateTime(emp.staticFields[field.fieldName])
                          : emp.staticFields[field.fieldName] ?? '');
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: TextStyle(fontFamily: 'Vazir'),
                        ),
                      ),
                      Text(
                        field.fieldName == 'joiningDate'
                            ? 'تاریخ ایجاد/عضویت: '
                            : '${field.displayName}: ',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: 'Vazir'),
                      ),
                    ],
                  );
                }
                return SizedBox.shrink();
              }),
              ...dynamicFieldNames
                  .where((fieldName) => emp.visibleFields.contains(fieldName))
                  .map((fieldName) {
                final value = emp.dynamicFields[fieldName] ?? '';
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: TextStyle(fontFamily: 'Vazir'),
                      ),
                    ),
                    Text(
                      '$fieldName: ',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: 'Vazir'),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('بستن',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: 'Vazir')),
          ),
          TextButton(
            onPressed: () => _showEditEmployeeDialog(context, emp),
            child: Text('ویرایش',
                style: TextStyle(color: Colors.blue, fontFamily: 'Vazir'),
                textDirection: TextDirection.rtl),
          ),
          TextButton(
            onPressed: () async {
              await _deleteEmployee(emp);
              Navigator.pop(context);
            },
            child: Text('حذف',
                style: TextStyle(color: Colors.red, fontFamily: 'Vazir'),
                textDirection: TextDirection.rtl),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickImage() async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg'],
        ),
      ],
      confirmButtonText: 'انتخاب',
    );
    if (file != null) {
      final appDir = await getApplicationSupportDirectory();
      final pictureDir =
          Directory(path.join(appDir.path, 'org_chart_pictures'));
      await pictureDir.create(recursive: true);
      final fileExtension = path.extension(file.path);
      final newFileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final newPath = path.join(pictureDir.path, newFileName);
      await File(file.path).copy(newPath);
      return newPath;
    }
    return null;
  }

  Future<String?> _pickFolder() async {
    final String? folderPath = await getDirectoryPath(
      confirmButtonText: 'انتخاب پوشه',
    );

    if (folderPath != null) {
      return folderPath;
    }

    return null;
  }

  void _showEditEmployeeDialog(BuildContext context, Employee emp) {
    final _formKey = GlobalKey<FormState>();
    Map<String, TextEditingController> staticFieldControllers = staticFields
        .asMap()
        .map((_, field) => MapEntry(
            field.fieldName,
            TextEditingController(
                text: emp.staticFields[field.fieldName] ?? '')));
    DateTime joiningDate = emp.staticFields.containsKey('joiningDate')
        ? DateTime.parse(emp.staticFields['joiningDate']!)
        : DateTime.now();
    int? managerId = emp.managerId;
    Color? selectedColor;
    if (emp.staticFields.containsKey('color') &&
        emp.staticFields['color']?.isNotEmpty == true) {
      try {
        String hexColor = emp.staticFields['color']!.startsWith('0x')
            ? emp.staticFields['color']!.substring(2)
            : emp.staticFields['color']!;
        if (RegExp(r'^[0-9a-fA-F]{6,8}$').hasMatch(hexColor)) {
          selectedColor = Color(int.parse(hexColor, radix: 16) | 0xFF000000);
        } else {
          selectedColor = defaultColor;
        }
      } catch (e) {
        print('Error parsing color for employee ${emp.id}: $e');
        selectedColor = defaultColor;
      }
    } else {
      selectedColor = defaultColor;
    }
    Map<String, String> dynamicFields = Map.from(emp.dynamicFields);
    Map<String, TextEditingController> dynamicFieldControllers =
        dynamicFieldNames.asMap().map((_, key) => MapEntry(
            key, TextEditingController(text: dynamicFields[key] ?? '')));
    List<String> visibleFields = List.from(emp.visibleFields);
    String? profilePicturePath = emp.staticFields['profilePicture'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('ویرایش کارمند'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profilePicturePath?.isNotEmpty == true &&
                      File(profilePicturePath!).existsSync())
                    Column(
                      children: [
                        ClipOval(
                          child: Image.file(
                            File(profilePicturePath!),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, size: 100),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final newPath = await _pickImage();
                            if (newPath != null) {
                              setState(() {
                                profilePicturePath = newPath;
                                staticFieldControllers['profilePicture']!.text =
                                    newPath;
                              });
                            }
                          },
                          child: Text('تغییر عکس پروفایل',
                              textDirection: TextDirection.rtl),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Icon(Icons.person, size: 100),
                        TextButton(
                          onPressed: () async {
                            final newPath = await _pickImage();
                            if (newPath != null) {
                              setState(() {
                                profilePicturePath = newPath;
                                staticFieldControllers['profilePicture']!.text =
                                    newPath;
                              });
                            }
                          },
                          child: Text('انتخاب عکس پروفایل',
                              textDirection: TextDirection.rtl),
                        ),
                      ],
                    ),
                  SizedBox(height: 10),
                  ...staticFields
                      .where((field) => field.fieldName != 'profilePicture')
                      .map((field) {
                    if (field.fieldName == 'joiningDate') {
                      return TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: joiningDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              joiningDate = pickedDate;
                              staticFieldControllers['joiningDate']!.text =
                                  joiningDate.toIso8601String();
                            });
                          }
                        },
                        child: Text(
                            '${field.displayName}: ${joiningDate.toString().split(' ')[0]}',
                            textDirection: TextDirection.rtl),
                      );
                    } else if (field.fieldName == 'managerId') {
                      return DropdownButtonFormField<int>(
                        decoration:
                            InputDecoration(labelText: field.displayName),
                        value: managerId,
                        items: [
                          DropdownMenuItem(
                              value: null, child: Text('مدیری نیست')),
                          ...employees
                              .where((e) =>
                                  e.id != emp.id && e.tabId == currentTabId)
                              .map((e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(e.staticFields['name'] ?? ''),
                                  )),
                        ],
                        onChanged: (value) => managerId = value,
                      );
                    } // Inside _showEditEmployeeDialog, update the color picker section
                    else if (field.fieldName == 'color') {
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Text('${field.displayName}: '),
                              SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('انتخاب رنگ'),
                                      content: SingleChildScrollView(
                                        child: BlockPicker(
                                          pickerColor:
                                              selectedColor ?? defaultColor,
                                          onColorChanged: (color) {
                                            selectedColor = color;
                                            staticFieldControllers['color']!
                                                    .text =
                                                '0x${color.value.toRadixString(16).padLeft(8, '0')}';
                                          },
                                          availableColors:
                                              availableColors, // Add the custom color list
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text('تأیید'),
                                        ),
                                      ],
                                    ),
                                  ).then((_) => setState(() {}));
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: selectedColor ?? defaultColor,
                                    border: Border.all(color: Colors.black),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: TextFormField(
                          controller: staticFieldControllers[field.fieldName],
                          decoration:
                              InputDecoration(labelText: field.displayName),
                          validator: (field.fieldName == 'name')
                              ? (value) => value!.isEmpty
                                  ? '${field.displayName} را وارد کنید'
                                  : null
                              : null,
                        ),
                      );
                    }
                  }),
                  SizedBox(height: 10),
                  Text('فیلدهای قابل نمایش در جزئیات:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl),
                  ...staticFields.map((field) => CheckboxListTile(
                        title: Text(field.displayName,
                            textDirection: TextDirection.rtl),
                        value: visibleFields.contains(field.fieldName),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              visibleFields.add(field.fieldName);
                            } else {
                              visibleFields.remove(field.fieldName);
                            }
                          });
                        },
                      )),
                  ...dynamicFieldNames.map((fieldName) => CheckboxListTile(
                        title:
                            Text(fieldName, textDirection: TextDirection.rtl),
                        value: visibleFields.contains(fieldName),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              visibleFields.add(fieldName);
                            } else {
                              visibleFields.remove(fieldName);
                            }
                          });
                        },
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('کنسل'),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  Map<String, String> updatedStaticFields = {};
                  staticFieldControllers.forEach((key, controller) {
                    if (controller.text.isNotEmpty ||
                        key == 'joiningDate' ||
                        key == 'color') {
                      updatedStaticFields[key] = controller.text;
                    }
                  });
                  updatedStaticFields['joiningDate'] =
                      joiningDate.toIso8601String();
                  if (!updatedStaticFields.containsKey('color') ||
                      updatedStaticFields['color']!.isEmpty) {
                    updatedStaticFields['color'] =
                        '0x${defaultColor.value.toRadixString(16).padLeft(8, '0')}';
                  }
                  if (profilePicturePath != null &&
                      File(profilePicturePath!).existsSync()) {
                    updatedStaticFields['profilePicture'] = profilePicturePath!;
                  } else {
                    updatedStaticFields.remove('profilePicture');
                  }
                  dynamicFields = {};
                  dynamicFieldControllers.forEach((key, controller) {
                    if (controller.text.isNotEmpty) {
                      dynamicFields[key] = controller.text;
                    }
                  });
                  final updatedEmployee = Employee(
                    id: emp.id,
                    staticFields: updatedStaticFields,
                    dynamicFields: dynamicFields,
                    managerId: managerId,
                    tabId: currentTabId,
                    visibleFields: visibleFields,
                  );
                  await DatabaseHelper.instance.updateEmployee(updatedEmployee);
                  await _loadTabsAndEmployees();
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              child: Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEmployee(Employee emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف کارمند'),
        content: Text(
            'آیا مطمئن هستید که می‌خواهید کارمند ${emp.staticFields['name'] ?? 'بدون نام'} را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('خیر'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('بله', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = await DatabaseHelper.instance.database;
        final rowsDeleted = await db.delete(
          'employees',
          where: 'id = ?',
          whereArgs: [emp.id],
        );

        final rowsUpdated = await db.update(
          'employees',
          {'managerId': null},
          where: 'managerId = ?',
          whereArgs: [emp.id],
        );

        // Delete profile picture file if it exists
        if (emp.staticFields.containsKey('profilePicture') &&
            emp.staticFields['profilePicture']?.isNotEmpty == true) {
          final imagePath = emp.staticFields['profilePicture']!;
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        }

        await _loadTabsAndEmployees();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کارمند با موفقیت حذف شد')),
        );
      } catch (e) {
        print('Error deleting employee: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('به این علت نتوانستیم کارمند را حذف کنیم: $e')),
        );
      }
    }
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    Map<String, TextEditingController> staticFieldControllers = staticFields
        .asMap()
        .map((_, field) => MapEntry(field.fieldName, TextEditingController()));
    DateTime joiningDate = DateTime.now();
    int? managerId;
    Color selectedColor = defaultColor;
    Map<String, String> dynamicFields = {};
    Map<String, TextEditingController> dynamicFieldControllers =
        dynamicFieldNames
            .asMap()
            .map((_, key) => MapEntry(key, TextEditingController()));
    List<String> visibleFields = staticFields
        .where((field) => field.isVisible)
        .map((field) => field.fieldName)
        .toList()
      ..addAll(dynamicFieldNames);
    String? profilePicturePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title:
              Text('اضافه کردن کارمند جدید', textDirection: TextDirection.rtl),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profilePicturePath?.isNotEmpty == true &&
                      File(profilePicturePath!).existsSync())
                    Column(
                      children: [
                        ClipOval(
                          child: Image.file(
                            File(profilePicturePath!),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, size: 100),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final newPath = await _pickImage();
                            if (newPath != null) {
                              setState(() {
                                profilePicturePath = newPath;
                                staticFieldControllers['profilePicture']!.text =
                                    newPath;
                              });
                            }
                          },
                          child: Text('تغییر عکس پروفایل',
                              textDirection: TextDirection.rtl),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Icon(Icons.person, size: 100),
                        TextButton(
                          onPressed: () async {
                            final newPath = await _pickImage();
                            if (newPath != null) {
                              setState(() {
                                profilePicturePath = newPath;
                                staticFieldControllers['profilePicture']!.text =
                                    newPath;
                              });
                            }
                          },
                          child: Text('انتخاب عکس پروفایل',
                              textDirection: TextDirection.rtl),
                        ),
                      ],
                    ),
                  SizedBox(height: 10),
                  ...staticFields
                      .where((field) => field.fieldName != 'profilePicture')
                      .map((field) {
                    if (field.fieldName == 'joiningDate') {
                      return TextButton(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: joiningDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(joiningDate),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                joiningDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                                staticFieldControllers['joiningDate']!.text =
                                    joiningDate.toIso8601String();
                              });
                            }
                          }
                        },
                        child: Text(
                            '${field.displayName}: ${joiningDate.toString().split(' ')[0]}',
                            textDirection: TextDirection.rtl),
                      );
                    } else if (field.fieldName == 'managerId') {
                      return DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                            labelText: field.displayName,
                            labelStyle: TextStyle(fontFamily: 'Vazir')),
                        value: managerId,
                        items: [
                          DropdownMenuItem(
                              value: null, child: Text('مدیری نیست')),
                          ...employees
                              .where((e) => e.tabId == currentTabId)
                              .map((e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(e.staticFields['name'] ?? '',
                                        textDirection: TextDirection.rtl),
                                  )),
                        ],
                        onChanged: (value) => managerId = value,
                      );
                    } // Inside _showAddEmployeeDialog, update the color picker section
                    else if (field.fieldName == 'color') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${field.displayName}: ',
                                textDirection: TextDirection.rtl),
                            SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('انتخاب رنگ',
                                        textDirection: TextDirection.rtl),
                                    content: SingleChildScrollView(
                                      child: BlockPicker(
                                        pickerColor: selectedColor,
                                        onColorChanged: (color) {
                                          selectedColor = color;
                                          staticFieldControllers['color']!
                                                  .text =
                                              '0x${color.value.toRadixString(16).padLeft(8, '0')}';
                                        },
                                        availableColors:
                                            availableColors, // Add the custom color list
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('تأیید',
                                            textDirection: TextDirection.rtl),
                                      ),
                                    ],
                                  ),
                                ).then((_) => setState(() {}));
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: selectedColor,
                                  border: Border.all(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      String? hintText;
                      switch (field.fieldName) {
                        case 'name':
                          hintText = 'مثال: احمد محمدی';
                          break;
                        case 'title':
                          hintText = 'مثال: مدیر پروژه';
                          break;
                        case 'email':
                          hintText = 'مثال: ahmad@example.com';
                          break;
                        case 'phoneNumber':
                          hintText = 'مثال: +989123456789';
                          break;
                        case 'telegramId':
                          hintText = 'مثال: @AhmadMohammadi';
                          break;
                      }
                      return Directionality(
                        textDirection: TextDirection.rtl,
                        child: TextFormField(
                          controller: staticFieldControllers[field.fieldName],
                          decoration: InputDecoration(
                            labelText: field.displayName,
                            hintText: hintText,
                          ),
                          validator: (field.fieldName == 'name')
                              ? (value) => value!.isEmpty
                                  ? '${field.displayName} را وارد کنید'
                                  : null
                              : null,
                        ),
                      );
                    }
                  }),
                  SizedBox(height: 10),
                  Text('فیلدهای اضافی:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl),
                  ...dynamicFieldNames.map((fieldName) => TextFormField(
                        controller: dynamicFieldControllers[fieldName],
                        decoration: InputDecoration(
                            labelText: fieldName,
                            labelStyle: TextStyle(fontFamily: 'Vazir')),
                        textDirection: TextDirection.rtl,
                      )),
                  SizedBox(height: 10),
                  Text('فیلدهای قابل نمایش در جزئیات:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl),
                  ...staticFields.map((field) => CheckboxListTile(
                        title: Text(field.displayName,
                            textDirection: TextDirection.rtl),
                        value: visibleFields.contains(field.fieldName),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              visibleFields.add(field.fieldName);
                            } else {
                              visibleFields.remove(field.fieldName);
                            }
                          });
                        },
                      )),
                  ...dynamicFieldNames.map((fieldName) => CheckboxListTile(
                        title:
                            Text(fieldName, textDirection: TextDirection.rtl),
                        value: visibleFields.contains(fieldName),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              visibleFields.add(fieldName);
                            } else {
                              visibleFields.remove(fieldName);
                            }
                          });
                        },
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('کنسل', textDirection: TextDirection.rtl),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  Map<String, String> staticFields = {};
                  staticFieldControllers.forEach((key, controller) {
                    if (controller.text.isNotEmpty ||
                        key == 'joiningDate' ||
                        key == 'color') {
                      staticFields[key] = controller.text;
                    }
                  });
                  staticFields['joiningDate'] = joiningDate.toIso8601String();
                  if (!staticFields.containsKey('color') ||
                      staticFields['color']!.isEmpty) {
                    staticFields['color'] =
                        '0x${defaultColor.value.toRadixString(16).padLeft(8, '0')}';
                  }
                  if (profilePicturePath != null &&
                      File(profilePicturePath!).existsSync()) {
                    staticFields['profilePicture'] = profilePicturePath!;
                  } else {
                    staticFields.remove('profilePicture');
                  }
                  dynamicFields = {};
                  dynamicFieldControllers.forEach((key, controller) {
                    if (controller.text.isNotEmpty) {
                      dynamicFields[key] = controller.text;
                    }
                  });
                  final newEmployee = Employee(
                    staticFields: staticFields,
                    dynamicFields: dynamicFields,
                    managerId: managerId,
                    tabId: currentTabId,
                    visibleFields: visibleFields,
                  );
                  await DatabaseHelper.instance.insertEmployee(newEmployee);
                  await _loadTabsAndEmployees();
                  Navigator.pop(context);
                }
              },
              child: Text('ذخیره', textDirection: TextDirection.rtl),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}
