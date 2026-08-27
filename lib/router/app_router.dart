import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/order_record.dart';
import '../models/staff_member.dart';
import '../state/notifiers/auth_notifier.dart';
import '../screens/customer/customer_shell.dart';
import '../screens/login_screen.dart';
import '../screens/customer/wallet_screen.dart';
import '../screens/customer/order_history_screen.dart';
import '../screens/customer/order_tracking_screen.dart';
import '../screens/customer/chat_assistant_screen.dart';
import '../screens/staff/barista_screen.dart';
import '../screens/staff/manager_screen.dart';
import '../screens/staff/admin_screen.dart';
import '../screens/staff/qr_scanner_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthNotifier authNotifier, {GlobalKey<NavigatorState>? rootNavigatorKey}) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: authNotifier,
      redirect: (context, state) {
        final isLoggedIn = authNotifier.loggedIn;
        final role = authNotifier.role;
        final path = state.uri.path;

        final isAuthRoute = path == '/login';
        final isStaffAdminRoute = path == '/staff/admin';
        final isStaffManagerRoute = path == '/staff/manager';
        final isStaffBaristaRoute = path == '/staff/barista';
        final isStaffScanQrRoute = path == '/staff/scan-qr';
        final isStaffRoute = isStaffAdminRoute || isStaffManagerRoute || isStaffBaristaRoute || isStaffScanQrRoute;
        final isProtectedRoute = path == '/wallet' || path == '/orders/history' || path == '/chat';

        // 1. Unauthenticated users trying to access protected customer or staff routes
        if (!isLoggedIn) {
          if (isStaffRoute || isProtectedRoute) {
            return '/login';
          }
          return null;
        }

        // 2. Authenticated staff redirection from root / login
        if (path == '/' || isAuthRoute) {
          if (role == UserRole.barista) return '/staff/barista';
          if (role == UserRole.manager || role == UserRole.branchManager) return '/staff/manager';
          if (role == UserRole.admin) return '/staff/admin';
        }

        // 3. Role-based access guards for staff routes
        if (isStaffAdminRoute && role != UserRole.admin) {
          return '/';
        }
        if (isStaffManagerRoute && (role != UserRole.manager && role != UserRole.branchManager && role != UserRole.admin)) {
          return '/';
        }
        if (isStaffBaristaRoute && (role != UserRole.barista && role != UserRole.admin)) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CustomerShell(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/wallet',
          builder: (context, state) => const WalletScreen(),
        ),
        GoRoute(
          path: '/orders/history',
          builder: (context, state) => const OrderHistoryScreen(),
        ),
        GoRoute(
          path: '/orders/tracking',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is OrderRecord) {
              return OrderTrackingScreen(order: extra);
            }
            if (extra is Map<String, dynamic> && extra['order'] is OrderRecord) {
              return OrderTrackingScreen(
                order: extra['order'] as OrderRecord,
                qrToken: extra['qrToken'] as String?,
              );
            }
            final orderId = state.uri.queryParameters['id'] ?? 'ONGOING';
            final fallbackOrder = OrderRecord(
              id: orderId,
              shortId: orderId.length > 6 ? orderId.substring(0, 6) : orderId,
              userId: 'u-current',
              branchId: state.uri.queryParameters['branch'] ?? 'Şube',
              totalPrice: double.tryParse(state.uri.queryParameters['total'] ?? '0') ?? 0.0,
              items: {},
              createdAt: DateTime.now(),
              status: 'created',
              manualStatus: OrderStatus.received,
            );
            return OrderTrackingScreen(order: fallbackOrder);
          },
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatAssistantScreen(),
        ),
        GoRoute(
          path: '/staff/barista',
          builder: (context, state) => const BaristaScreen(),
        ),
        GoRoute(
          path: '/staff/manager',
          builder: (context, state) => const ManagerScreen(),
        ),
        GoRoute(
          path: '/staff/admin',
          builder: (context, state) => const AdminScreen(),
        ),
        GoRoute(
          path: '/staff/scan-qr',
          builder: (context, state) => const QRScannerScreen(),
        ),
      ],
    );
  }
}
