import 'package:flutter/material.dart';

import '../constants/construction_categories_seed.dart';

class CategoryModel {
  final String id;
  final String name;
  final String unit; // 'bag' | 'ton' | 'piece' | 'cubic_ft' | 'kg'
  final List<String> brands;
  final List<String> grades;
  final int activeMaterialsCount;
  final bool isActive;
  final String? iconKey;

  CategoryModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.brands,
    required this.grades,
    this.activeMaterialsCount = 0,
    this.isActive = true,
    this.iconKey,
  });

  IconData get icon => CategoryIconCodec.decode(iconKey);

  CategoryModel copyWith({
    String? id,
    String? name,
    String? unit,
    List<String>? brands,
    List<String>? grades,
    int? activeMaterialsCount,
    bool? isActive,
    String? iconKey,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      brands: brands ?? this.brands,
      grades: grades ?? this.grades,
      activeMaterialsCount: activeMaterialsCount ?? this.activeMaterialsCount,
      isActive: isActive ?? this.isActive,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'brands': brands,
      'grades': grades,
      'activeMaterialsCount': activeMaterialsCount,
      'active': isActive,
      if (iconKey != null && iconKey!.isNotEmpty) 'icon': iconKey,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return CategoryModel(
      id: id ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      unit: map['unit']?.toString() ?? '',
      brands: _stringList(map['brands']),
      grades: _stringList(map['grades']),
      activeMaterialsCount: (map['activeMaterialsCount'] as num?)?.toInt() ?? 0,
      isActive: map['active'] as bool? ?? true,
      iconKey: map['icon']?.toString(),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory CategoryModel.fromDoc(String docId, Map<String, dynamic> map) {
    return CategoryModel.fromMap(map, id: docId);
  }
}
