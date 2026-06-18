// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import 'package:intl/intl.dart';

class SupplierChatView extends StatefulWidget {
  const SupplierChatView({super.key});

  @override
  State<SupplierChatView> createState() => _SupplierChatViewState();
}

class _SupplierChatViewState extends State<SupplierChatView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      if (authVM.user != null) {
        context.read<ChatViewModel>().loadSupplierChats(authVM.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer<ChatViewModel>(
        builder: (context, vm, child) {
          // In ChatViewModel we should have a list of summary/conversation objects
          // Using messages for now as a fallback but the spec implies a list of rows
          if (vm.isLoading) return const Center(child: CircularProgressIndicator());
          
          if (vm.messages.isEmpty) {
            return const Center(child: Text('No active chats', style: TextStyle(color: Colors.grey)));
          }

          // Placeholder for conversation grouping logic
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 1, // Simplified for placeholder
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
                  title: const Text('Order #ORD-7721', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Field User: Salam. Is the delivery on its way?', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat('hh:mm a').format(DateTime.now()), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                  onTap: () => context.push('${RouteNames.supplierChat}/ORD-7721'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
