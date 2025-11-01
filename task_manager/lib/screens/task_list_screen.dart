import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart'; // <-- 1. IMPORTAR O NOVO MODELO
import '../services/database_service.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  List<Category> _categories = []; // <-- 2. ADICIONAR LISTA DE CATEGORIAS
  String _filter = 'all'; // all, completed, pending
  String? _categoryFilter; // <-- 3. ADICIONAR FILTRO DE CATEGORIA
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData(); // <-- 4. MUDAR PARA FUNÇÃO ÚNICA DE LOAD
  }

  // 5. ATUALIZAR FUNÇÃO DE LOAD PARA CARREGAR TUDO
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Carrega tarefas e categorias em paralelo
    final tasksFuture = DatabaseService.instance.readAll();
    final categoriesFuture = DatabaseService.instance.readAllCategories();

    final results = await Future.wait([tasksFuture, categoriesFuture]);

    setState(() {
      _tasks = results[0] as List<Task>;
      _categories = results[1] as List<Category>;
      _isLoading = false;
    });
  }

  // 6. ATUALIZAR GETTER DE TAREFAS FILTRADAS
  List<Task> get _filteredTasks {
    List<Task> filtered;

    // 1º: Filtra por Status (todas, pendentes, concluídas)
    switch (_filter) {
      case 'completed':
        filtered = _tasks.where((t) => t.completed).toList();
        break;
      case 'pending':
        filtered = _tasks.where((t) => !t.completed).toList();
        break;
      default:
        filtered = _tasks.toList(); // Cria uma nova lista
    }

    // 2º: Filtra por Categoria (se houver filtro aplicado)
    if (_categoryFilter != null) {
      filtered = filtered.where((t) => t.categoryId == _categoryFilter).toList();
    }

    return filtered;
  }

  // 7. HELPER PARA ENCONTRAR A CATEGORIA PELO ID
  Category? _getCategoryById(String? id) {
    if (id == null) return null;
    try {
      // Encontra a primeira categoria que bate com o ID
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      // Retorna nulo se a categoria não for encontrada
      return null;
    }
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    await _loadData(); // <-- 8. USAR _loadData
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.delete(task.id);
      await _loadData(); // <-- 9. USAR _loadData

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa excluída'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openTaskForm([Task? task]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(task: task),
      ),
    );

    if (result == true) {
      await _loadData(); // <-- 10. USAR _loadData
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // 11. NOVO BOTÃO DE FILTRO DE CATEGORIA
          PopupMenuButton<String>(
            icon: Icon(
              Icons.category_outlined,
              // Muda a cor do ícone se um filtro de categoria estiver ativo
              color: _categoryFilter != null ? Colors.amberAccent : Colors.white,
            ),
            tooltip: 'Filtrar por Categoria',
            onSelected: (value) {
              setState(() {
                _categoryFilter = (value == 'all') ? null : value;
              });
            },
            itemBuilder: (context) => [
              // Opção "Todas"
              const PopupMenuItem(
                value: 'all',
                child: Row(children: [
                  Icon(Icons.clear_all, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Todas as Categorias'),
                ]),
              ),
              // Separador
              const PopupMenuDivider(),
              // Lista de categorias do banco
              ..._categories.map((category) {
                return PopupMenuItem(
                  value: category.id,
                  child: Row(children: [
                    Icon(Icons.circle, color: category.displayColor, size: 16),
                    const SizedBox(width: 8),
                    Text(category.name),
                  ]),
                );
              }),
            ],
          ),

          // Filtro de Status (seu filtro antigo)
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar por Status',
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending_actions),
                    SizedBox(width: 8),
                    Text('Pendentes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Card de Estatísticas (sem alteração)
          if (_tasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.list,
                    'Total',
                    stats['total'].toString(),
                  ),
                  _buildStatItem(
                    Icons.pending_actions,
                    'Pendentes',
                    stats['pending'].toString(),
                  ),
                  _buildStatItem(
                    Icons.check_circle,
                    'Concluídas',
                    stats['completed'].toString(),
                  ),
                ],
              ),
            ),

          // Lista de Tarefas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTasks.isEmpty
                ? _buildEmptyState() // <-- Atualizado
                : RefreshIndicator(
              onRefresh: _loadData, // <-- 12. USAR _loadData
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];
                  // 13. ENCONTRA A CATEGORIA DA TAREFA
                  final category = _getCategoryById(task.categoryId);

                  // 14. PASSA A CATEGORIA PARA O CARD
                  return TaskCard(
                    task: task,
                    category: category,
                    onTap: () => _openTaskForm(task),
                    onToggle: () => _toggleTask(task),
                    onDelete: () => _deleteTask(task),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    // ... (sem alteração)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // 15. ATUALIZAR MENSAGEM DE ESTADO VAZIO
  Widget _buildEmptyState() {
    String message;
    IconData icon;

    // Verifica se o filtro de categoria é o motivo de estar vazio
    if (_categoryFilter != null && _filteredTasks.isEmpty) {
      message = 'Nenhuma tarefa nesta categoria';
      icon = Icons.folder_off;
    }
    // Lógica antiga
    else if (_filter == 'completed') {
      message = 'Nenhuma tarefa concluída ainda';
      icon = Icons.check_circle_outline;
    } else if (_filter == 'pending') {
      message = 'Nenhuma tarefa pendente';
      icon = Icons.pending_actions;
    } else {
      message = 'Nenhuma tarefa cadastrada';
      icon = Icons.task_alt;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openTaskForm(),
            icon: const Icon(Icons.add),
            label: const Text('Criar primeira tarefa'),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    // Calcula estatísticas sobre TODAS as tarefas, não apenas as filtradas.
    // Isso está correto, não mude.
    return {
      'total': _tasks.length,
      'completed': _tasks.where((t) => t.completed).length,
      'pending': _tasks.where((t) => !t.completed).length,
    };
  }
}