/// FastAPI backend base URL.
///
/// Defaults to `127.0.0.1`, which reaches the Mac host directly from the iOS
/// Simulator (for an Android emulator, use `10.0.2.2`; for a real device, the
/// host machine's LAN IP). For a deployed build (e.g. the web demo), override
/// at build time: `flutter build web --dart-define=API_BASE_URL=https://your-backend.onrender.com`.
const policyApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);
