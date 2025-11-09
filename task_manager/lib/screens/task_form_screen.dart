import 'dart:io';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../widgets/location_picker.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

// Enum para facilitar a escolha da fonte da imagem
enum ImageSourceType { camera, gallery }

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  bool _completed = false;
  bool _isLoading = false;

  // CÂMERA (MODIFICADO)
  // Trocado de String? para List<String>
  List<String> _photoPaths = [];

  // GPS
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
      // MODIFICADO: Carrega a lista
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

  // --- CÂMERA METHODS ATUALIZADOS ---

  /// 1. Mostra o diálogo de escolha (Sem mudanças)
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

  /// 2. Chama o serviço e ADICIONA na lista
  Future<void> _pickImage(ImageSourceType source) async {
    setState(() => _isLoading = true);
    String? photoPath;

    try {
      if (source == ImageSourceType.camera) {
        photoPath = await CameraService.instance.takePicture(context);
      } else {
        photoPath = await CameraService.instance.pickFromGallery(context);
      }

      if (photoPath != null && mounted) {
        // MODIFICADO: Adiciona a nova foto na lista
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
          SnackBar(
            content: Text('Erro ao selecionar imagem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 3. Remover foto (MODIFICADO: Recebe o 'path' a ser removido)
  void _removePhoto(String pathToRemove) {
    // Deleta o arquivo físico
    CameraService.instance.deletePhoto(pathToRemove);
    // Remove da lista na tela
    setState(() {
      _photoPaths.remove(pathToRemove);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Foto removida')),
    );
  }

  /// 4. Visualizar foto (MODIFICADO: Recebe o 'path' a ser visto)
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

  // --- FIM DOS MÉTODOS DE CÂMERA ---

  // GPS METHODS (Sem mudanças)
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
  // --- FIM DOS MÉTODOS DE GPS ---


  // --- MÉTODO SALVAR (MODIFICADO) ---
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.task == null) {
        // CRIAR
        final newTask = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          // MODIFICADO: Salva a lista de fotos
          photoPaths: _photoPaths,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
        );
        await DatabaseService.instance.create(newTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa criada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ATUALIZAR
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          // MODIFICADO: Salva a lista de fotos
          photoPaths: _photoPaths,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
        );
        await DatabaseService.instance.update(updatedTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa atualizada'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
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
                  hintText: 'Ex: Estudar Flutter',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Digite um título';
                  }
                  if (value.trim().length < 3) {
                    return 'Mínimo 3 caracteres';
                  }
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
                  hintText: 'Detalhes...',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
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

              // --- SEÇÃO FOTO (MODIFICADA PARA GALERIA) ---
              Row(
                children: [
                  const Icon(Icons.photo_camera, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Fotos (${_photoPaths.length})', // Mostra a contagem
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // (O botão "Remover" daqui foi movido para cada foto)
                ],
              ),

              const SizedBox(height: 12),

              // Este container vai segurar nossa galeria horizontal
              Container(
                height: 120, // Altura fixa para a galeria
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  // Adicionamos +1 para o botão de "Adicionar"
                  itemCount: _photoPaths.length + 1,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {

                    // O último item é sempre o botão de adicionar
                    if (index == _photoPaths.length) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: SizedBox(
                          width: 100,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _showImageSourceDialog,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo),
                                SizedBox(height: 4),
                                Text('Adicionar', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Se não for o último, é um card de foto
                    final photoPath = _photoPaths[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // A Imagem (com Gesto para ver)
                            GestureDetector(
                              onTap: () => _viewPhoto(photoPath),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(photoPath),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            // O Botão de Remover (no canto)
                            Positioned(
                              top: -8,
                              right: -8,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: _isLoading ? null : () => _removePhoto(photoPath),
                                icon: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 4)
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // --- FIM DA SEÇÃO FOTO ---

              const Divider(height: 32),

              // SEÇÃO LOCALIZAÇÃO
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Localização',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_latitude != null)
                    TextButton.icon(
                      // Desabilita o botão se estiver carregando
                      onPressed: _isLoading ? null : _removeLocation,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remover'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              if (_latitude != null && _longitude != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: Text(_locationName ?? 'Localização salva'),
                    subtitle: Text(
                      LocationService.instance.formatCoordinates(
                        _latitude!,
                        _longitude!,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      // Desabilita o botão se estiver carregando
                      onPressed: _isLoading ? null : _showLocationPicker,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  // Desabilita o botão se estiver carregando
                  onPressed: _isLoading ? null : _showLocationPicker,
                  icon: const Icon(Icons.add_location),
                  label: const Text('Adicionar Localização'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),

              const SizedBox(height: 32),

              // BOTÃO SALVAR
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTask,
                icon: _isLoading
                    ? Container( // Mostra um spinner no botão
                  width: 18,
                  height: 18,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(isEditing ? 'Atualizar' : 'Criar Tarefa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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