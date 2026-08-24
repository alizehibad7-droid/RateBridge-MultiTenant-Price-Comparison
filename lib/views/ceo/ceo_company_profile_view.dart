import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/ceo_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';

class CeoCompanyProfileView extends StatefulWidget {
  const CeoCompanyProfileView({super.key});

  @override
  State<CeoCompanyProfileView> createState() => _CeoCompanyProfileViewState();
}

class _CeoCompanyProfileViewState extends State<CeoCompanyProfileView> {
  final _thresholdController = TextEditingController();
  String? _lastCompanyId;
  Stream<Map<String, dynamic>>? _statsStream;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Initial value
    final company = context.read<CeoViewModel>().company;
    if (company != null) {
      _thresholdController.text = company.autoApprovalThreshold.toStringAsFixed(0);
      _lastCompanyId = company.id;
      _statsStream = context.read<CeoViewModel>().watchDashboardStats(company.id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use Provider.of instead of context.watch to avoid potential issues in didChangeDependencies
    final ceoVM = Provider.of<CeoViewModel>(context);
    final company = ceoVM.company;
    if (company != null && company.id != _lastCompanyId) {
      setState(() {
        _lastCompanyId = company.id;
        _statsStream = ceoVM.watchDashboardStats(company.id);
        _thresholdController.text = company.autoApprovalThreshold.toStringAsFixed(0);
      });
    }
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  String _maskCnic(String? cnic) {
    if (cnic == null || cnic.isEmpty) return 'N/A';
    String digits = cnic.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return cnic;
    return '${digits.substring(0, 5)}-*******-${digits.substring(12)}';
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Log out?'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                style: CeoTheme.destructiveButtonStyle(height: 40),
                child: const Text('Log out'),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthViewModel>().signOut();
    if (context.mounted) {
      context.go(RouteNames.login);
    }
  }

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 80,
    );

    if (pickedFile == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final url = await CloudinaryService.uploadImageBytes(
        bytes: bytes,
        folder: 'ratebridge/profiles',
        filename: 'ceo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (url != null && mounted) {
        final uid = context.read<AuthViewModel>().user?.uid;
        if (uid != null) {
          await context.read<UserRepository>().updateUserDoc(uid, {
            'profileImageUrl': url,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated successfully')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final ceoVM = context.watch<CeoViewModel>();
    final user = authVM.user;
    final company = ceoVM.company;

    if (company == null) {
      return const Scaffold(
        backgroundColor: CeoColors.screenBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'CEO Profile'),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _statsStream,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _buildProfileHeader(user, company),
              const SizedBox(height: 24),

              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow('Full Name', user?.name ?? company.ceoFullName ?? 'N/A'),
                _buildInfoRow('Designation', user?.jobTitle ?? company.designation ?? 'CEO'),
                _buildInfoRow('CNIC', _maskCnic(user?.cnic ?? company.cnicNumber)),
              ]),
              const SizedBox(height: 24),

              _buildSectionTitle('Company Information'),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow('Company Name', company.name),
                _buildInfoRow('Registration #', company.registrationNumber.isEmpty ? 'Not Provided' : company.registrationNumber),
                _buildInfoRow('Company Type', company.companyType ?? 'N/A'),
                _buildInfoRow('Monthly Volume', company.estimatedMonthlyVolume ?? 'N/A'),
                _buildInfoRow('Active Sites', '${company.activeSitesCount ?? 0}'),
              ]),
              const SizedBox(height: 24),

              _buildSectionTitle('Verification Status'),
              const SizedBox(height: 12),
              _buildVerificationCard(company),
              const SizedBox(height: 24),

              _buildSectionTitle('Subscription Plan'),
              const SizedBox(height: 12),
              _buildSubscriptionCard(company),
              const SizedBox(height: 24),

              _buildSectionTitle('Company Invite Code'),
              const SizedBox(height: 12),
              _buildInviteKeyCard(context, company),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: CeoTheme.destructiveButtonStyle(height: 52),
                  child: const Text('Log out'),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 5),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: CeoTheme.titleStyle(size: 16));
  }

  Widget _buildProfileHeader(dynamic user, dynamic company) {
    final statusData = CeoTheme.statusColors(company.status);
    final profileImageUrl = user?.profileImageUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: CeoTheme.cardDecoration(),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickProfileImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: CeoColors.navy.withValues(alpha: 0.1),
                  backgroundImage: profileImageUrl != null 
                    ? NetworkImage(profileImageUrl) 
                    : (company.logoUrl != null ? NetworkImage(company.logoUrl!) : null),
                  child: (profileImageUrl == null && company.logoUrl == null)
                      ? const Icon(Icons.person, size: 35, color: CeoColors.navy)
                      : null,
                ),
                if (_isUploadingImage)
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.black26,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: CeoColors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 12, color: CeoColors.navy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? company.ceoFullName ?? 'CEO',
                  style: CeoTheme.titleStyle(size: 18),
                ),
                Text(
                  company.name,
                  style: CeoTheme.mutedStyle(),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusData.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    company.status.toUpperCase(),
                    style: CeoTheme.bodyStyle(color: statusData.fg).copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: CeoTheme.mutedStyle(size: 14)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: CeoTheme.bodyStyle(color: CeoColors.navy).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(dynamic company) {
    final statusData = CeoTheme.statusColors(company.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(borderColor: statusData.fg.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                company.status == 'active' ? Icons.verified : Icons.info_outline,
                color: statusData.fg,
              ),
              const SizedBox(width: 8),
              Text(
                'Status: ${company.status.toUpperCase()}',
                style: CeoTheme.bodyStyle(color: statusData.fg).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (company.status == 'rejected' && company.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${company.rejectionReason}',
              style: CeoTheme.bodyStyle(color: CeoColors.red).copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(dynamic company) {
    final plan = company.plan?.toString().toUpperCase() ?? 'FREE';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CeoColors.navy, CeoColors.navy.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$plan PLAN',
                style: const TextStyle(color: CeoColors.amber, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const Icon(Icons.star, color: CeoColors.amber),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            company.plan == 'premium' ? 'Unlimited connections & RFQ active' : 'Basic business features active',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push(RouteNames.ceoSubscription),
            style: ElevatedButton.styleFrom(
              backgroundColor: CeoColors.amber,
              foregroundColor: CeoColors.navy,
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text('MANAGE SUBSCRIPTION'),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteKeyCard(BuildContext context, dynamic company) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CeoSectionLabel('Field User Invite Code'),
                const SizedBox(height: 4),
                Text(
                  company.inviteCode ?? 'RB-XXXXXX',
                  style: CeoTheme.titleStyle(size: 20).copyWith(letterSpacing: 2),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: CeoColors.navy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: company.inviteCode ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: CeoColors.navy),
            onPressed: () => Share.share('Join our team on RateBridge using code: ${company.inviteCode}'),
          ),
        ],
      ),
    );
  }
}
