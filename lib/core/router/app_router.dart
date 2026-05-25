import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/domain/entities/app_user.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';
import 'package:listapay/presentation/auth/change_pin_screen.dart';
import 'package:listapay/presentation/auth/login_screen.dart';
import 'package:listapay/presentation/auth/register_screen.dart';
import 'package:listapay/presentation/customers/customer_form_screen.dart';
import 'package:listapay/presentation/customers/customers_screen.dart';
import 'package:listapay/presentation/debt/debt_detail_screen.dart';
import 'package:listapay/presentation/debt/debt_screen.dart';
import 'package:listapay/presentation/home/home_screen.dart';
import 'package:listapay/presentation/inventory/barcode_scanner_screen.dart';
import 'package:listapay/presentation/inventory/category_screen.dart';
import 'package:listapay/presentation/inventory/inventory_screen.dart';
import 'package:listapay/presentation/inventory/product_form_screen.dart';
import 'package:listapay/presentation/modules/reports_screen.dart';
import 'package:listapay/presentation/modules/settings_screen.dart';
import 'package:listapay/presentation/pos/checkout_screen.dart';
import 'package:listapay/presentation/pos/pos_screen.dart';
import 'package:listapay/presentation/pos/pos_shell.dart';
import 'package:listapay/presentation/pos/product_picker_screen.dart';
import 'package:listapay/presentation/splash/splash_screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const changePin = '/change-pin';
  static const home = '/home';
  static const pos = '/pos';
  static const posCheckout = '/pos/checkout';
  static const posProducts = '/pos/products';
  static const posScan = '/pos/scan';
  static const debt = '/debt';
  static const customers = '/customers';
  static const customerNew = '/customers/new';
  static const inventory = '/inventory';
  static const productNew = '/inventory/product/new';
  static const categories = '/inventory/categories';
  static const barcodeScan = '/inventory/scan';
  static const reports = '/reports';
  static const settings = '/settings';

  static String productEdit(int id) => '/inventory/product/$id';
  static String customerEdit(int id) => '/customers/$id';
  static String debtDetail(int id) => '/debt/$id';
}

bool _isAdminOnlyRoute(String path) =>
    path == AppRoutes.reports;

bool _canAccessRoute(AppUser user, String path) {
  if (_isAdminOnlyRoute(path)) {
    return user.canAccessReports;
  }
  if (path == AppRoutes.settings) {
    return user.canAccessSettings;
  }
  if (path == AppRoutes.pos || path.startsWith('${AppRoutes.pos}/')) {
    return user.canSell;
  }
  if (path == AppRoutes.inventory || path.startsWith('${AppRoutes.inventory}/')) {
    return user.canManageInventory;
  }
  if (path == AppRoutes.customers ||
      path.startsWith('${AppRoutes.customers}/')) {
    return user.canAccessCustomers;
  }
  if (path == AppRoutes.debt || path.startsWith('${AppRoutes.debt}/')) {
    return user.canAccessDebts;
  }
  return true;
}

GoRouter createAppRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefresh(authCubit),
    redirect: (context, state) {
      final auth = authCubit.state;
      final path = state.matchedLocation;

      if (auth.status == AuthStatus.unknown ||
          (auth.status == AuthStatus.loading && path == AppRoutes.splash)) {
        return null;
      }

      final isLoggedIn = auth.status == AuthStatus.authenticated;
      final user = auth.user;

      if (!isLoggedIn && path == AppRoutes.splash) {
        return AppRoutes.login;
      }
      if (!isLoggedIn &&
          path != AppRoutes.login &&
          path != AppRoutes.register) {
        return AppRoutes.login;
      }

      if (isLoggedIn) {
        if (auth.requiresPinChange) {
          if (path != AppRoutes.changePin) {
            return AppRoutes.changePin;
          }
          return null;
        }

        if (path == AppRoutes.changePin && !auth.requiresPinChange) {
          final voluntary = state.extra == true;
          if (!voluntary) return AppRoutes.home;
        }

        if (user != null && !_canAccessRoute(user, path)) {
          return AppRoutes.home;
        }

        if (path == AppRoutes.login ||
            path == AppRoutes.register ||
            path == AppRoutes.splash) {
          return AppRoutes.home;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _buildFadePage(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _buildFadePage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _buildFadePage(state: state, child: const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.changePin,
        pageBuilder: (context, state) {
          final auth = context.read<AuthCubit>().state;
          final forced = auth.requiresPinChange;
          return _buildFadePage(
            state: state,
            child: ChangePinScreen(forced: forced),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) =>
            _buildFadePage(state: state, child: const HomeScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => PosShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.pos,
            builder: (context, state) => const PosScreen(),
            routes: [
              GoRoute(
                path: 'checkout',
                builder: (context, state) => const CheckoutScreen(),
              ),
              GoRoute(
                path: 'products',
                builder: (context, state) => const ProductPickerScreen(),
              ),
              GoRoute(
                path: 'scan',
                builder: (context, state) => const BarcodeScannerScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.debt,
        builder: (context, state) => const DebtScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return DebtDetailScreen(debtId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.customers,
        builder: (context, state) => const CustomersScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const CustomerFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return CustomerFormScreen(customerId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) => const InventoryScreen(),
        routes: [
          GoRoute(
            path: 'product/new',
            builder: (context, state) => const ProductFormScreen(),
          ),
          GoRoute(
            path: 'product/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return ProductFormScreen(productId: id);
            },
          ),
          GoRoute(
            path: 'categories',
            builder: (context, state) => const CategoryScreen(),
          ),
          GoRoute(
            path: 'scan',
            builder: (context, state) => const BarcodeScannerScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

CustomTransitionPage<void> _buildFadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._cubit) {
    _cubit.stream.listen((_) => notifyListeners());
  }

  final AuthCubit _cubit;
}
