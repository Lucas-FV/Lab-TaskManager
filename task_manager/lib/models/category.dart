import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  final int color; // Armazenamos como int (ex: 0xFF42A5F5)

  Category({
    String? id,
    required this.name,
    required this.color,
  }) : id = id ?? const Uuid().v4();

  // Converte o int em um objeto Color
  Color get displayColor => Color(color);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      color: map['color'],
    );
  }
}