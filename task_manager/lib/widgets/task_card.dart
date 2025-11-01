import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/category.dart'; // <-- 1. IMPORTE CATEGORY

class TaskCard extends StatelessWidget {
  final Task task;
  final Category? category; // <-- 2. RECEBE A CATEGORIA
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    this.category, // <-- 3. ADICIONA AO CONSTRUTOR
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  // --- 4. FUNÇÕES DE PRIORIDADE (RE-ADICIONADAS) ---
  Color _getPriorityColor() {
    switch (task.priority) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'urgent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon() {
    switch (task.priority) {
      case 'urgent':
        return Icons.priority_high;
      default:
        return Icons.flag;
    }
  }

  String _getPriorityLabel() {
    switch (task.priority) {
      case 'low':
        return 'Baixa';
      case 'medium':
        return 'Média';
      case 'high':
        return 'Alta';
      case 'urgent':
        return 'Urgente';
      default:
        return 'Média';
    }
  }

  // --- Função ADICIONADA DO EXERCÍCIO 'dueDate' ---
  bool _isPastDate(DateTime date) {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isBefore(todayDateOnly);
  }

  @override
  Widget build(BuildContext context) {
    final bool isOverdue =
        task.dueDate != null && !task.completed && _isPastDate(task.dueDate!);

    // 5. DEFINE A COR DA CATEGORIA (ou cor padrão)
    final Color categoryColor =
        category?.displayColor ?? Colors.grey.shade400;

    // Cor da Prioridade
    final Color priorityColor = _getPriorityColor();

    final createdAtFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: task.completed ? 1 : (isOverdue ? 4 : 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // --- 6. BORDA USA A COR DA CATEGORIA ---
        side: BorderSide(
          color: isOverdue
              ? Colors.red.shade700
              : (task.completed ? Colors.grey.shade300 : categoryColor),
          width: isOverdue ? 2.5 : 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox (sem alteração)
              Checkbox(
                value: task.completed,
                onChanged: (_) => onToggle(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),

              // Conteúdo Principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título (sem alteração)
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.completed ? Colors.grey : Colors.black,
                      ),
                    ),

                    // Descrição (sem alteração)
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: task.completed
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // --- 7. LINHA DE METADADOS ATUALIZADA ---
                    Wrap(
                      spacing: 12, // Espaço horizontal
                      runSpacing: 8, // Espaço vertical
                      children: [
                        // 1. CHIP DE CATEGORIA
                        if (category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: categoryColor.withOpacity(0.1),
                              border: Border.all(
                                color: categoryColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 14,
                                  color: categoryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  category!.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: categoryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 2. CHIP DE PRIORIDADE
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: priorityColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getPriorityIcon(),
                                size: 14,
                                color: priorityColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getPriorityLabel(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: priorityColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. Data (Lógica do dueDate)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (task.dueDate != null) ...[
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: isOverdue
                                    ? Colors.red
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vence: ${DateFormat('dd/MM/yyyy').format(task.dueDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOverdue
                                      ? Colors.red
                                      : Colors.grey.shade600,
                                  fontWeight: isOverdue
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              if (isOverdue)
                                const Text(
                                  ' - VENCIDA',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                            ] else ...[
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                createdAtFormat.format(task.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // --- BOTÃO DE DELETAR CORRIGIDO ---
              // O IconButton estava faltando aqui
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                tooltip: 'Deletar tarefa',
              ),
            ],
          ),
        ),
      ),
    );
  }
}