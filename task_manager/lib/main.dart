import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'services/sync_service.dart'; // Importe o SyncService
import 'screens/task_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar serviços
  await CameraService.instance.initialize();

  // MODIFICADO: Inicializa o SyncService para monitorar rede e filas
  SyncService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Offline-First', // Título atualizado
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const TaskListScreen(),
    );
  }
}