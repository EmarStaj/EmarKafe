import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/customer/customer_shell.dart';
import 'screens/customer/order_history_screen.dart';
import 'screens/staff/admin_screen.dart';
import 'screens/staff/barista_screen.dart';
import 'screens/staff/manager_screen.dart';
import 'data/catalog.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'state/app_state.dart';
import 'services/api_service.dart';
import 'theme.dart';
import 'utils/page_transitions.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // App initialization requires api_service to init properly inside AuthNotifier.
  // But for now, just load catalog.
  
  const onesignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
  if (onesignalAppId.isNotEmpty) {
    OneSignal.initialize(onesignalAppId);
    OneSignal.Notifications.requestPermission(true);
  }

  // Katalog arayüz kurulmadan önce yüklenir; böylece ürün id'leri oturum
  // boyunca sabit kalır ve sepetteki id'ler geçersizleşmez.
  await Catalog.instance.load();
  runApp(const EmarKafeApp());
}

class EmarKafeApp extends StatelessWidget {
  const EmarKafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProxyProvider<ApiService, AuthNotifier>(
          create: (ctx) => AuthNotifier(ctx.read<ApiService>()),
          update: (_, api, auth) => auth ?? AuthNotifier(api),
        ),
        ChangeNotifierProxyProvider2<ApiService, AuthNotifier, CartNotifier>(
          create: (ctx) => CartNotifier(ctx.read<ApiService>(), ctx.read<AuthNotifier>()),
          update: (_, api, auth, cart) => cart ?? CartNotifier(api, auth),
        ),
        ChangeNotifierProxyProvider2<ApiService, AuthNotifier, WalletNotifier>(
          create: (ctx) => WalletNotifier(ctx.read<ApiService>(), ctx.read<AuthNotifier>()),
          update: (_, api, auth, wallet) => wallet ?? WalletNotifier(api, auth),
        ),
        ChangeNotifierProxyProvider4<ApiService, AuthNotifier, CartNotifier, WalletNotifier, OrderNotifier>(
          create: (ctx) => OrderNotifier(ctx.read<ApiService>(), ctx.read<AuthNotifier>(), ctx.read<CartNotifier>(), ctx.read<WalletNotifier>()),
          update: (_, api, auth, cart, wallet, orders) => orders ?? OrderNotifier(api, auth, cart, wallet),
        ),
        ChangeNotifierProxyProvider2<ApiService, AuthNotifier, StockNotifier>(
          create: (ctx) => StockNotifier(ctx.read<ApiService>(), ctx.read<AuthNotifier>()),
          update: (_, api, auth, stock) => stock ?? StockNotifier(api, auth),
        ),
        ChangeNotifierProxyProvider5<AuthNotifier, CartNotifier, OrderNotifier, WalletNotifier, StockNotifier, AppState>(
          create: (ctx) => AppState(ctx.read<AuthNotifier>(), ctx.read<CartNotifier>(), ctx.read<OrderNotifier>(), ctx.read<WalletNotifier>(), ctx.read<StockNotifier>()),
          update: (_, auth, cart, orders, wallet, stock, app) => app ?? AppState(auth, cart, orders, wallet, stock),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderNotifier>().rateReminderNotifier.addListener(_onRateReminder);
    });
  }

  @override
  void dispose() {
    context.read<OrderNotifier>().rateReminderNotifier.removeListener(_onRateReminder);
    super.dispose();
  }

  void _onRateReminder() {
    final order = context.read<OrderNotifier>().rateReminderNotifier.value;
    if (order != null) {
      _showRateReminder(order);
    }
  }

  void _showRateReminder(OrderRecord order) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('☕ ${order.id} nasıldı? Siparişini değerlendirmek ister misin?'),
        action: SnackBarAction(
          label: 'Değerlendir',
          onPressed: () => navigatorKey.currentState?.push(softRoute(const OrderHistoryScreen())),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'EMAR Kafe',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: EmarTheme.light(),
        darkTheme: EmarTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _RootRouter(),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Girişsiz kullanıcı da ana ekranı misafir olarak gezebilir;
    // giriş yalnızca sağ üstteki profil ikonuyla tetiklenir.
    if (!app.loggedIn) return const CustomerShell();
    return switch (app.role) {
      UserRole.customer => const CustomerShell(),
      UserRole.barista => const BaristaScreen(),
      UserRole.manager => const ManagerScreen(),
      UserRole.branchManager => const ManagerScreen(),
      UserRole.admin => const AdminScreen(),
    };
  }
}
