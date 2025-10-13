import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';

enum FilterStatus { all, pending, completed }

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];

  List<Task> _allTasks = []; // Guarda TODAS as tarefas do banco
  List<Task> _filteredTasks = []; // Guarda as tarefas a serem exibidas na tela
  FilterStatus _currentFilter = FilterStatus.all; // O filtro começa em "Todas"
  final _titleController = TextEditingController();
  String _selectedPriority = 'medium'; // Valor padrão para a prioridade

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await DatabaseService.instance.readAll();
    setState(() {
      _allTasks = tasks;
    });
    _applyFilter(); // Aplica o filtro sempre que as tarefas são carregadas
  }

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final task = Task(
      title: _titleController.text.trim(),
      priority: _selectedPriority, // Use a prioridade selecionada
    );

    await DatabaseService.instance.create(task);
    _titleController.clear();
    _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    _loadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await DatabaseService.instance.delete(id);
    _loadTasks();
  }

  void _applyFilter() {
    setState(() {
      if (_currentFilter == FilterStatus.pending) {
        _filteredTasks = _allTasks.where((task) => !task.completed).toList();
      } else if (_currentFilter == FilterStatus.completed) {
        _filteredTasks = _allTasks.where((task) => task.completed).toList();
      } else {
        _filteredTasks = List.from(_allTasks); // Cópia da lista completa
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
      ),
      body: Column(
        children: [
          // ✨ PASSO 5: Widget para seleção de filtro
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<FilterStatus>(
              segments: const <ButtonSegment<FilterStatus>>[
                ButtonSegment(value: FilterStatus.all, label: Text('Todas')),
                ButtonSegment(value: FilterStatus.pending, label: Text('Pendentes')),
                ButtonSegment(value: FilterStatus.completed, label: Text('Completas')),
              ],
              selected: {_currentFilter},
              onSelectionChanged: (Set<FilterStatus> newSelection) {
                setState(() {
                  _currentFilter = newSelection.first;
                  _applyFilter(); // Aplica o filtro ao mudar a seleção
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Nova tarefa...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedPriority,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPriority = newValue!;
                    });
                  },
                  items: <String>['low', 'medium', 'high']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value[0].toUpperCase() + value.substring(1)),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTask,
                  child: const Text('Adicionar'),
                ),
              ],
            ),
          ),
          Expanded(
            // ✨ PASSO 5: ListView atualizado para usar a lista filtrada
            child: ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return ListTile(
                  leading: Checkbox(
                    value: task.completed,
                    onChanged: (_) => _toggleTask(task),
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text('Prioridade: ${task.priority}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTask(task.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}