import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/jobs_provider.dart';
import 'services/api_service.dart';
import 'services/message_realtime_service.dart';
import 'router.dart';

void main() {
  final apiService = ApiService();
  final realtimeService = MessageRealtimeService(apiService);
  runApp(MyApp(apiService: apiService, realtimeService: realtimeService));
}

class MyApp extends StatelessWidget {
  final ApiService apiService;
  final MessageRealtimeService realtimeService;

  const MyApp({
    super.key,
    required this.apiService,
    required this.realtimeService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<MessageRealtimeService>.value(value: realtimeService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService, realtimeService),
        ),
        ChangeNotifierProvider(create: (_) => JobsProvider(apiService)),
      ],
      child: MaterialApp.router(
        title: 'Empleo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
