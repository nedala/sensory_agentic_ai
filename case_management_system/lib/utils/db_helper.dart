import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/case_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'case_management.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS cases(
      id TEXT PRIMARY KEY,
      title TEXT,
      createdAt TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS case_objects(
      id TEXT PRIMARY KEY,
      title TEXT,
      path TEXT,
      content TEXT,
      createdAt TEXT,
      type TEXT,
      isBinaryFile INTEGER,
      caseId TEXT,
      FOREIGN KEY (caseId) REFERENCES cases(id) ON DELETE CASCADE
    )
  ''');
  }

  Future<List<Case>> getCases() async {
    final db = await database;
    final casesData = await db.query('cases');
    final List<Case> cases = [];

    for (final caseData in casesData) {
      final caseObjectsData = await db.query(
        'case_objects',
        where: 'caseId = ?',
        whereArgs: [caseData['id']],
      );
      final caseObjects =
          caseObjectsData.map((e) => CaseObject.fromMap(e)).toList();
      cases.add(Case.fromMap(caseData, caseObjects));
    }
    return cases;
  }

  Future<void> insertCase(Case caseEntity) async {
    if (_database == null) {
      await _initDatabase();
    }
    final db = await database;
    await db.insert('cases', caseEntity.toMap());

    // Insert associated case objects
    for (final object in caseEntity.caseObjects) {
      await db.insert('case_objects', object.toMap());
    }
  }

  Future<void> updateCase(Case updatedCase) async {
    final db = await database;
    await db.update('cases', updatedCase.toMap(),
        where: 'id = ?', whereArgs: [updatedCase.id]);

    // Update associated case objects
    for (final object in updatedCase.caseObjects) {
      await db.update('case_objects', object.toMap(),
          where: 'id = ?', whereArgs: [object.id]);
    }
  }

  Future<void> deleteCase(String id) async {
    final db = await database;
    await db.delete('case_objects', where: 'caseId = ?', whereArgs: [id]);
    await db.delete('cases', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertCaseObject(CaseObject caseObject) async {
    final db = await database;
    await db.insert('case_objects', caseObject.toMap());
  }

  Future<void> updateCaseObject(CaseObject caseObject) async {
    final db = await database;
    await db.update(
      'case_objects',
      caseObject.toMap(),
      where: 'id = ?',
      whereArgs: [caseObject.id],
    );
  }

  Future<List<CaseObject>> getCaseObjectsByCaseId(String caseId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'case_objects',
      where: 'caseId = ?',
      whereArgs: [caseId],
    );

    return List.generate(maps.length, (i) {
      return CaseObject.fromMap(maps[i]);
    });
  }

  Future<void> deleteCaseObject(String id) async {
    final db = await database;
    await db.delete('case_objects', where: 'id = ?', whereArgs: [id]);
  }
}
