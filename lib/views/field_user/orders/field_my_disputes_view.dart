import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/field_theme.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../../../widgets/my_disputes_tracker.dart';

class FieldMyDisputesView extends StatelessWidget {
  const FieldMyDisputesView({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<FieldSessionViewModel>().user?.uid ??
        context.watch<AuthViewModel>().user?.uid ??
        '';

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const FieldAppBar(title: 'My Disputes'),
      body: MyDisputesTracker(uid: uid),
    );
  }
}
