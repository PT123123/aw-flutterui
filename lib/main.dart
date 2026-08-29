import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'platform.dart';
import 'state/api_provider.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPlatformWindow();

  final settings = await AppSettings.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProxyProvider<AppSettings, ApiProvider>(
          create: (_) => ApiProvider(settings),
          update: (_, s, prev) => prev ?? ApiProvider(s),
        ),
      ],
      child: const _Root(),
    ),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return AwApp(darkMode: context.watch<AppSettings>().darkMode);
  }
}
