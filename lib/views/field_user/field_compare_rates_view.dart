// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/field_user_viewmodel.dart';
import '../../widgets/field/field_widgets.dart';
import 'field_place_order_view.dart';
import 'field_price_trends_view.dart';

class FieldCompareRatesView extends StatefulWidget {
  final String materialName;

  const FieldCompareRatesView({super.key, required this.materialName});

  @override
  State<FieldCompareRatesView> createState() => _FieldCompareRatesViewState();
}

class _FieldCompareRatesViewState extends State<FieldCompareRatesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyId = context.read<AuthViewModel>().companyId;
      if (companyId != null) {
        context
            .read<FieldUserViewModel>()
            .loadCompareRates(companyId, widget.materialName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fieldVm = context.watch<FieldUserViewModel>();
    final results = fieldVm.compareResults;
    final bestPrice =
        results.isNotEmpty ? results.first.pricePerUnit : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.materialName, style: AppTextStyles.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'Price trends',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      FieldPriceTrendsView(materialName: widget.materialName),
                ),
              );
            },
          ),
        ],
      ),
      body: fieldVm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No suppliers currently offer ${widget.materialName}.',
                          style: AppTextStyles.bodyMuted,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: appCardDecoration(
                        shadow: AppShadows.card,
                        borderColor: AppColors.infoBg, // Using infoBg as color wasn't ideal in appCardDecoration, wait, appCardDecoration signature:
                        // BoxDecoration appCardDecoration({List<BoxShadow>? shadow, Color? borderColor,})
                      ),
                      // The user's original code had:
                      // decoration: appCardDecoration(
                      //   shadow: AppShadows.card,
                      //   color: AppColors.infoBg,
                      //   borderColor: AppColors.info.withOpacity(0.2),
                      // ),
                      // But the appCardDecoration in app_theme.dart doesn't have 'color' parameter.
                      // I will stick to what's in app_theme.dart or adjust it.
                      // Actually, I'll use a standard BoxDecoration for that specific container to match the user's intent.
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.primary, size: 18), // AppColors.info not in app_colors.dart, using primary
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${results.length} suppliers found · sorted by lowest price',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...results.map((m) => CompareRateRow(
                          material: m,
                          isBestPrice: m.pricePerUnit == bestPrice,
                          onSelect: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FieldPlaceOrderView(material: m),
                              ),
                            );
                          },
                        )),
                  ],
                ),
    );
  }
}
