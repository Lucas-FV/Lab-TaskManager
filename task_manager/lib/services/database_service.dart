import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/category.dart'; // <-- 1. IMPORTE O NOVO MODELO

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // <-- Versão 3 (para dueDate e categoryId)
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 3. CRIA A TABELA DE CATEGORIAS
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');

    // 4. CRIA A TABELA DE TAREFAS
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT, 
        categoryId TEXT 
      )
    ''');

    // 5. INSERE CATEGORIAS PADRÃO
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migração para v2 (adiciona dueDate)
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN dueDate TEXT');
    }
    // 6. MIGRAÇÃO PARA v3 (adiciona categorias e categoryId)
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color INTEGER NOT NULL
        )
      ''');
      await db.execute('ALTER TABLE tasks ADD COLUMN categoryId TEXT');
      await _insertDefaultCategories(db);
    }
  }

  // 7. MÉTODO PARA INSERIR CATEGORIAS PADRÃO
  Future<void> _insertDefaultCategories(Database db) async {
    await db.insert('categories', Category(name: 'Trabalho', color: 0xFF42A5F5).toMap()); // Azul
    await db.insert('categories', Category(name: 'Estudos', color: 0xFFFFCA28).toMap()); // Amarelo
    await db.insert('categories', Category(name: 'Pessoal', color: 0xFF66BB6A).toMap()); // Verde
    await db.insert('categories', Category(name: 'Casa', color: 0xFFEF5350).toMap()); // Vermelho
  }

  // 8. NOVO MÉTODO PARA LER CATEGORIAS
  Future<List<Category>> readAllCategories() async {
    final db = await database;
    final result = await db.query('categories', orderBy: 'name ASC');
    return result.map((map) => Category.fromMap(map)).toList();
  }

  // (create, read, readAll, update, delete de Task)
  Future<Task> create(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
    return task;
  }

  Future<Task?> read(String id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await database;
    const orderBy = 'dueDate IS NULL, dueDate ASC, createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> update(Task task) async {
    final db = await database;
    return db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}