/// Supabase project settings.
///
/// This app defaults to the configured project anon key for convenience.
/// You can still override it at build/run time with:
/// `flutter run --dart-define=SUPABASE_ANON_KEY=eyJ...`
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dxxvpickifobdyjwmfpx.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4eHZwaWNraWZvYmR5andtZnB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NTk3NDUsImV4cCI6MjA5NTEzNTc0NX0.YJW4uPJmNihrxyO-y4G9qONTl-889CAn6BrLGrXahWE',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
