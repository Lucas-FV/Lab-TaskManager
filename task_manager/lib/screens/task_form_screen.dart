import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/category.dart'; // <-- 1. IMPORTAR O NOVO MODELO
import '../services/database_service.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task; // null = criar novo, não-null = editar

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  bool _completed = false;
  DateTime? _dueDate;
  bool _isLoading = false;

  // --- 2. ADICIONAR VARIÁVEIS PARA CATEGORIA ---
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();

    // 3. CARREGAR AS CATEGORIAS
    _loadCategories();

    // Se estiver editando, preencher campos
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _completed = widget.task!.completed;
      _dueDate = widget.task!.dueDate;
      _selectedCategoryId = widget.task!.categoryId; // <-- 4. INICIALIZAR CATEGORIA
    }
  }

  // 5. NOVA FUNÇÃO PARA CARREGAR CATEGORIAS
  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    // Busca as categorias do banco de dados
    final categories = await DatabaseService.instance.readAllCategories();
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;

      // Garante que o ID selecionado (na edição) é válido
      if (widget.task != null && widget.task!.categoryId != null) {
        final ids = categories.map((c) => c.id).toList();
        if (!ids.contains(widget.task!.categoryId)) {
          _selectedCategoryId = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: 'Selecione a data de vencimento',
    );

    if (pickedDate != null && pickedDate != _dueDate) {
      setState(() {
        _dueDate = pickedDate;
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.task == null) {
        // Criar nova tarefa
        final newTask = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          dueDate: _dueDate,
          categoryId: _selectedCategoryId, // <-- 6. SALVAR A CATEGORIA
        );
        await DatabaseService.instance.create(newTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa criada com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Atualizar tarefa existente
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          dueDate: _dueDate,
          categoryId: _selectedCategoryId, // <-- 6. SALVAR A CATEGORIA
        );
        await DatabaseService.instance.update(updatedTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa atualizada com sucesso'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Retorna true = sucesso
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      // 7. ATUALIZAR O BODY PARA MOSTRAR LOADING DE CATEGORIA
      body: _isLoading || _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Campo de Título ---
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  hintText: 'Ex: Estudar Flutter',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, digite um título';
                  }
                  if (value.trim().length < 3) {
                    return 'Título deve ter pelo menos 3 caracteres';
                  }
                  return null;
                },
                maxLength: 100,
              ),

              const SizedBox(height: 16),

              // --- Campo de Descrição ---
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Adicione mais detalhes...',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 5,
                maxLength: 500,
              ),

              const SizedBox(height: 16),

              // --- 8. DROPDOWN DE CATEGORIA ADICIONADO ---
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                // Itens do Dropdown
                items: [
                  // Opção nula (Sem Categoria)
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'Nenhuma',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  // Lista de categorias do banco
                  ..._categories.map((category) {
                    return DropdownMenuItem(
                      value: category.id,
                      child: Row(
                        children: [
                          Icon(Icons.circle,
                              color: category.displayColor, size: 16),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),

              const SizedBox(height: 16),

              // --- Campo de Data (DatePicker) ---
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Vencimento',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: InkWell(
                  onTap: _selectDueDate,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dueDate == null
                            ? 'Nenhuma data selecionada'
                            : DateFormat('dd/MM/yyyy').format(_dueDate!),
                        style: TextStyle(
                          fontSize: 16,
                          color: _dueDate == null
                              ? Colors.grey.shade600
                              : null,
                        ),
                      ),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _dueDate = null),
                          tooltip: 'Limpar data',
                        )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Dropdown de Prioridade ---
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Prioridade',
                  prefixIcon: Icon(Icons.flag),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'low',
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Baixa'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Média'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Alta'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'urgent',
                    child: Row(
                      children: [
                        Icon(Icons.flag, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Urgente'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),

              const SizedBox(height: 16),

              // --- Switch de Completo ---
              Card(
                child: SwitchListTile(
                  title: const Text('Tarefa Completa'),
                  subtitle: Text(
                    _completed
                        ? 'Esta tarefa está marcada como concluída'
                        : 'Esta tarefa ainda não foi concluída',
                  ),
                  value: _completed,
                  onChanged: (value) {
                    setState(() => _completed = value);
                  },
                  secondary: Icon(
                    _completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _completed ? Colors.green : Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- Botões ---
              ElevatedButton.icon(
                onPressed: _saveTask,
                icon: const Icon(Icons.save),
                label:
                Text(isEditing ? 'Atualizar Tarefa' : 'Criar Tarefa'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancelar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}