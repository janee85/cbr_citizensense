import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'router.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ApiService api = kUseMockApi ? MockApiService() : HttpApiService(kApiBaseUrl);
  final auth = AuthProvider(api);
  if (api is HttpApiService) api.onUnauthorized = auth.logout;
  await auth.restore();
  runApp(CitizenSenseApp(api: api, auth: auth));
}

class CitizenSenseApp extends StatefulWidget {
  const CitizenSenseApp({super.key, required this.api, required this.auth});
  final ApiService api;
  final AuthProvider auth;

  @override
  State<CitizenSenseApp> createState() => _CitizenSenseAppState();
}

class _CitizenSenseAppState extends State<CitizenSenseApp> {
  late final DashboardProvider _dashboard;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _dashboard = DashboardProvider(widget.api);
    _router = buildRouter(widget.auth);
  }

  @override
  void dispose() {
    widget.auth.dispose();
    _dashboard.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: widget.api),
        ChangeNotifierProvider<AuthProvider>.value(value: widget.auth),
        ChangeNotifierProvider<DashboardProvider>.value(value: _dashboard),
      ],
      child: MaterialApp.router(
        title: 'Cabadbaran CitizenSense',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
      ),
    );
  }
}
