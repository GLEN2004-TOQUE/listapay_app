/// Supabase project settings.
///
/// Pass your anon key at build/run time (do not commit secrets):
/// `flutter run --dart-define=SUPABASE_ANON_KEY=eyJ...`
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dxxvpickifobdyjwmfpx.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
