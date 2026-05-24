import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/config/supabase_config.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/data/repositories/local_auth_repository.dart';
import 'package:listapay/data/repositories/local_customer_repository.dart';
import 'package:listapay/data/repositories/local_debt_repository.dart';
import 'package:listapay/data/repositories/local_inventory_repository.dart';
import 'package:listapay/data/repositories/local_pos_repository.dart';
import 'package:listapay/data/services/connectivity_service.dart';
import 'package:listapay/data/services/debt_sms_reminder_service.dart';
import 'package:listapay/data/services/notification_service.dart';
import 'package:listapay/data/services/payment_config_service.dart';
import 'package:listapay/data/services/receipt_service.dart';
import 'package:listapay/data/services/reports_service.dart';
import 'package:listapay/data/services/sms_service.dart';
import 'package:listapay/data/services/store_session_service.dart';
import 'package:listapay/data/services/sync_service.dart';
import 'package:listapay/domain/repositories/auth_repository.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';
import 'package:listapay/domain/repositories/inventory_repository.dart';
import 'package:listapay/domain/repositories/pos_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';

class ListaPayApp extends StatefulWidget {
  const ListaPayApp({super.key});

  @override
  State<ListaPayApp> createState() => _ListaPayAppState();
}

class _ListaPayAppState extends State<ListaPayApp> {
  late final AppDatabase _database;
  late final AuthRepository _authRepository;
  late final InventoryRepository _inventoryRepository;
  late final CustomerRepository _customerRepository;
  late final DebtRepository _debtRepository;
  late final PosRepository _posRepository;
  late final ReceiptService _receiptService;
  late final NotificationService _notificationService;
  late final SmsService _smsService;
  late final DebtSmsReminderService _debtSmsReminderService;
  late final StoreSessionService _storeSessionService;
  late final SyncService _syncService;
  late final ReportsService _reportsService;
  late final PaymentConfigService _paymentConfigService;
  late final ConnectivityService _connectivity;
  late final AuthCubit _authCubit;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSubscription;
  bool _debtCheckRan = false;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _authRepository = LocalAuthRepository(_database);
    _inventoryRepository = LocalInventoryRepository(_database);
    _customerRepository = LocalCustomerRepository(_database);
    _debtRepository = LocalDebtRepository(_database);
    _posRepository = LocalPosRepository(_database, _customerRepository);
    _receiptService = ReceiptService();
    _notificationService = NotificationService(_database, _debtRepository);
    _connectivity = ConnectivityService();
    _smsService = SmsService();
    _debtSmsReminderService = DebtSmsReminderService(
      db: _database,
      debtRepository: _debtRepository,
      connectivity: _connectivity,
      smsService: _smsService,
      notificationService: _notificationService,
    );
    _storeSessionService = StoreSessionService();
    _syncService = SyncService(
      db: _database,
      storeSession: _storeSessionService,
      connectivity: _connectivity,
    );
    _reportsService = ReportsService(_database);
    _paymentConfigService = PaymentConfigService(_database);
    _authCubit = AuthCubit(_authRepository);
    _router = createAppRouter(_authCubit);
    _notificationService.onNavigate = _router.go;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _authRepository.initialize();
    await _inventoryRepository.initialize();
    _authSubscription = _authCubit.stream.listen((state) async {
      if (state.status == AuthStatus.authenticated && !_debtCheckRan) {
        _debtCheckRan = true;
        await _runDebtAndSmsChecks();
      }
      if (state.status == AuthStatus.unauthenticated) {
        _debtCheckRan = false;
      }
    });
    await _authCubit.checkSession();
    if (SupabaseConfig.isConfigured) {
      unawaited(_storeSessionService.restoreSessionIfNeeded());
    }
    // Notifications can prompt for permissions; do not block auth routing.
    unawaited(_notificationService.initialize());
  }

  Future<void> _runDebtAndSmsChecks() async {
    await _notificationService.runDebtChecks();
    await _debtSmsReminderService.processRetryQueue();
    await _debtSmsReminderService.processReminders();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authCubit.close();
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<InventoryRepository>.value(
          value: _inventoryRepository,
        ),
        RepositoryProvider<CustomerRepository>.value(
          value: _customerRepository,
        ),
        RepositoryProvider<DebtRepository>.value(value: _debtRepository),
        RepositoryProvider<PosRepository>.value(value: _posRepository),
        RepositoryProvider<ReceiptService>.value(value: _receiptService),
        RepositoryProvider<NotificationService>.value(
          value: _notificationService,
        ),
        RepositoryProvider<SmsService>.value(value: _smsService),
        RepositoryProvider<DebtSmsReminderService>.value(
          value: _debtSmsReminderService,
        ),
        RepositoryProvider<ConnectivityService>.value(value: _connectivity),
        RepositoryProvider<StoreSessionService>.value(
          value: _storeSessionService,
        ),
        RepositoryProvider<SyncService>.value(value: _syncService),
        RepositoryProvider<ReportsService>.value(value: _reportsService),
        RepositoryProvider<PaymentConfigService>.value(
          value: _paymentConfigService,
        ),
        RepositoryProvider<AppDatabase>.value(value: _database),
      ],
      child: BlocProvider.value(
        value: _authCubit,
        child: MaterialApp.router(
          title: 'ListaPay',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: _router,
        ),
      ),
    );
  }
}
