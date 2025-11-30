import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';

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
      // MUDANÇA 1: Incrementamos a versão para 6 para aplicar a nova migração
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // Tabela de Tarefas
    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textType,
        priority $textType,
        completed $intType,
        createdAt $textType,
        photoPaths TEXT NOT NULL DEFAULT '[]', 
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT
      )
    ''');

    // MUDANÇA 2: Criamos a tabela sync_queue para novas instalações
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL, 
        task_id INTEGER,
        payload TEXT,
        createdAt TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrações legadas (v1 a v5)
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE tasks ADD COLUMN photoPaths TEXT NOT NULL DEFAULT '[]'");
      await db.execute("UPDATE tasks SET photoPaths = '[\"' || photoPath || '\"]' WHERE photoPath IS NOT NULL AND photoPath != ''");
    }

    // MUDANÇA 3: Migração para v6 - Criação da tabela de fila de sincronização
    // Requisito: "Implementar a tabela sync_queue no SQLite"
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL, -- Valores: 'CREATE', 'UPDATE', 'DELETE'
          task_id INTEGER,      -- ID da tarefa afetada
          payload TEXT,         -- JSON completo da tarefa (para Create/Update)
          createdAt TEXT        -- Para garantir a ordem cronológica
        )
      ''');
      print('✅ Banco migrado para v6 (Fila de Sincronização criada)');
    }
  }

  // --- MÉTODOS CRUD DE TAREFAS (Mantidos iguais) ---

  Future<Task> create(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<Task?> read(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await instance.database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> update(Task task) async {
    final db = await instance.database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();

    return allTasks.where((task) {
      if (!task.hasLocation) return false;
      final latDiff = (task.latitude! - latitude).abs();
      final lonDiff = (task.longitude! - longitude).abs();
      final distance = ((latDiff * 111000) + (lonDiff * 111000)) / 2;
      return distance <= radiusInMeters;
    }).toList();
  }

  // --- NOVOS MÉTODOS: FILA DE SINCRONIZAÇÃO (OFFLINE-FIRST) ---

  // 1. Adicionar ação à fila
  Future<int> addToQueue(String action, int taskId, String payload) async {
    final db = await instance.database;
    return await db.insert('sync_queue', {
      'action': action,
      'task_id': taskId,
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // 2. Ler toda a fila (Ordenada por criação para processar na ordem certa)
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'createdAt ASC');
  }

  // 3. Remover item da fila (Chamado após sucesso na API)
  Future<int> removeFromQueue(int id) async {
    final db = await instance.database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // 4. Verificar se uma tarefa específica tem pendências (Para a UI pintar o ícone laranja)
  Future<bool> isTaskUnsynced(int taskId) async {
    final db = await instance.database;
    final result = await db.query(
      'sync_queue',
      where: 'task_id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}