import 'package:flutter/material.dart';

import '../models/category_model.dart';

/// Permanent Pakistan construction material category catalog.
class ConstructionCategorySeedEntry {
  final String id;
  final String name;
  final String unit;
  final IconData icon;
  final List<String> brands;
  final List<String> grades;

  const ConstructionCategorySeedEntry({
    required this.id,
    required this.name,
    required this.unit,
    required this.icon,
    this.brands = const [],
    this.grades = const [],
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'icon': CategoryIconCodec.encode(icon),
      'brands': brands,
      'grades': grades,
      'active': true,
      'activeMaterialsCount': 0,
    };
  }

  CategoryModel toCategoryModel() {
    return CategoryModel(
      id: id,
      name: name,
      unit: unit,
      brands: brands,
      grades: grades,
      iconKey: CategoryIconCodec.encode(icon),
      isActive: true,
    );
  }
}

/// Maps [IconData] to stable Firestore string keys and back.
class CategoryIconCodec {
  CategoryIconCodec._();

  static const _byKey = <String, IconData>{
    'layers_outlined': Icons.layers_outlined,
    'architecture_outlined': Icons.architecture_outlined,
    'grid_view_outlined': Icons.grid_view_outlined,
    'terrain_outlined': Icons.terrain_outlined,
    'forest_outlined': Icons.forest_outlined,
    'format_paint_outlined': Icons.format_paint_outlined,
    'water_outlined': Icons.water_outlined,
    'border_all_outlined': Icons.border_all_outlined,
    'bathtub_outlined': Icons.bathtub_outlined,
    'electrical_services_outlined': Icons.electrical_services_outlined,
    'window_outlined': Icons.window_outlined,
    'construction_outlined': Icons.construction_outlined,
  };

  static String encode(IconData icon) {
    for (final entry in _byKey.entries) {
      if (entry.value.codePoint == icon.codePoint &&
          entry.value.fontFamily == icon.fontFamily) {
        return entry.key;
      }
    }
    return 'construction_outlined';
  }

  static IconData decode(String? key) {
    if (key == null || key.isEmpty) return Icons.construction_outlined;
    return _byKey[key] ?? Icons.construction_outlined;
  }
}

/// Pre-defined construction categories for Pakistan market.
const List<ConstructionCategorySeedEntry> kConstructionCategorySeeds = [
  ConstructionCategorySeedEntry(
    id: 'cement',
    name: 'Cement',
    unit: 'bag',
    icon: Icons.layers_outlined,
    brands: [
      'DG Khan',
      'Lucky',
      'Bestway',
      'Fauji',
      'Maple Leaf',
      'Askari',
      'Cherat',
      'Power',
    ],
    grades: ['OPC', 'SRC', 'PPC'],
  ),
  ConstructionCategorySeedEntry(
    id: 'steel',
    name: 'Steel / TMT Bars',
    unit: 'ton',
    icon: Icons.architecture_outlined,
    brands: [
      'Amreli Steels',
      'Mughal Steel',
      'Agha Steel',
      'Ittehad Steel',
      'International Steel',
    ],
    grades: ['Grade 40', 'Grade 60', 'Grade 75'],
  ),
  ConstructionCategorySeedEntry(
    id: 'bricks',
    name: 'Bricks',
    unit: '1000 pieces',
    icon: Icons.grid_view_outlined,
    brands: ['Local Kiln'],
    grades: ['A-Class', 'B-Class'],
  ),
  ConstructionCategorySeedEntry(
    id: 'sand',
    name: 'Sand',
    unit: 'cft',
    icon: Icons.terrain_outlined,
  ),
  ConstructionCategorySeedEntry(
    id: 'crush',
    name: 'Crush / Aggregate',
    unit: 'cft',
    icon: Icons.grid_view_outlined,
    grades: ['3/4 Crush', '1.5 Inch Crush', 'Margalla Crush'],
  ),
  ConstructionCategorySeedEntry(
    id: 'timber',
    name: 'Timber / Wood',
    unit: 'cft',
    icon: Icons.forest_outlined,
    grades: ['Deodar', 'Shesham', 'Kail', 'Imported Pine'],
  ),
  ConstructionCategorySeedEntry(
    id: 'paint',
    name: 'Paint',
    unit: 'liter',
    icon: Icons.format_paint_outlined,
    brands: ['ICI Dulux', 'Berger', 'Brighto', 'Master Paints'],
    grades: ['Emulsion', 'Distemper', 'Enamel', 'Weathershield'],
  ),
  ConstructionCategorySeedEntry(
    id: 'pipes',
    name: 'Pipes (PVC/GI)',
    unit: 'piece',
    icon: Icons.water_outlined,
    brands: ['Dadex', 'Master', 'Beta Pipes', 'Popular Pipes'],
    grades: ['PVC', 'GI', 'UPVC'],
  ),
  ConstructionCategorySeedEntry(
    id: 'tiles',
    name: 'Tiles',
    unit: 'sq ft',
    icon: Icons.border_all_outlined,
    brands: ['Master Tiles', 'Shabbir Tiles', 'Sonex'],
    grades: ['Ceramic', 'Porcelain', 'Vitrified'],
  ),
  ConstructionCategorySeedEntry(
    id: 'sanitary',
    name: 'Sanitary Ware',
    unit: 'piece',
    icon: Icons.bathtub_outlined,
    brands: ['Master Sanitary', 'Porta', 'Pak Sanitary'],
  ),
  ConstructionCategorySeedEntry(
    id: 'electrical',
    name: 'Electrical Wire & Cable',
    unit: 'meter',
    icon: Icons.electrical_services_outlined,
    brands: ['Pakistan Cables', 'Fast Cables', 'Newage Cables'],
  ),
  ConstructionCategorySeedEntry(
    id: 'glass',
    name: 'Glass',
    unit: 'sq ft',
    icon: Icons.window_outlined,
    brands: ['Ghani Glass', 'Tariq Glass'],
    grades: ['Clear', 'Tinted', 'Frosted'],
  ),
];
