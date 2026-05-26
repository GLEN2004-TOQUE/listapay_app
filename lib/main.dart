import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ListaPay/app.dart';
import 'package:ListaPay/core/config/supabase_config.dart';
import 'package:ListaPay/data/services/background_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ListaPayApp(platformInitialization: _initializePlatformServices()));
}

Future<void> _initializePlatformServices() async {
  if (!SupabaseConfig.isConfigured) {
    debugPrint(
      'ListaPay: Supabase not configured — cloud sync disabled. '
      'Pass --dart-define=SUPABASE_ANON_KEY=... to enable.',
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    if (!kIsWeb) {
      await registerBackgroundSync();
    }
  } catch (error, stackTrace) {
    debugPrint('ListaPay: platform initialization failed: $error');
    debugPrint('$stackTrace');
  }
}
