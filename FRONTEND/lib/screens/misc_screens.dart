import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

/// Route /unauthorized from Activity 6: shown when a role guard fails.
class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline_rounded, size: 44, color: AppColors.star),
            const SizedBox(height: 12),
            const Text('You do not have access to this page.',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(user?.role.home ?? '/login'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Go to my dashboard'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
