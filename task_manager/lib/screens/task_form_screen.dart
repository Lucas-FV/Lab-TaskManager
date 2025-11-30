import 'dart:io';
import 'package:flutter/material.dart';
import '../models/task.dart';
// REMOVIDO: import '../services/database_service.dart'; // Não chamamos mais o banco direto aqui
import '../services/sync_service.dart'; // ADICIONADO: Usamos o SyncService
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../widgets/location_picker.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

enum ImageSourceType { camera, gallery }

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  bool _completed = false;
  bool _isLoading = false;

  List<String> _photoPaths = [];

  double? _latitude;
  double? _longitude;
  String? _locationName;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _completed = widget.task!.completed;
      _photoPaths = List<String>.from(widget.task!.photoPaths);
      _latitude = widget.task!.latitude;
      _longitude = widget.task!.longitude;
      _locationName = widget.task!.locationName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- MÉTODOS DE CÂMERA (Mantidos iguais) ---
  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Selecionar da Galeria'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSourceType.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tirar Foto com a Câmera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSourceType.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSourceType source) async {
    setState(() => _isLoading = true);
    try {
      String? photoPath;
      if (source == ImageSourceType.camera) {
        photoPath = await CameraService.instance.takePicture(context);
      } else {
        photoPath = await CameraService.instance.pickFromGallery(context);
      }

      if (photoPath != null && mounted) {
        setState(() => _photoPaths.add(photoPath!));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSourceType.camera
                ? '📷 Foto capturada!'
                : '🖼️ Foto selecionada!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removePhoto(String pathToRemove) {
    CameraService.instance.deletePhoto(pathToRemove);
    setState(() {
      _photoPaths.remove(pathToRemove);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Foto removida')),
    );
  }

  void _viewPhoto(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // --- MÉTODOS DE GPS (Mantidos iguais) ---
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: LocationPicker(
            initialLatitude: _latitude,
            initialLongitude: _longitude,
            initialAddress: _locationName,
            onLocationSelected: (lat, lon, address) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
                _locationName = address;
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📍 Localização removida')),
    );
  }

  // --- MÉTODO SALVAR (MODIFICADO PARA OFFLINE-FIRST) ---
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Monta o objeto Task com os dados do formulário
      final taskData = Task(
        id: widget.task?.id, // Mantém o ID se for edição
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        completed: _completed,
        photoPaths: _photoPaths,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        createdAt: widget.task?.createdAt, // Mantém data de criação original
      );

      // 2. Chama o SyncService ao invés do DatabaseService
      // O segundo parâmetro indica se é uma atualização (true) ou criação (false)
      final isEditing = widget.task != null;

      await SyncService.instance.saveTask(taskData, isEditing);

      if (mounted) {
        // Mensagem de sucesso genérica (o SyncService já cuidou da lógica de fila)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? '✓ Tarefa salva!' : '✓ Tarefa criada!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
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
      if (mounted) setState(() => _isLoading = false);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TÍTULO
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Digite um título';
                  if (value.trim().length < 3) return 'Mínimo 3 caracteres';
                  return null;
                },
                maxLength: 100,
              ),
              const SizedBox(height: 16),

              // DESCRIÇÃO
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // PRIORIDADE
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Prioridade',
                  prefixIcon: Icon(Icons.flag),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('🟢 Baixa')),
                  DropdownMenuItem(value: 'medium', child: Text('🟡 Média')),
                  DropdownMenuItem(value: 'high', child: Text('🟠 Alta')),
                  DropdownMenuItem(value: 'urgent', child: Text('🔴 Urgente')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 24),

              // SWITCH COMPLETA
              SwitchListTile(
                title: const Text('Tarefa Completa'),
                subtitle: Text(_completed ? 'Sim' : 'Não'),
                value: _completed,
                onChanged: (value) => setState(() => _completed = value),
                activeColor: Colors.green,
                secondary: Icon(
                  _completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _completed ? Colors.green : Colors.grey,
                ),
              ),
              const Divider(height: 32),

              // --- SEÇÃO FOTO ---
              Row(
                children: [
                  const Icon(Icons.photo_camera, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Fotos (${_photoPaths.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoPaths.length + 1,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    if (index == _photoPaths.length) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: SizedBox(
                          width: 100,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _showImageSourceDialog,
                            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [Icon(Icons.add_a_photo), SizedBox(height: 4), Text('Adicionar', style: TextStyle(fontSize: 12))],
                            ),
                          ),
                        ),
                      );
                    }
                    final photoPath = _photoPaths[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTap: () => _viewPhoto(photoPath),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(photoPath), fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: -8, right: -8,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _isLoading ? null : () => _removePhoto(photoPath),
                                icon: const Icon(Icons.remove_circle, color: Colors.red, shadows: [Shadow(color: Colors.white, blurRadius: 4)]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 32),

              // SEÇÃO LOCALIZAÇÃO
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('Localização', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_latitude != null)
                    TextButton.icon(
                      onPressed: _isLoading ? null : _removeLocation,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remover'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_latitude != null && _longitude != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: Text(_locationName ?? 'Localização salva'),
                    subtitle: Text(LocationService.instance.formatCoordinates(_latitude!, _longitude!)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _isLoading ? null : _showLocationPicker,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showLocationPicker,
                  icon: const Icon(Icons.add_location),
                  label: const Text('Adicionar Localização'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
              const SizedBox(height: 32),

              // BOTÃO SALVAR
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTask,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(isEditing ? 'Atualizar' : 'Criar Tarefa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}