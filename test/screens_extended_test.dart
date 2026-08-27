import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/screens/customer/cart_tab.dart';
import 'package:emar_kafe/screens/customer/campaigns_tab.dart';
import 'package:emar_kafe/screens/customer/wallet_screen.dart';
import 'package:emar_kafe/screens/staff/barista_screen.dart';
import 'package:emar_kafe/screens/staff/admin_screen.dart';
import 'package:emar_kafe/screens/staff/manager_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  late ApiService api;
  late AuthNotifier auth;
  late CartNotifier cart;
  late WalletNotifier wallet;
  late OrderNotifier orders;
  late StockNotifier stock;
  late MenuNotifier menu;
  late StaffNotifier staff;
  late AppState appState;

  setUp(() {
    api = ApiService();
    auth = AuthNotifier(api);
    cart = CartNotifier(api, auth);
    wallet = WalletNotifier(api, auth);
    orders = OrderNotifier(api, auth, cart, wallet);
    orders.stopPolling();
    stock = StockNotifier(api, auth);
    menu = MenuNotifier(api);
    staff = StaffNotifier(api);
    appState = AppState(auth, cart, orders, wallet, stock, menu, staff);
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: MaterialApp(home: child),
    );
  }

  group('Extended Screens Widget Tests', () {
    testWidgets('CartTab renders empty state when cart is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: CartTab())),
      );
      expect(find.byType(CartTab), findsOneWidget);
    });

    testWidgets('CampaignsTab renders campaign cards and badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: CampaignsTab())),
      );
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('WalletScreen renders balance and quick topup buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(const WalletScreen()));
      expect(find.text('Cüzdanım'), findsOneWidget);
      expect(find.text('+50₺'), findsOneWidget);
      expect(find.text('+100₺'), findsOneWidget);
    });

    testWidgets('BaristaScreen renders columns and today completed counter', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(buildTestableWidget(const BaristaScreen()));
      expect(find.textContaining('Bugün Tamamlanan:'), findsOneWidget);
    });

    testWidgets('AdminScreen renders summary stats and management tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(buildTestableWidget(const AdminScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Admin · Genel Bakış'), findsOneWidget);
      expect(find.text('Aktif Şube'), findsOneWidget);
      expect(find.text('Personel Ekle'), findsOneWidget);
    });

    testWidgets('ManagerScreen renders shift and revenue management UI', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(buildTestableWidget(const ManagerScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Yönetici'), findsOneWidget);
      expect(find.text('Şube Personeli'), findsOneWidget);
      expect(find.text('Ciro'), findsOneWidget);
    });
  });
}
