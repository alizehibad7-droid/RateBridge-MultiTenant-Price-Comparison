// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../l10n/app_localizations.dart';

class CeoCompanyProfileView extends StatefulWidget {
  const CeoCompanyProfileView({super.key});

  @override
  State<CeoCompanyProfileView> createState() => _CeoCompanyProfileViewState();
}

class _CeoCompanyProfileViewState extends State<CeoCompanyProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _ceoNameController;
  late TextEditingController _ceoPhoneController;

  @override
  void initState() {
    super.initState();
    final vm = context.read<CeoViewModel>();
    vm.loadCompanyProfile();
    _nameController = TextEditingController(text: vm.company?.name);
    _cityController = TextEditingController(text: vm.company?.city);
    _addressController = TextEditingController(text: vm.company?.address);
    _phoneController = TextEditingController(text: vm.company?.phone);
    _ceoNameController = TextEditingController(text: vm.name); 
    _ceoPhoneController = TextEditingController(); // This could be pulled from user model
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _ceoNameController.dispose();
    _ceoPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // Logic to upload via ViewModel
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authVM = Provider.of<AuthViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.profile, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: () => _handleLogout(authVM),
            tooltip: l10n.signOut,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<CeoViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.company == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final code = viewModel.company?.inviteCode;
          final isGenerating = code == null || code.isEmpty || code == 'RB-XXXXXX';

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surface,
                        backgroundImage: viewModel.company?.logoUrl != null 
                            ? NetworkImage(viewModel.company!.logoUrl!) 
                            : null,
                        child: viewModel.company?.logoUrl == null 
                            ? const Icon(Icons.business_rounded, size: 50, color: AppColors.textSecondary) 
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: const CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildSectionHeader('CORPORATE IDENTITY'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nameController,
                  label: 'Company Name',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(controller: _cityController, label: 'City'),
                const SizedBox(height: 16),
                _buildTextField(controller: _addressController, label: 'Headquarters Address'),
                const SizedBox(height: 16),
                _buildTextField(controller: _phoneController, label: 'Business Contact'),
                
                const SizedBox(height: 32),
                _buildSectionHeader('WORKSPACE INVITATION'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: isGenerating 
                          ? Row(
                              children: [
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 12),
                                Text('Generating...', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                              ],
                            )
                          : Text(
                              code,
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2, color: AppColors.primary),
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                        onPressed: isGenerating ? null : () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        onPressed: () => _confirmRegenerate(viewModel),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                _buildSectionHeader('EXECUTIVE DETAILS'),
                const SizedBox(height: 16),
                _buildTextField(controller: _ceoNameController, label: 'Full Name'),
                const SizedBox(height: 16),
                _buildTextField(controller: _ceoPhoneController, label: 'Personal Phone'),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: viewModel.uid != null ? authVM.user?.email : '',
                  decoration: const InputDecoration(
                    labelText: 'System Email',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await viewModel.updateCompanyProfile({
                        'name': _nameController.text,
                        'city': _cityController.text,
                        'address': _addressController.text,
                        'phone': _phoneController.text,
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile synchronized'), backgroundColor: Colors.green));
                      }
                    }
                  },
                  child: const Text('UPDATE CORPORATE PROFILE'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 1.5));
  }

  Widget _buildTextField({required TextEditingController controller, required String label, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  void _confirmRegenerate(CeoViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Invite Code?'),
        content: const Text('New staff will need the new code to join. The old code will be invalidated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.regenerateInviteCode();
            },
            child: const Text('CONFIRM RESET'),
          ),
        ],
      ),
    );
  }

  void _handleLogout(AuthViewModel authVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Session?'),
        content: const Text('Are you sure you want to exit your corporate dashboard?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authVM.signOut();
              if (mounted) {
                context.go(RouteNames.login);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
