import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SessionBootstrapScreen extends StatefulWidget {
  const SessionBootstrapScreen({super.key});

  @override
  State<SessionBootstrapScreen> createState() => _SessionBootstrapScreenState();
}

class _SessionBootstrapScreenState extends State<SessionBootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final authProvider = context.read<AuthProvider>();
    final hasSession = await authProvider.checkSession();
    if (!mounted) return;

    context.go(hasSession ? '/home' : '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
