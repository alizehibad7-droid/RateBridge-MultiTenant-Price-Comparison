import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/ai_viewmodel.dart';
import '../../constants/app_colors.dart';

class PredictiveAiAnalyticsView extends StatefulWidget {
  const PredictiveAiAnalyticsView({super.key});

  @override
  State<PredictiveAiAnalyticsView> createState() => _PredictiveAiAnalyticsViewState();
}

class _PredictiveAiAnalyticsViewState extends State<PredictiveAiAnalyticsView> {
  final _promptController = TextEditingController(text: "Forecast Karachi steel prices for the next 4 weeks assuming fuel price spikes");

  final List<String> _quickScenarios = [
    "Steel volatility in Karachi",
    "Cement price trend Punjab",
    "Logistics & fuel impact",
    "Bricks forecast 2024"
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiViewModel = Provider.of<AiViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        title: const Text('Gemini Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Skyline Headline - Tight tracked & Bold
            Text(
              "Predictive AI Sourcing",
              style: theme.textTheme.displayMedium?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -1.2,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Leverage RateBridge Gemini intelligence to forecast material price swings and supply chain delays with structured market data.",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            
            // Skyline Card Architecture - soft diffused shadow
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics_outlined,
                          color: AppColors.navy,
                          size: 20,
                          weight: 300,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        "Forecasting Parameters",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 16, 
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _promptController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Enter market scenario...",
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.all(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Interactive Quick Selection Chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quickScenarios.map((scenario) {
                      final isSelected = _promptController.text == scenario;
                      return _PressableScale(
                        onTap: () => setState(() => _promptController.text = scenario),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.amber.withValues(alpha: 0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.amber : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            scenario,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.navy : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: _PressableScale(
                      onTap: aiViewModel.isAnalyzing 
                        ? () {} 
                        : () => aiViewModel.runMarketAnalysis(_promptController.text),
                      child: ElevatedButton(
                        onPressed: aiViewModel.isAnalyzing ? null : () => aiViewModel.runMarketAnalysis(_promptController.text),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: AppColors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: aiViewModel.isAnalyzing 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome_outlined, size: 20, color: Colors.white, weight: 300),
                                SizedBox(width: 10),
                                Text("RUN PREDICTIVE MODEL", style: TextStyle(letterSpacing: 0.8, fontWeight: FontWeight.w800)),
                              ],
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Results Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Market Intelligence Output",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18, 
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (aiViewModel.result != null)
                  _PressableScale(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.share_outlined, size: 20, color: AppColors.textPrimary, weight: 300),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (aiViewModel.isAnalyzing)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 3, 
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.amber),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Synthesizing market data...", 
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  aiViewModel.statusFeedback,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.8,
                    color: AppColors.navy.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            const SizedBox(height: 40),
            
            // Skyline Functional Highlight - Contrast through selective Blue
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.navy,
                      size: 22,
                      weight: 300,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Tip: High accuracy forecasts are generated using local market indices and fuel price volatility metrics.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary, 
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
