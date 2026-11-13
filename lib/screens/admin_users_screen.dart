import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';

/// Admin view of every account, where an admin can change roles.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<AppUser>> _users;

  @override
  void initState() {
    super.initState();
    _users = context.read<AuthProvider>().allUsers();
  }

  Future<void> _changeRole(AppUser user, UserRole role) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final products = context.read<ProductProvider>();
    final cart = context.read<CartProvider>();
    try {
      await auth.setRole(user, role);
      await products.load();
      await cart.refresh();
      setState(() => _users = auth.allUsers());
      messenger.showSnackBar(
        SnackBar(content: Text('${user.fullName} is now ${role.label}')),
      );
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: FutureBuilder<List<AppUser>>(
        future: _users,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final user = users[i];
              final isMe = user.id == me?.id;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.canvas,
                      child: Icon(switch (user.role) {
                        UserRole.admin => Icons.shield_rounded,
                        UserRole.seller => Icons.storefront_rounded,
                        UserRole.customer => Icons.person_rounded,
                      }, color: AppColors.violet),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMe ? '${user.fullName} (you)' : user.fullName,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            user.email,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          if (user.isSeller && user.shopName != null)
                            Text(
                              user.shopName!,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.violet,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<UserRole>(
                      enabled: !isMe,
                      tooltip: 'Change role',
                      onSelected: (role) => _changeRole(user, role),
                      itemBuilder: (_) => [
                        for (final role in UserRole.values)
                          if (role != user.role)
                            PopupMenuItem(
                              value: role,
                              child: Text('Make ${role.label}'),
                            ),
                      ],
                      child: Chip(
                        label: Text(user.role.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
