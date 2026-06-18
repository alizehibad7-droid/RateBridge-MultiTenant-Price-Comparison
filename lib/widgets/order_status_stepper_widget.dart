import 'package:flutter/material.dart';

class OrderStatusStepperWidget extends StatelessWidget {
  final String status;

  const OrderStatusStepperWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    int getStep() {
      if (status == 'In Transit') return 0;
      if (status == 'QC Inspection') return 1;
      return 2;
    }

    return Stepper(
      currentStep: getStep(),
      physics: const ClampingScrollPhysics(),
      steps: const [
        Step(title: Text("Escrow Locked / Transit"), content: Text("Sourced material dispatched from Lahore/Karachi depot")),
        Step(title: Text("QC Audit On-Site"), content: Text("Awaiting Field Inspector validation stamp.")),
        Step(title: Text("On Site / Escrow Settled"), content: Text("Sourcing transaction finalized. Supplier dispatched funds released")),
      ],
    );
  }
}
