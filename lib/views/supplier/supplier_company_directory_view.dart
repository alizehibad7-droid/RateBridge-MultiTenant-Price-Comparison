import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/company_model.dart';
import '../../models/partnership_request_model.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/supplier/supplier_async_states.dart';
import 'partnerships/partnership_ui.dart';

class SupplierCompanyDirectoryView extends StatefulWidget {
  const SupplierCompanyDirectoryView({super.key});

  @override
  State<SupplierCompanyDirectoryView> createState() =>
      _SupplierCompanyDirectoryViewState();
}

class _SupplierCompanyDirectoryViewState
    extends State<SupplierCompanyDirectoryView> {
  final _searchController = TextEditingController();
  String _selectedCity = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SupplierViewModel>();
      vm.ensurePartnershipStatusWatch();
      vm.loadCompanyDirectory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SupplierViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: const SupplierAppBar(title: 'Find Companies'),
      body: Column(
        children: [
          Container(
            color: FieldColors.surfaceWhite,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('find_companies_search'),
              controller: _searchController,
              onChanged: vm.searchCompanies,
              decoration: InputDecoration(
                hintText: 'Search by company name or city...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          vm.searchCompanies('');
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: FieldColors.screenBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: partnershipCities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final city = partnershipCities[index];
                final selected = _selectedCity == city;
                return FilterChip(
                  label: Text(city == 'All' ? 'All Cities' : city),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedCity = city);
                    vm.filterCompanyDirectoryByCity(city);
                  },
                  backgroundColor: FieldColors.surfaceWhite,
                  selectedColor: FieldColors.accentAmber,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? FieldColors.primaryNavy
                        : FieldColors.textSecondary,
                  ),
                  side: BorderSide(
                    color: selected
                        ? FieldColors.accentAmber
                        : FieldColors.borderSubtle,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ),
          Expanded(child: _buildList(vm)),
        ],
      ),
    );
  }

  Widget _buildList(SupplierViewModel vm) {
    if (vm.isLoading && vm.companyDirectory.isEmpty) {
      return const SupplierListSkeleton(itemCount: 3, itemHeight: 120);
    }
    if (vm.companyDirectory.isEmpty) {
      final query = _searchController.text.trim();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                query.isEmpty
                    ? 'No active companies found'
                    : 'No companies found for \'$query\'',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: FieldColors.primaryNavy,
                ),
                textAlign: TextAlign.center,
              ),
              if (query.isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    vm.searchCompanies('');
                    setState(() {});
                  },
                  child: const Text('Clear search'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.companyDirectory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _CompanyDirectoryCard(
        company: vm.companyDirectory[index],
        vm: vm,
      ),
    );
  }
}

class _CompanyDirectoryCard extends StatelessWidget {
  final CompanyModel company;
  final SupplierViewModel vm;

  const _CompanyDirectoryCard({required this.company, required this.vm});

  @override
  Widget build(BuildContext context) {
    final action = vm.directoryActionFor(company.id);
    final categories = vm.interestCategoriesFor(company);
    final typeLine = [
      if (company.companyType != null && company.companyType!.isNotEmpty)
        company.companyType!,
      if (company.city.isNotEmpty) company.city,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: partnershipCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          companyInitialsAvatar(company.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                ),
                if (typeLine.isNotEmpty)
                  Text(
                    typeLine,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: FieldColors.textSecondary,
                    ),
                  ),
                Text(
                  'Active since ${company.createdAt.year}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: FieldColors.textMuted,
                  ),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categories
                        .map(
                          (c) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: FieldColors.accentAmber
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: FieldColors.primaryNavy,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DirectoryActionButton(
            action: action,
            company: company,
            vm: vm,
          ),
        ],
      ),
    );
  }
}

class _DirectoryActionButton extends StatelessWidget {
  final String action;
  final CompanyModel company;
  final SupplierViewModel vm;

  const _DirectoryActionButton({
    required this.action,
    required this.company,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    switch (action) {
      case 'Partners ✓':
        return _pillButton(
          label: action,
          enabled: false,
          filled: false,
          color: FieldColors.statusSuccess,
        );
      case 'Pending':
        return _pillButton(
          label: action,
          enabled: false,
          filled: false,
          color: FieldColors.accentAmber,
        );
      case 'Respond':
        return _pillButton(
          label: action,
          enabled: true,
          filled: true,
          color: FieldColors.primaryNavy,
          onTap: () => _respondSheet(context),
        );
      case 'Request Again':
        return _pillButton(
          label: action,
          enabled: true,
          filled: false,
          color: FieldColors.textSecondary,
          onTap: () => _sendSheet(context),
        );
      default:
        return _pillButton(
          label: 'Send Request',
          enabled: true,
          filled: true,
          color: FieldColors.accentAmber,
          textColor: FieldColors.primaryNavy,
          onTap: () => _sendSheet(context),
        );
    }
  }

  Widget _pillButton({
    required String label,
    required bool enabled,
    required bool filled,
    required Color color,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    final child = Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textColor ?? (filled ? Colors.white : color),
      ),
    );
    if (filled) {
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 36),
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 36),
        ),
        child: child,
      ),
    );
  }

  void _sendSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send Partnership Request',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: FieldColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                company.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: FieldColors.accentAmber,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 200,
                onChanged: (_) => setSheetState(() {}),
                decoration: const InputDecoration(
                  hintText:
                      'Introduce yourself or mention which materials you supply...',
                  border: OutlineInputBorder(),
                ),
              ),
              Text(
                '${controller.text.length}/200',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: FieldColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final msg = controller.text.trim();
                    Navigator.pop(ctx);
                    final ok = await vm.sendPartnershipRequest(
                      company.id,
                      message: msg.isEmpty ? null : msg,
                    );
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Partnership request sent.')),
                      );
                    }
                  },
                  child: const Text('Send Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _respondSheet(BuildContext context) {
    PartnershipRequestModel? request;
    for (final r in vm.pendingCeoInvitations) {
      if (r.companyId == company.id) {
        request = r;
        break;
      }
    }
    if (request == null) return;
    final req = request;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              company.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (req.message != null && req.message!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                req.message!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: FieldColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final name =
                    await vm.acceptPartnershipRequest(req.requestId);
                if (context.mounted && name != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Partnership accepted with $name')),
                  );
                }
              },
              child: const Text('Accept'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final controller = TextEditingController();
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (innerCtx) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      20 + MediaQuery.of(innerCtx).viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Reason for declining (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(innerCtx);
                            await vm.rejectPartnershipRequest(
                              req.requestId,
                              controller.text.trim(),
                            );
                          },
                          child: const Text('Confirm Decline'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: FieldColors.statusDanger,
              ),
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }
}
