import 'package:flutter/material.dart';

import '../../../models/material_model.dart';

import '../../../theme/field_theme.dart';



IconData fieldMaterialCategoryIcon(String category) {
  final name = category.toLowerCase().trim();
  if (name.contains('cement')) return Icons.layers_outlined;
  if (name.contains('steel') || name.contains('tmt')) {
    return Icons.architecture_outlined;
  }
  if (name.contains('brick')) return Icons.grid_view_outlined;
  if (name.contains('crush') || name.contains('aggregate')) {
    return Icons.grid_view_outlined;
  }
  if (name.contains('sand')) return Icons.terrain_outlined;
  if (name.contains('timber') || name.contains('wood')) {
    return Icons.forest_outlined;
  }
  if (name.contains('paint')) return Icons.format_paint_outlined;
  if (name.contains('pipe')) return Icons.water_outlined;
  if (name.contains('tile')) return Icons.border_all_outlined;
  if (name.contains('sanitary')) return Icons.bathtub_outlined;
  if (name.contains('electrical') || name.contains('cable')) {
    return Icons.electrical_services_outlined;
  }
  if (name.contains('glass')) return Icons.window_outlined;
  switch (name) {
    case 'aggregates':
      return Icons.grid_view_outlined;
    default:
      return Icons.construction_outlined;
  }
}



/// Category icon or Cloudinary material photo with fallback.

class FieldMaterialImageLead extends StatelessWidget {

  final MaterialModel material;

  final double size;

  final bool circular;



  const FieldMaterialImageLead({

    super.key,

    required this.material,

    this.size = 40,

    this.circular = true,

  });



  @override

  Widget build(BuildContext context) {

    final imageUrl = material.profileImageUrl;

    final borderRadius =

        circular ? null : BorderRadius.circular(FieldRadius.button);



    if (imageUrl != null && imageUrl.isNotEmpty) {

      final image = Image.network(

        imageUrl,

        width: size,

        height: size,

        fit: BoxFit.cover,

        errorBuilder: (_, __, ___) => _fallbackIcon(),

      );

      if (circular) {

        return ClipOval(child: SizedBox(width: size, height: size, child: image));

      }

      return ClipRRect(

        borderRadius: borderRadius!,

        child: SizedBox(width: size, height: size, child: image),

      );

    }



    return _fallbackIcon();

  }



  Widget _fallbackIcon() {

    return Container(

      width: size,

      height: size,

      decoration: BoxDecoration(

        color: FieldColors.accentAmber.withValues(alpha: 0.15),

        shape: circular ? BoxShape.circle : BoxShape.rectangle,

        borderRadius: circular ? null : BorderRadius.circular(FieldRadius.button),

      ),

      child: Icon(

        fieldMaterialCategoryIcon(material.category),

        color: FieldColors.primaryNavy,

        size: size * 0.5,

      ),

    );

  }

}



class FieldMaterialCard extends StatelessWidget {

  final MaterialModel material;

  final VoidCallback onTap;



  const FieldMaterialCard({

    super.key,

    required this.material,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(FieldRadius.card),

        child: Ink(

          decoration: FieldTheme.cardDecoration(),

          padding: const EdgeInsets.all(FieldSpacing.md),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              FieldMaterialImageLead(material: material),

              const Spacer(),

              Text(

                material.name,

                style: FieldTypography.titleMedium,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

              ),

              if (material.brand?.trim().isNotEmpty == true) ...[

                const SizedBox(height: 2),

                Text(

                  material.brand!.trim(),

                  style: FieldTypography.bodyMedium.copyWith(

                    fontSize: 11,

                    color: FieldColors.textMuted,

                  ),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                ),

              ],

              const SizedBox(height: FieldSpacing.xs),

              Text(

                material.supplierName,

                style: FieldTypography.bodyMedium,

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

              ),

              const SizedBox(height: FieldSpacing.sm),

              Text(

                'Rs ${material.pricePerUnit.toStringAsFixed(0)}',

                style: FieldTypography.titleMedium.copyWith(

                  color: FieldColors.primaryNavy,

                  fontWeight: FontWeight.w700,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class FieldSearchResultTile extends StatelessWidget {

  final MaterialModel material;

  final VoidCallback onTap;



  const FieldSearchResultTile({

    super.key,

    required this.material,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(FieldRadius.card),

        child: Ink(

          decoration: FieldTheme.cardDecoration(),

          padding: const EdgeInsets.all(FieldSpacing.md),

          child: Row(

            children: [

              FieldMaterialImageLead(material: material, size: 44),

              const SizedBox(width: FieldSpacing.md),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      material.name,

                      style: FieldTypography.titleMedium,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                    ),

                    const SizedBox(height: FieldSpacing.xs),

                    Text(

                      '${material.supplierName} · ${material.category}',

                      style: FieldTypography.bodyMedium,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                    ),

                  ],

                ),

              ),

              const SizedBox(width: FieldSpacing.sm),

              Text(

                'Rs ${material.pricePerUnit.toStringAsFixed(0)}',

                style: FieldTypography.titleMedium.copyWith(

                  color: FieldColors.primaryNavy,

                  fontWeight: FontWeight.w700,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}


