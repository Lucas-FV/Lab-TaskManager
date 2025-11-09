import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
// Importe o pacote que acabamos de adicionar
import 'package:image_picker/image_picker.dart';

import '../screens/camera_screen.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;
  // Variável para o novo seletor de galeria
  final ImagePicker _picker = ImagePicker();

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      print('✅ CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)');
    } catch (e) {
      print('⚠️ Erro ao inicializar câmera: $e');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  // --- NOVO MÉTODO ---
  /// Abre a galeria do dispositivo para o usuário selecionar uma foto.
  /// Retorna o caminho [String] da foto salva no app, ou null.
  Future<String?> pickFromGallery(BuildContext context) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Opcional: comprime a imagem
      );

      // Se o usuário não selecionou nada
      if (pickedFile == null) return null;

      // RE-UTILIZA SEU MÉTODO DE SALVAR!
      // Isso garante que a foto da galeria seja copiada
      // para o diretório de imagens do seu app.
      final String savedPath = await savePicture(pickedFile);
      return savedPath;

    } catch (e) {
      print('❌ Erro ao pegar imagem da galeria: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir galeria: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // --- SEU MÉTODO ORIGINAL (SEM MUDANÇAS) ---
  /// Abre sua tela [CameraScreen] customizada para tirar uma foto.
  /// Retorna o caminho [String] da foto salva, ou null.
  Future<String?> takePicture(BuildContext context) async {
    if (!hasCameras) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Nenhuma câmera disponível'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return null;

      // Isso navega para sua tela 'camera_screen.dart'
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      return imagePath;
    } catch (e) {
      print('❌ Erro ao abrir câmera: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return null;
    } finally {
      controller.dispose();
    }
  }

  // --- SEU MÉTODO ORIGINAL (SEM MUDANÇAS) ---
  /// Salva a [XFile] no diretório de documentos do app.
  Future<String> savePicture(XFile image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = path.join(appDir.path, 'images', fileName);

      final imageDir = Directory(path.join(appDir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }

      final savedImage = await File(image.path).copy(savePath);
      print('✅ Foto salva: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('❌ Erro ao salvar foto: $e');
      rethrow;
    }
  }

  // --- SEU MÉTODO ORIGINAL (SEM MUDANÇAS) ---
  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao deletar foto: $e');
      return false;
    }
  }
}