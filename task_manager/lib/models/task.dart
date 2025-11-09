// Adicione esta importação no topo do arquivo
import 'dart:convert';

class Task {
  final int? id;
  final String title;
  final String description;
  final String priority;
  final bool completed;
  final DateTime createdAt;

  // CÂMERA (MODIFICADO)
  // Trocamos um único String? por uma Lista de Strings
  final List<String> photoPaths;

  // SENSORES
  final DateTime? completedAt;
  final String? completedBy; // 'manual', 'shake'

  // GPS
  final double? latitude;
  final double? longitude;
  final String? locationName;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.priority,
    this.completed = false,
    DateTime? createdAt,
    // MODIFICADO: Definimos o valor padrão como uma lista vazia
    this.photoPaths = const [],
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
  }) : createdAt = createdAt ?? DateTime.now();

  // Getters auxiliares (MODIFICADO)
  bool get hasPhoto => photoPaths.isNotEmpty; // A lógica mudou
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'completed': completed ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      // MODIFICADO: Codificamos a lista para uma string JSON
      'photoPaths': jsonEncode(photoPaths),
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      priority: map['priority'] as String,
      completed: (map['completed'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      // MODIFICADO: Decodificamos a string JSON de volta para uma lista
      photoPaths: map['photoPaths'] != null
          ? List<String>.from(jsonDecode(map['photoPaths'] as String))
          : [],
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      completedBy: map['completedBy'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['locationName'] as String?,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    // MODIFICADO
    List<String>? photoPaths,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      // MODIFICADO
      photoPaths: photoPaths ?? this.photoPaths,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
    );
  }
}