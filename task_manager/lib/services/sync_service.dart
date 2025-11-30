import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart'; // Para debug prints ou SnackBars se necessário
import '../models/task.dart';
import 'database_service.dart';

class SyncService {
  // Singleton para garantir uma única instância monitorando a rede
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionChangeController = StreamController<bool>.broadcast();

  // Acesso público ao stream de conexão (para o Banner da UI)
  Stream<bool> get connectionStream => _connectionChangeController.stream;

  // Estado atual da conexão
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  // Inicializa o monitoramento de rede
  void initialize() {
    // Verifica status inicial
    _connectivity.checkConnectivity().then(_updateConnectionStatus);

    // Escuta mudanças (Wi-Fi <-> 4G <-> Offline)
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) async {
    // Consideramos online se tiver Mobile ou Wifi
    bool hasConnection = results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);

    // Só dispara se houver mudança de estado real
    if (hasConnection != _isOnline) {
      _isOnline = hasConnection;
      _connectionChangeController.add(_isOnline);
      print("📡 Status de Conexão alterado: ${_isOnline ? 'ONLINE' : 'OFFLINE'}");

      // SE VOLTOU A FICAR ONLINE: Processa a fila!
      if (_isOnline) {
        await _processQueue();
      }
    }
  }

  // --- CORE: SALVAR TAREFA (OFFLINE-FIRST) ---
  // Este método substitui as chamadas diretas ao DatabaseService na UI
  Future<void> saveTask(Task task, bool isEdit) async {
    Task localTask;

    // 1. SEMPRE salva no SQLite primeiro (Garante persistência local imediata)
    try {
      if (isEdit) {
        await DatabaseService.instance.update(task);
        localTask = task; // Tarefa já tem ID
      } else {
        localTask = await DatabaseService.instance.create(task); // Cria e recebe ID
      }
      print("💾 Tarefa salva localmente (SQLite): ${localTask.title}");
    } catch (e) {
      print("❌ Erro crítico ao salvar localmente: $e");
      rethrow; // Se falhar localmente, nem tenta sync
    }

    // 2. Tenta sincronizar ou coloca na fila
    if (_isOnline) {
      try {
        await _sendToApi(isEdit ? 'UPDATE' : 'CREATE', localTask);
        print("☁️ Sincronizado com sucesso na API em tempo real");
      } catch (e) {
        print("⚠️ Falha na API (timeout/erro 500). Adicionando à fila offline.");
        await _addToQueue(isEdit ? 'UPDATE' : 'CREATE', localTask);
      }
    } else {
      print("✈️ Sem internet. Adicionando à fila offline.");
      await _addToQueue(isEdit ? 'UPDATE' : 'CREATE', localTask);
    }
  }

  // --- CORE: DELETAR TAREFA ---
  Future<void> deleteTask(int taskId) async {
    // 1. Remove localmente
    await DatabaseService.instance.delete(taskId);
    print("🗑️ Tarefa $taskId deletada localmente");

    // 2. Sync ou Fila
    if (_isOnline) {
      try {
        await _sendToApi('DELETE', Task(id: taskId, title: '', description: '', priority: ''));
      } catch (e) {
        await DatabaseService.instance.addToQueue('DELETE', taskId, '');
      }
    } else {
      await DatabaseService.instance.addToQueue('DELETE', taskId, '');
    }
  }

  // --- FILA: PROCESSAMENTO EM BACKGROUND ---
  Future<void> _processQueue() async {
    print("🔄 Iniciando processamento da fila de sincronização...");

    final queue = await DatabaseService.instance.getSyncQueue();
    if (queue.isEmpty) {
      print("✅ Fila vazia.");
      return;
    }

    print("📦 Itens na fila: ${queue.length}");

    for (var item in queue) {
      // Se a conexão cair no meio do loop, para.
      if (!_isOnline) break;

      try {
        final id = item['id'] as int;
        final action = item['action'] as String;
        final payload = item['payload'] as String;

        // Reconstrói a task se houver payload (CREATE/UPDATE)
        Task? task;
        if (payload.isNotEmpty) {
          task = Task.fromMap(jsonDecode(payload));
        } else {
          // Caso DELETE, cria task dummy só com ID
          task = Task(id: item['task_id'] as int, title: '', description: '', priority: '');
        }

        print("🚀 Enviando item da fila: $action - ID ${task.id}");

        // Tenta enviar para API
        await _sendToApi(action, task);

        // Se sucesso, remove da fila (Senão, fica lá para a próxima tentativa)
        await DatabaseService.instance.removeFromQueue(id);

      } catch (e) {
        print("❌ Erro ao processar item da fila: $e");
        // Não removemos da fila, tentará novamente na próxima conexão
      }
    }
    print("✅ Processamento da fila concluído.");
  }

  Future<void> _addToQueue(String action, Task task) async {
    // O payload é vazio se for DELETE
    final payload = action == 'DELETE' ? '' : jsonEncode(task.toMap());
    await DatabaseService.instance.addToQueue(action, task.id!, payload);
  }

  // --- API MOCK (SIMULAÇÃO) ---
  // Aqui você colocaria seu Dio ou Http request real
  Future<void> _sendToApi(String action, Task task) async {
    // Simula delay de rede (1.5 segundos)
    await Future.delayed(const Duration(milliseconds: 1500));

    // SIMULAÇÃO DE ERRO ALEATÓRIO (Opcional, para testar robustez)
    // if (DateTime.now().second % 5 == 0) throw Exception("Simulação de Erro 500");

    // LÓGICA LAST-WRITE-WINS (LWW)
    // Na vida real, o servidor retornaria a versão mais atual da task.
    // Se a versão do servidor for mais nova (updatedAt > local), atualizamos o banco local.
    // Exemplo de código real:
    /*
      final response = await dio.post('/tasks', data: task.toMap());
      if (response.data['updatedAt'] > task.updatedAt) {
         await DatabaseService.instance.update(Task.fromMap(response.data));
      }
    */

    print("☁️ [API MOCK] $action processado com sucesso para ID: ${task.id}");
  }
}