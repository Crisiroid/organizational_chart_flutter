import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'models/employee.dart';
import 'models/tab.dart';
import 'dart:convert';
import 'dart:io';

class StaticField {
  final String fieldName;
  final bool isRequired;
  final String displayName;
  final bool isVisible;

  StaticField({
    required this.fieldName,
    required this.isRequired,
    required this.displayName,
    required this.isVisible,
  });

  Map<String, dynamic> toMap() {
    return {
      'field_name': fieldName,
      'is_required': isRequired ? 1 : 0,
      'display_name': displayName,
      'is_visible': isVisible ? 1 : 0,
    };
  }

  factory StaticField.fromMap(Map<String, dynamic> map) {
    return StaticField(
      fieldName: map['field_name'],
      isRequired: map['is_required'] == 1,
      displayName: map['display_name'] ?? map['field_name'],
      isVisible: map['is_visible'] == 1,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('org_chart.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('isFirstRun') ?? true;

    if (isFirstRun) {
      await deleteDatabase(path);
      await prefs.setBool('isFirstRun', false);
    }

    return await openDatabase(path,
        version: 9, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tabs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        title TEXT NOT NULL,
        email TEXT NOT NULL,
        phoneNumber TEXT NOT NULL,
        telegramId TEXT NOT NULL,
        joiningDate TEXT NOT NULL,
        managerId INTEGER,
        color TEXT,
        tabId INTEGER NOT NULL,
        dynamicFields TEXT,
        visibleFields TEXT,
        FOREIGN KEY (managerId) REFERENCES employees (id),
        FOREIGN KEY (tabId) REFERENCES tabs (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE dynamic_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE static_fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        field_name TEXT NOT NULL UNIQUE,
        is_required INTEGER NOT NULL,
        display_name TEXT NOT NULL,
        is_visible INTEGER NOT NULL
      )
    ''');

    await db.insert('static_fields', {
      'field_name': 'name',
      'is_required': 1,
      'display_name': 'نام و نام خانوادگی',
      'is_visible': 1
    });
    await db.insert('static_fields', {
      'field_name': 'title',
      'is_required': 1,
      'display_name': 'عنوان شغلی',
      'is_visible': 1
    });
    await db.insert('static_fields', {
      'field_name': 'email',
      'is_required': 1,
      'display_name': 'ایمیل',
      'is_visible': 1
    });
    await db.insert('static_fields', {
      'field_name': 'phoneNumber',
      'is_required': 1,
      'display_name': 'شماره تلفن',
      'is_visible': 1
    });
    await db.insert('static_fields', {
      'field_name': 'telegramId',
      'is_required': 1,
      'display_name': 'شناسه تلگرام',
      'is_visible': 1
    });
    await db.insert('static_fields', {
      'field_name': 'joiningDate',
      'is_required': 1,
      'display_name': 'تاریخ عضویت',
      'is_visible': 1
    });
    await db.insert('static_fields', {
      'field_name': 'managerId',
      'is_required': 0,
      'display_name': 'مدیر',
      'is_visible': 1
    });
    await db.insert('static_fields', {
      'field_name': 'color',
      'is_required': 0,
      'display_name': 'رنگ',
      'is_visible': 1
    });
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE employees ADD COLUMN color TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE tabs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      await db.execute(
          'ALTER TABLE employees ADD COLUMN tabId INTEGER NOT NULL DEFAULT 1');
      await db.insert('tabs', {'id': 1, 'name': 'Tab 1'});
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE employees ADD COLUMN dynamicFields TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE dynamic_fields (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          field_name TEXT NOT NULL UNIQUE
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE static_fields (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          field_name TEXT NOT NULL UNIQUE,
          is_required INTEGER NOT NULL
        )
      ''');
      await db.insert('static_fields', {
        'field_name': 'name',
        'is_required': 1,
      });
      await db.insert('static_fields', {
        'field_name': 'title',
        'is_required': 1,
      });
      await db.insert('static_fields', {
        'field_name': 'email',
        'is_required': 1,
      });
      await db.insert('static_fields', {
        'field_name': 'phoneNumber',
        'is_required': 1,
      });
      await db.insert('static_fields', {
        'field_name': 'telegramId',
        'is_required': 1,
      });
      await db.insert('static_fields', {
        'field_name': 'joiningDate',
        'is_required': 1,
      });
      await db.insert('static_fields', {
        'field_name': 'managerId',
        'is_required': 0,
      });
      await db.insert('static_fields', {
        'field_name': 'color',
        'is_required': 0,
      });
    }
    if (oldVersion < 7) {
      await db.execute(
          'ALTER TABLE static_fields ADD COLUMN display_name TEXT NOT NULL DEFAULT ""');
      await db.update('static_fields', {'display_name': 'نام و نام خانوادگی'},
          where: 'field_name = ?', whereArgs: ['name']);
      await db.update('static_fields', {'display_name': 'عنوان شغلی'},
          where: 'field_name = ?', whereArgs: ['title']);
      await db.update('static_fields', {'display_name': 'ایمیل'},
          where: 'field_name = ?', whereArgs: ['email']);
      await db.update('static_fields', {'display_name': 'شماره تلفن'},
          where: 'field_name = ?', whereArgs: ['phoneNumber']);
      await db.update('static_fields', {'display_name': 'شناسه تلگرام'},
          where: 'field_name = ?', whereArgs: ['telegramId']);
      await db.update('static_fields', {'display_name': 'تاریخ عضویت'},
          where: 'field_name = ?', whereArgs: ['joiningDate']);
      await db.update('static_fields', {'display_name': 'مدیر'},
          where: 'field_name = ?', whereArgs: ['managerId']);
      await db.update('static_fields', {'display_name': 'رنگ'},
          where: 'field_name = ?', whereArgs: ['color']);
    }
    if (oldVersion < 8) {
      await db.execute(
          'ALTER TABLE static_fields ADD COLUMN is_visible INTEGER NOT NULL DEFAULT 1');
      await db.update('static_fields', {'is_visible': 1});
    }
    if (oldVersion < 9) {
      await db.execute(
          'ALTER TABLE employees ADD COLUMN visibleFields TEXT');
      await db.update('employees', {
        'visibleFields': jsonEncode([
          'name',
          'title',
          'email',
          'phoneNumber',
          'telegramId',
          'joiningDate',
          'managerId',
          'color'
        ])
      });
    }
  }

  Future<int> insertTab(TabModel tab) async {
    final db = await database;
    return await db.insert('tabs', tab.toMap());
  }

  Future<List<TabModel>> getTabs() async {
    final db = await database;
    final result = await db.query('tabs');
    return result.map((map) => TabModel.fromMap(map)).toList();
  }

  Future<void> deleteTab(int tabId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'employees',
        where: 'tabId = ?',
        whereArgs: [tabId],
      );
      await txn.delete(
        'tabs',
        where: 'id = ?',
        whereArgs: [tabId],
      );
    });
  }

  Future<int> insertEmployee(Employee employee) async {
    final db = await database;
    return await db.insert('employees', employee.toMap());
  }

  Future<void> updateEmployee(Employee employee) async {
    final db = await database;
    await db.update(
      'employees',
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<List<Employee>> getEmployees() async {
    final db = await database;
    final result = await db.query('employees');
    final staticFields = await getStaticFields();
    final activeFields = staticFields.map((f) => f.fieldName).toList();
    return result.map((map) {
      Map<String, String> staticFieldsMap = {};
      for (var field in activeFields) {
        if (map.containsKey(field) && map[field] != null) {
          staticFieldsMap[field] = map[field].toString();
        }
      }
      return Employee.fromMap({
        'id': map['id'],
        'staticFields': staticFieldsMap,
        'dynamicFields': map['dynamicFields'] ?? '{}',
        'managerId': map['managerId'],
        'tabId': map['tabId'],
        'visibleFields': map['visibleFields'] ?? '[]',
      });
    }).toList();
  }

  Future<int> insertDynamicFieldName(String fieldName) async {
    final db = await database;
    return await db.insert('dynamic_fields', {'field_name': fieldName});
  }

  Future<List<String>> getDynamicFieldNames() async {
    final db = await database;
    final result = await db.query('dynamic_fields');
    return result.map((map) => map['field_name'] as String).toList();
  }

  Future<void> deleteDynamicFieldName(String fieldName) async {
    final db = await database;
    await db.delete(
      'dynamic_fields',
      where: 'field_name = ?',
      whereArgs: [fieldName],
    );
    final employees = await getEmployees();
    for (var employee in employees) {
      if (employee.dynamicFields.containsKey(fieldName)) {
        employee.dynamicFields.remove(fieldName);
        employee.visibleFields.remove(fieldName);
        await updateEmployee(employee);
      }
    }
  }

  Future<int> insertStaticField(StaticField field) async {
    final db = await database;
    await db.execute('ALTER TABLE employees ADD COLUMN ${field.fieldName} TEXT');
    return await db.insert('static_fields', field.toMap());
  }

  Future<List<StaticField>> getStaticFields() async {
    final db = await database;
    final result = await db.query('static_fields');
    return result.map((map) => StaticField.fromMap(map)).toList();
  }

  Future<void> deleteStaticField(String fieldName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'static_fields',
        where: 'field_name = ?',
        whereArgs: [fieldName],
      );
      await txn.execute('UPDATE employees SET $fieldName = NULL');
      await txn.execute(
          'UPDATE employees SET visibleFields = REPLACE(visibleFields, ?, "")',
          [fieldName]);
    });
  }

  Future<void> updateStaticFieldVisibility(String fieldName, bool isVisible) async {
    final db = await database;
    await db.update(
      'static_fields',
      {'is_visible': isVisible ? 1 : 0},
      where: 'field_name = ?',
      whereArgs: [fieldName],
    );
  }

  Future<String> exportDatabase() async {
    final db = await database;
    const backupDirPath = '/storage/emulated/0/org_chart_backups';
    await Directory(backupDirPath).create(recursive: true);

    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '').substring(0, 15);
    final filePath = join(backupDirPath, 'org_chart_backup_$timestamp.sql');
    final file = File(filePath);
    final sink = file.openWrite();

    try {
      final tables = ['tabs', 'employees', 'dynamic_fields', 'static_fields'];

      for (var table in tables) {
        final schemaResult = await db.rawQuery(
            'SELECT sql FROM sqlite_master WHERE type="table" AND name=?',
            [table]);
        if (schemaResult.isNotEmpty) {
          final createTableSql = schemaResult.first['sql'] as String;
          sink.writeln('$createTableSql;');
          sink.writeln();
        }

        final data = await db.query(table);
        if (data.isNotEmpty) {
          final columns = data.first.keys.toList();
          for (var row in data) {
            final values = columns.map((col) {
              final value = row[col];
              if (value == null) {
                return 'NULL';
              } else if (value is String) {
                return "'${value.replaceAll("'", "''")}'";
              } else {
                return value.toString();
              }
            }).join(', ');
            sink.writeln(
                'INSERT INTO $table (${columns.join(', ')}) VALUES ($values);');
          }
          sink.writeln();
        }
      }

      await sink.flush();
      return filePath;
    } finally {
      await sink.close();
    }
  }

  Future<void> importDatabase(String filePath) async {
    final db = await database;
    final importFile = File(filePath);

    if (!await importFile.exists()) {
      throw Exception('فایل $filePath یافت نشد.');
    }

    final sqlContent = await importFile.readAsString();
    final sqlStatements = sqlContent
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    await db.transaction((txn) async {
      final tables = ['tabs', 'employees', 'dynamic_fields', 'static_fields'];
      for (var table in tables) {
        await txn.execute('DROP TABLE IF EXISTS $table');
      }

      for (var statement in sqlStatements) {
        try {
          await txn.execute(statement);
        } catch (e) {
          print('Error executing statement: $statement - $e');
        }
      }
    });
  }

  Future<String> exportDatabaseToJson() async {
    final db = await database;
    const backupDirPath = '/storage/emulated/0/org_chart_backups';
    await Directory(backupDirPath).create(recursive: true);

    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '').substring(0, 15);
    final filePath = join(backupDirPath, 'org_chart_backup_$timestamp.json');
    final file = File(filePath);

    try {
      final Map<String, dynamic> exportData = {};

      final tabs = await db.query('tabs');
      exportData['tabs'] = tabs;

      final employees = await db.query('employees');
      exportData['employees'] = employees;

      final dynamicFields = await db.query('dynamic_fields');
      exportData['dynamic_fields'] = dynamicFields;

      final staticFields = await db.query('static_fields');
      exportData['static_fields'] = staticFields;

      await file.writeAsString(jsonEncode(exportData));
      return filePath;
    } catch (e) {
      throw Exception('Failed to export database to JSON: $e');
    }
  }

  Future<void> importDatabaseFromJson(String filePath) async {
    final db = await database;
    final importFile = File(filePath);

    if (!await importFile.exists()) {
      throw Exception('File $filePath not found.');
    }

    try {
      final jsonContent = await importFile.readAsString();
      final importData = jsonDecode(jsonContent) as Map<String, dynamic>;

      await db.transaction((txn) async {
        await txn.execute('DROP TABLE IF EXISTS employees');
        await txn.execute('DROP TABLE IF EXISTS tabs');
        await txn.execute('DROP TABLE IF EXISTS dynamic_fields');
        await txn.execute('DROP TABLE IF EXISTS static_fields');

        await txn.execute('''
          CREATE TABLE tabs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        await txn.execute('''
          CREATE TABLE employees (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            title TEXT NOT NULL,
            email TEXT NOT NULL,
            phoneNumber TEXT NOT NULL,
            telegramId TEXT NOT NULL,
            joiningDate TEXT NOT NULL,
            managerId INTEGER,
            color TEXT,
            tabId INTEGER NOT NULL,
            dynamicFields TEXT,
            visibleFields TEXT,
            FOREIGN KEY (managerId) REFERENCES employees (id),
            FOREIGN KEY (tabId) REFERENCES tabs (id)
          )
        ''');

        await txn.execute('''
          CREATE TABLE dynamic_fields (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            field_name TEXT NOT NULL UNIQUE
          )
        ''');

        await txn.execute('''
          CREATE TABLE static_fields (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            field_name TEXT NOT NULL UNIQUE,
            is_required INTEGER NOT NULL,
            display_name TEXT NOT NULL,
            is_visible INTEGER NOT NULL
          )
        ''');

        if (importData['tabs'] != null) {
          for (var tab in (importData['tabs'] as List)) {
            await txn.insert('tabs', (tab as Map).cast<String, dynamic>());
          }
        }

        if (importData['employees'] != null) {
          for (var employee in (importData['employees'] as List)) {
            await txn.insert('employees', (employee as Map).cast<String, dynamic>());
          }
        }

        if (importData['dynamic_fields'] != null) {
          for (var field in (importData['dynamic_fields'] as List)) {
            await txn.insert('dynamic_fields', (field as Map).cast<String, dynamic>());
          }
        }

        if (importData['static_fields'] != null) {
          for (var field in (importData['static_fields'] as List)) {
            await txn.insert('static_fields', (field as Map).cast<String, dynamic>());
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to import database from JSON: $e');
    }
  }
}