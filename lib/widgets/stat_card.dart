import 'package:flutter/material.dart';



import '../theme/supplier_theme.dart';

import '../utils/app_theme.dart';



class StatCard extends StatelessWidget {

  final String label;

  final String value;

  final IconData icon;

  final String? badge;

  final Color? badgeColor;

  final Color? borderLeft;

  final Color valueColor;

  final VoidCallback? onTap;



  const StatCard({

    super.key,

    required this.label,

    required this.value,

    required this.icon,

    this.badge,

    this.badgeColor,

    this.borderLeft,

    this.valueColor = FieldColors.textPrimary,

    this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    final card = Container(

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: FieldColors.surfaceWhite,

        borderRadius: BorderRadius.circular(FieldRadius.card),

        border: Border.all(

          color: borderLeft ?? FieldColors.borderSubtle,

          width: borderLeft != null ? 1.5 : 1,

        ),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Container(

                width: 32,

                height: 32,

                alignment: Alignment.center,

                decoration: BoxDecoration(

                  color: FieldColors.accentAmber.withValues(alpha: 0.15),

                  borderRadius: BorderRadius.circular(FieldRadius.button),

                ),

                child: Icon(icon, size: 16, color: FieldColors.primaryNavy),

              ),

              if (badge != null)

                Container(

                  padding:

                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

                  decoration: BoxDecoration(

                    color: (badgeColor ?? FieldColors.statusSuccess)

                        .withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(FieldRadius.chip),

                  ),

                  child: Text(

                    badge!,

                    style: TextStyle(

                      fontSize: 10,

                      fontWeight: FontWeight.w700,

                      color: badgeColor ?? FieldColors.statusSuccess,

                    ),

                  ),

                ),

            ],

          ),

          const SizedBox(height: 12),

          Text(

            value,

            style: TextStyle(

              fontSize: 18,

              fontWeight: FontWeight.w700,

              color: valueColor,

            ),

          ),

          const SizedBox(height: 2),

          Text(

            label,

            style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),

          ),

        ],

      ),

    );



    if (onTap == null) return card;

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(FieldRadius.card),

        child: card,

      ),

    );

  }

}


