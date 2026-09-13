import 'package:flutter/material.dart';

import 'package:shimmer/shimmer.dart';



import '../../theme/supplier_theme.dart';

import '../../utils/app_theme.dart';



/// Icon + title + subtitle empty state for supplier screens.

class SupplierEmptyState extends StatelessWidget {

  final IconData icon;

  final String title;

  final String subtitle;

  final Widget? action;



  const SupplierEmptyState({

    super.key,

    required this.icon,

    required this.title,

    required this.subtitle,

    this.action,

  });



  @override

  Widget build(BuildContext context) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.all(32),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(

              icon,

              size: 64,

              color: FieldColors.textMuted.withValues(alpha: 0.5),

            ),

            const SizedBox(height: 16),

            Text(

              title,

              style: AppTextStyles.emptyTitle.copyWith(

                color: FieldColors.textPrimary,

              ),

              textAlign: TextAlign.center,

            ),

            const SizedBox(height: 8),

            Text(

              subtitle,

              style: AppTextStyles.emptySubtitle.copyWith(

                color: FieldColors.textSecondary,

              ),

              textAlign: TextAlign.center,

            ),

            if (action != null) ...[

              const SizedBox(height: 24),

              action!,

            ],

          ],

        ),

      ),

    );

  }

}



/// Shimmer placeholder rows for list screens.

class SupplierListSkeleton extends StatelessWidget {

  final int itemCount;

  final double itemHeight;



  const SupplierListSkeleton({

    super.key,

    this.itemCount = 4,

    this.itemHeight = 88,

  });



  @override

  Widget build(BuildContext context) {

    return ListView.separated(

      padding: const EdgeInsets.all(16),

      physics: const NeverScrollableScrollPhysics(),

      itemCount: itemCount,

      separatorBuilder: (_, __) => const SizedBox(height: 12),

      itemBuilder: (_, __) => Shimmer.fromColors(

        baseColor: FieldColors.borderSubtle,

        highlightColor: FieldColors.screenBackground,

        child: Container(

          height: itemHeight,

          decoration: BoxDecoration(

            color: FieldColors.borderSubtle,

            borderRadius: BorderRadius.circular(FieldRadius.card),

          ),

        ),

      ),

    );

  }

}



/// Shimmer cards matching the supplier materials list layout.

class SupplierMaterialListSkeleton extends StatelessWidget {

  final int itemCount;



  const SupplierMaterialListSkeleton({super.key, this.itemCount = 4});



  @override

  Widget build(BuildContext context) {

    return ListView.separated(

      padding: const EdgeInsets.all(16),

      physics: const NeverScrollableScrollPhysics(),

      itemCount: itemCount,

      separatorBuilder: (_, __) => const SizedBox(height: 12),

      itemBuilder: (_, __) => Shimmer.fromColors(

        baseColor: FieldColors.borderSubtle,

        highlightColor: FieldColors.screenBackground,

        child: Container(

          height: 96,

          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(

            color: FieldColors.borderSubtle,

            borderRadius: BorderRadius.circular(FieldRadius.card),

          ),

          child: Row(

            children: [

              Container(

                width: 56,

                height: 56,

                decoration: BoxDecoration(

                  color: FieldColors.borderSubtle,

                  borderRadius: BorderRadius.circular(FieldRadius.button),

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [

                    Container(

                      height: 14,

                      width: double.infinity,

                      decoration: BoxDecoration(

                        color: FieldColors.borderSubtle,

                        borderRadius: BorderRadius.circular(4),

                      ),

                    ),

                    const SizedBox(height: 8),

                    Container(

                      height: 12,

                      width: 100,

                      decoration: BoxDecoration(

                        color: FieldColors.borderSubtle,

                        borderRadius: BorderRadius.circular(4),

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}


