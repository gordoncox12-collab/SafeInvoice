import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/models.dart';
import 'app_controller.dart';
import 'screens/customer_screens.dart';
import 'screens/excel_settings_screens.dart';
import 'screens/invoice_screens.dart';
import 'screens/shell.dart';
import 'theme.dart';

GoRouter createRouter(AppController controller) {
  return GoRouter(
    refreshListenable: controller,
    initialLocation: '/',
    redirect: (context, state) {
      if (!controller.ready) return null;
      final loc = state.matchedLocation;
      final onboarding = loc == '/onboarding';
      if (controller.businesses.isEmpty && !onboarding) return '/onboarding';
      if (controller.businesses.isNotEmpty && onboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/invoices', builder: (context, state) => const InvoiceListScreen()),
          GoRoute(path: '/customers', builder: (context, state) => const CustomerListScreen()),
          GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
        ],
      ),
      GoRoute(
        path: '/business/:id',
        builder: (context, state) => BusinessEditScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customer/:id',
        builder: (context, state) => CustomerDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/customer-edit/:id',
        builder: (context, state) => CustomerEditScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invoice/:id',
        builder: (context, state) => InvoiceEditScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invoice-view/:id',
        builder: (context, state) => InvoiceViewScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/signature/:id',
        builder: (context, state) => SignatureScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/excel',
        builder: (context, state) => const ExcelHubScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => const TemplateListScreen(),
      ),
      GoRoute(
        path: '/template/:id',
        builder: (context, state) => TemplateEditScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionListScreen(),
      ),
      GoRoute(
        path: '/transaction/new',
        builder: (context, state) => const TransactionEditScreen(),
      ),
      GoRoute(
        path: '/note/:customerId/:noteId',
        builder: (context, state) => NoteEditScreen(
          customerId: state.pathParameters['customerId']!,
          noteId: state.pathParameters['noteId']!,
        ),
      ),
      GoRoute(
        path: '/folder/:customerId/:type',
        builder: (context, state) => FolderScreen(
          customerId: state.pathParameters['customerId']!,
          type: state.pathParameters['type']!,
        ),
      ),
      GoRoute(
        path: '/sheet/:customerId',
        builder: (context, state) => SheetCaptureScreen(customerId: state.pathParameters['customerId']!),
      ),
    ],
  );
}

class SafeInvoiceApp extends StatefulWidget {
  const SafeInvoiceApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<SafeInvoiceApp> createState() => _SafeInvoiceAppState();
}

class _SafeInvoiceAppState extends State<SafeInvoiceApp> {
  late final GoRouter _router = createRouter(widget.controller);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'SafeInvoice',
            debugShowCheckedModeBanner: false,
            theme: safeInvoiceTheme(
              mode: ThemeModeOption.light,
              accent: widget.controller.settings.accentPalette,
              platformBrightness: Brightness.light,
            ),
            darkTheme: safeInvoiceTheme(
              mode: ThemeModeOption.dark,
              accent: widget.controller.settings.accentPalette,
              platformBrightness: Brightness.dark,
            ),
            themeMode: switch (widget.controller.settings.themeMode) {
              ThemeModeOption.light => ThemeMode.light,
              ThemeModeOption.dark => ThemeMode.dark,
              ThemeModeOption.system => ThemeMode.system,
            },
            locale: const Locale('en', 'ZA'),
            supportedLocales: const [Locale('en', 'ZA'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
