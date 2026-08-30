import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                style: CeoTheme.destructiveButtonStyle(height: 40),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log out'),
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
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
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
      appBar: const CeoAppBar(title: 'Account Settings'),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _statsStream,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _buildProfileHeader(user, company),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: CeoColors.navy, size: 20),
                  const SizedBox(width: 8),
                  _buildSectionTitle('Personal Information'),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(Icons.person_rounded, 'Full Name', user?.name ?? company.ceoFullName ?? 'N/A'),
                _buildInfoRow(Icons.badge_outlined, 'Designation', user?.jobTitle ?? company.designation ?? 'CEO'),
                _buildInfoRow(Icons.credit_card_rounded, 'CNIC', _maskCnic(user?.cnic ?? company.cnicNumber)),
              ]),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(Icons.business_rounded, color: CeoColors.navy, size: 20),
                  const SizedBox(width: 8),
                  _buildSectionTitle('Company Information'),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoCard([
                _buildInfoRow(Icons.apartment_rounded, 'Company Name', company.name),
                _buildInfoRow(Icons.app_registration_rounded, 'Registration #', company.registrationNumber.isEmpty ? 'Not Provided' : company.registrationNumber),
                _buildInfoRow(Icons.category_outlined, 'Company Type', company.companyType ?? 'N/A'),
                _buildInfoRow(Icons.bar_chart_rounded, 'Monthly Volume', company.estimatedMonthlyVolume ?? 'N/A'),
                _buildInfoRow(Icons.location_on_outlined, 'Active Sites', '${company.activeSitesCount ?? 0}'),
              ]),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: CeoColors.navy, size: 20),
                  const SizedBox(width: 8),
                  _buildSectionTitle('Verification Status'),
                ],
              ),
              const SizedBox(height: 12),
              _buildVerificationCard(company),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(Icons.workspace_premium_outlined, color: CeoColors.navy, size: 20),
                  const SizedBox(width: 8),
                  _buildSectionTitle('Subscription Plan'),
                ],
              ),
              const SizedBox(height: 12),
              _buildSubscriptionCard(company),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(Icons.key_rounded, color: CeoColors.navy, size: 20),
                  const SizedBox(width: 8),
                  _buildSectionTitle('Team Access'),
                ],
              ),
              const SizedBox(height: 12),
              _buildInviteKeyCard(context, company),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout Session'),
                  style: CeoTheme.destructiveButtonStyle(height: 52),
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
                  radius: 38,
                  backgroundColor: CeoColors.navy.withValues(alpha: 0.1),
                  backgroundImage: profileImageUrl != null 
                    ? NetworkImage(profileImageUrl) 
                    : (company.logoUrl != null ? NetworkImage(company.logoUrl!) : null),
                  child: (profileImageUrl == null && company.logoUrl == null)
                      ? const Icon(Icons.account_circle_rounded, size: 76, color: CeoColors.navy)
                      : null,
                ),
                if (_isUploadingImage)
                  const CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.black26,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CeoColors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 12, color: CeoColors.navy),
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
                  style: CeoTheme.titleStyle(size: 20),
                ),
                Text(
                  company.name,
                  style: CeoTheme.mutedStyle(size: 14),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusData.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: statusData.fg),
                      const SizedBox(width: 6),
                      Text(
                        company.status.toUpperCase(),
                        style: CeoTheme.bodyStyle(color: statusData.fg).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CeoColors.textGrey),
          const SizedBox(width: 12),
          Text(label, style: CeoTheme.mutedStyle(size: 14)),
          const Spacer(),
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
    final isActive = company.status == 'active';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(borderColor: statusData.fg.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusData.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.verified_rounded : Icons.pending_rounded,
                  color: statusData.fg,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Verified Account' : 'Account ${company.status.toUpperCase()}',
                      style: CeoTheme.bodyStyle(color: CeoColors.navy).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isActive ? 'Your business is verified on RateBridge' : 'Awaiting administrator confirmation',
                      style: CeoTheme.mutedStyle(size: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (company.status == 'rejected' && company.rejectionReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CeoColors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CeoColors.red.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: CeoColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${company.rejectionReason}',
                      style: CeoTheme.bodyStyle(color: CeoColors.red).copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(dynamic company) {
    final plan = company.plan?.toString().toUpperCase() ?? 'FREE';
    final isPremium = company.plan == 'premium';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CeoColors.navy, CeoColors.navy.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CeoColors.navy.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$plan PLAN',
                    style: GoogleFonts.plusJakartaSans(
                      color: CeoColors.amber,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    isPremium ? 'Full Access' : 'Limited Access',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPremium ? Icons.auto_awesome_rounded : Icons.eco_rounded,
                  color: CeoColors.amber,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push(RouteNames.ceoSubscription),
            icon: Icon(isPremium ? Icons.settings_rounded : Icons.upgrade_rounded, size: 18),
            label: Text(isPremium ? 'MANAGE PLAN' : 'UPGRADE TO PREMIUM'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CeoColors.amber,
              foregroundColor: CeoColors.navy,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteKeyCard(BuildContext context, dynamic company) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CeoColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.group_add_rounded, color: CeoColors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: CeoSectionLabel('Field User Invite Code')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CeoColors.screenBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CeoColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    company.inviteCode ?? 'RB-XXXXXX',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CeoColors.navy,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.content_copy_rounded, size: 20, color: CeoColors.navy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: company.inviteCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
                  },
                  tooltip: 'Copy',
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 20, color: CeoColors.navy),
                  onPressed: () => Share.share('Join our construction team on RateBridge using this invite code: ${company.inviteCode}'),
                  tooltip: 'Share',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with your field engineers to link them to your company.',
            style: CeoTheme.mutedStyle(size: 11),
          ),
        ],
      ),
    );
  }
}
