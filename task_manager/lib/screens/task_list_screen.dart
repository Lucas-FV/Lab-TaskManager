import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart'; // IMPORTANTE: Importar o SyncService
import '../screens/task_form_screen.dart';
import '../widgets/task_card.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  // Mapa para saber o status de sync de cada tarefa (ID -> Pendente?)
  Map<int, bool> _unsyncedMap = {};
  String _filter = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _setupShakeDetection();
  }

  @override
  void dispose() {
    SensorService.instance.stop();
    super.dispose();
  }

  void _setupShakeDetection() {
    SensorService.instance.startShakeDetection(() {
      _showShakeDialog();
    });
  }

  void _showShakeDialog() {
    final pendingTasks = _tasks.where((t) => !t.completed).toList();

    if (pendingTasks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Nenhuma tarefa pendente!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vibration, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Shake detectado!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecione uma tarefa para completar:'),
            const SizedBox(height: 16),
            ...pendingTasks.take(3).map((task) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _completeTaskByShake(task),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTaskByShake(Task task) async {
    try {
      final updated = task.copyWith(
        completed: true,
        completedAt: DateTime.now(),
        completedBy: 'shake',
      );

      // MODIFICADO: Usa SyncService para garantir fila offline
      await SyncService.instance.saveTask(updated, true);

      Navigator.pop(context);
      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${task.title}" completa via shake!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Garante fechar o dialog em caso de erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final tasks = await DatabaseService.instance.readAll();

      // MODIFICADO: Verifica o status de sincronização de cada tarefa
      final unsyncedMap = <int, bool>{};
      for (var task in tasks) {
        if (task.id != null) {
          unsyncedMap[task.id!] = await DatabaseService.instance.isTaskUnsynced(task.id!);
        }
      }

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _unsyncedMap = unsyncedMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ... (get _filteredTasks e get _statistics mantidos iguais, omitidos para brevidade) ...
  List<Task> get _filteredTasks {
    switch (_filter) {
      case 'pending': return _tasks.where((t) => !t.completed).toList();
      case 'completed': return _tasks.where((t) => t.completed).toList();
      case 'nearby': return _tasks; // Lógica real no _filterByNearby
      default: return _tasks;
    }
  }

  Map<String, int> get _statistics {
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.completed).length;
    final pending = total - completed;
    final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;
    return {'total': total, 'completed': completed, 'pending': pending, 'completionRate': completionRate};
  }

  Future<void> _filterByNearby() async {
    // ... (Mantido igual ao original, mas lembre de recarregar o _unsyncedMap se necessário)
    // Para simplificar, vou manter a lógica original de filtro aqui
    final position = await LocationService.instance.getCurrentLocation();
    if (position == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Sem localização'), backgroundColor: Colors.red));
      return;
    }
    final nearbyTasks = await DatabaseService.instance.getTasksNearLocation(
      latitude: position.latitude, longitude: position.longitude, radiusInMeters: 1000,
    );
    setState(() {
      _tasks = nearbyTasks;
      _filter = 'nearby';
    });
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja deletar "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (task.hasPhoto) {
          for (final path in task.photoPaths) {
            await CameraService.instance.deletePhoto(path);
          }
        }

        // MODIFICADO: Usa SyncService para deletar (API ou Fila)
        await SyncService.instance.deleteTask(task.id!);

        await _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Tarefa deletada')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _toggleComplete(Task task) async {
    try {
      final updated = task.copyWith(
        completed: !task.completed,
        completedAt: !task.completed ? DateTime.now() : null,
        completedBy: !task.completed ? 'manual' : null,
      );

      // MODIFICADO: Usa SyncService
      await SyncService.instance.saveTask(updated, true);

      await _loadTasks();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statistics;
    final filteredTasks = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Botão de Refresh manual para forçar sync se necessário
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _loadTasks,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'nearby') {
                _filterByNearby();
              } else {
                setState(() {
                  _filter = value;
                  if (value != 'nearby') _loadTasks();
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Todas')),
              const PopupMenuItem(value: 'pending', child: Text('Pendentes')),
              const PopupMenuItem(value: 'completed', child: Text('Concluídas')),
              const PopupMenuItem(value: 'nearby', child: Text('Próximas')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: Column(
          children: [
            // MODIFICADO: Banner de Conectividade (Requisito 2)
            StreamBuilder<bool>(
              stream: SyncService.instance.connectionStream,
              initialData: SyncService.instance.isOnline,
              builder: (context, snapshot) {
                final isOnline = snapshot.data ?? false;
                // Se ficar online, recarregamos a lista para atualizar os ícones de sync
                if (isOnline) {
                  // Pequeno delay para dar tempo da fila processar
                  Future.delayed(const Duration(seconds: 2), _loadTasks);
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 30, // Altura fixa do banner
                  width: double.infinity,
                  color: isOnline ? Colors.green : Colors.red,
                  child: Center(
                    child: Text(
                      isOnline ? '🟢 ONLINE' : '🔴 OFFLINE (Modo Avião)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                );
              },
            ),

            // Card Estatísticas (Mantido)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade700]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Total', value: stats['total'].toString(), icon: Icons.list_alt),
                  _StatItem(label: 'Concluídas', value: stats['completed'].toString(), icon: Icons.check_circle),
                  _StatItem(label: 'Taxa', value: '${stats['completionRate']}%', icon: Icons.trending_up),
                ],
              ),
            ),

            // Lista de Tarefas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTasks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];
                  final isUnsynced = _unsyncedMap[task.id] ?? false;

                  // MODIFICADO: Envolvemos o Card em um Stack para colocar o ícone de Sync
                  return Stack(
                    children: [
                      TaskCard(
                        task: task,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TaskFormScreen(task: task)),
                          );
                          if (result == true) _loadTasks();
                        },
                        onDelete: () => _deleteTask(task),
                        onCheckboxChanged: (value) => _toggleComplete(task),
                      ),
                      // Ícone de Status de Sync (Canto superior direito)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black12)],
                          ),
                          child: Icon(
                            isUnsynced ? Icons.cloud_off : Icons.check_circle,
                            size: 16,
                            color: isUnsynced ? Colors.orange : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskFormScreen()),
          );
          if (result == true) _loadTasks();
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
      ),
    );
  }

  Widget _buildEmptyState() {
    // (Mantido igual ao seu código original)
    return const Center(child: Text("Nenhuma tarefa encontrada"));
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
      ],
    );
  }
}