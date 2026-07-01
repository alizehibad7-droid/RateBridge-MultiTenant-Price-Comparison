import 'package:flutter/material.dart';

import '../theme/supplier_theme.dart';



class StatusBadgeStyle {

  final Color bg;

  final Color fg;

  const StatusBadgeStyle(this.bg, this.fg);



  static StatusBadgeStyle of(String status) {

    final colors = SupplierStatusColors.forStatus(status);

    return StatusBadgeStyle(colors.bg, colors.fg);

  }

}



class StatusBadge extends StatelessWidget {

  final String label;

  final String status;



  const StatusBadge({super.key, required this.label, required this.status});



  @override

  Widget build(BuildContext context) {

    final style = StatusBadgeStyle.of(status);

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

      decoration: BoxDecoration(

        color: style.bg,

        borderRadius: BorderRadius.circular(FieldRadius.chip),

      ),

      child: Text(

        label,

        style: TextStyle(

          color: style.fg,

          fontSize: 11,

          fontWeight: FontWeight.w600,

        ),

      ),

    );

  }

}



class RatingStars extends StatelessWidget {

  final double value; // 0..5

  final double size;

  final Color color;



  const RatingStars({

    super.key,

    required this.value,

    this.size = 14,

    this.color = FieldColors.accentAmber,

  });



  @override

  Widget build(BuildContext context) {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: List.generate(5, (i) {

        IconData icon;

        if (value >= i + 1) {

          icon = Icons.star;

        } else if (value > i && value < i + 1) {

          icon = Icons.star_half;

        } else {

          icon = Icons.star_border;

        }

        return Icon(icon, size: size, color: color);

      }),

    );

  }

}


