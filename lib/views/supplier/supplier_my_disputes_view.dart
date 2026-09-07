import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/my_disputes_tracker.dart';
import '../../widgets/supplier_nav_bar.dart';

class SupplierMyDisputesView extends StatelessWidget {
  const SupplierMyDisputesView({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<SupplierViewModel>().profile?.uid ??
        context.watch<AuthViewModel>().user?.uid ??
        '';

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'My Disputes'),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 5),
      body: MyDisputesTracker(uid: uid),
    );
  }
}
