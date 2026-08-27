import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/models/order_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'l10n/app_localizations.dart';

import 'screens/customer/customer_shell.dart';
import 'screens/customer/order_history_screen.dart';
import 'screens/staff/admin_screen.dart';
import 'screens/staff/barista_screen.dart';
import 'screens/staff/manager_screen.dart';
import 'data/catalog.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'state/app_state.dart';
import 'services/api_service.dart';
import 'services/realtime_service.dart';
import 'theme.dart';
import 'utils/page_transitions.dart';

import 'router/app_router.dart';
import 'package:go_router/go_router.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const onesignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
  if (onesignalAppId.isNotEmpty) {
    try {
      OneSignal.initialize(onesignalAppId);
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('OneSignal init error: $e');
    }
  }

  try {
    await Catalog.instance.load().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Catalog load error or timeout: $e');
  }

  runApp(const EmarKafeApp());
}

class EmarKafeApp extends StatelessWidget {
  const EmarKafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        Provider<RealtimeService>(create: (_) => RealtimeService()..init()),
        ChangeNotifierProxyProvider<ApiService, AuthNotifier>(
          create: (ctx) => AuthNotifier(ctx.read<ApiService>()),
          update: (_, api, auth) => auth ?? AuthNotifier(api),
        ),
        ChangeNotifierProxyProvider2<ApiService, AuthNotifier, CartNotifier>(
          create: (ctx) =>
              CartNotifier(ctx.read<ApiService>(), ctx.read<AuthNotifier>()),
          update: (_, api, auth, cart) => cart ?? CartNotifier(api, auth),
        ),
        ChangeNotifierProxyProvider2<ApiService, AuthNotifier, WalletNotifier>(
          create: (ctx) =>
              WalletNotifier(ctx.read<ApiService>(), ctx.read<AuthNotifier>()),
          update: (_, api, auth, wallet) => wallet ?? WalletNotifier(api, auth),
        ),
        ChangeNotifierProxyProvider4<
          ApiService,
          AuthNotifier,
          CartNotifier,
          WalletNotifier,
          OrderNotifier
        >(
          create: (ctx) => OrderNotifier(
            ctx.read<ApiService>(),
            ctx.read<AuthNotifier>(),
            ctx.read<CartNotifier>(),
            ctx.read<WalletNotifier>(),
            realtime: ctx.read<RealtimeService>(),
          ),
          update: (ctx, api, auth, cart, wallet, orders) =>
              orders ?? OrderNotifier(api, auth, cart, wallet, realtime: ctx.read<RealtimeService>()),
        ),
        ChangeNotifierProxyProvider<ApiService, MenuNotifier>(
          create: (ctx) => MenuNotifier(ctx.read<ApiService>()),
          update: (_, api, menu) => menu ?? MenuNotifier(api),
        ),
        ChangeNotifierProxyProvider2<ApiService, AuthNotifier, StockNotifier>(
          create: (ctx) =>
              StockNotifier(ctx.read<ApiService>(), ctx.read<AuthNotifier>()),
          update: (_, api, auth, stock) => stock ?? StockNotifier(api, auth),
        ),
        ChangeNotifierProxyProvider<ApiService, StaffNotifier>(
          create: (ctx) => StaffNotifier(ctx.read<ApiService>()),
          update: (_, api, staff) => staff ?? StaffNotifier(api),
        ),
        ChangeNotifierProvider<AppState>(
          create: (ctx) => AppState(
            ctx.read<AuthNotifier>(),
            ctx.read<CartNotifier>(),
            ctx.read<OrderNotifier>(),
            ctx.read<WalletNotifier>(),
            ctx.read<StockNotifier>(),
            ctx.read<MenuNotifier>(),
            ctx.read<StaffNotifier>(),
          ),
        ),
      ],
      child: const _AppWidget(),
    );
  }
}

class _AppWidget extends StatefulWidget {
  const _AppWidget();

  @override
  State<_AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<_AppWidget> {
  OrderNotifier? _orderNotifier;
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthNotifier>();
    _router ??= AppRouter.createRouter(auth, rootNavigatorKey: navigatorKey);

    final notifier = context.read<OrderNotifier>();
    if (_orderNotifier != notifier) {
      _orderNotifier?.rateReminderNotifier.removeListener(_onRateReminder);
      _orderNotifier = notifier;
      _orderNotifier?.rateReminderNotifier.addListener(_onRateReminder);
    }
  }

  @override
  void dispose() {
    _orderNotifier?.rateReminderNotifier.removeListener(_onRateReminder);
    super.dispose();
  }

  void _onRateReminder() {
    final order = _orderNotifier?.rateReminderNotifier.value;
    if (order != null) {
      _showRateReminder(order);
    }
  }

  void _showRateReminder(OrderRecord order) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          '☕ ${order.id} nasıldı? Siparişini değerlendirmek ister misin?',
        ),
        action: SnackBarAction(
          label: 'Değerlendir',
          onPressed: () => navigatorKey.currentState?.push(
            softRoute(const OrderHistoryScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthNotifier>();
    _router ??= AppRouter.createRouter(auth, rootNavigatorKey: navigatorKey);

    return MaterialApp.router(
      title: 'EMAR Kafe',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: EmarTheme.light(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
