/// FastAPI backend base URL.
///
/// `127.0.0.1` reaches the Mac host directly from the iOS Simulator. If you
/// run this against an Android emulator instead, switch to `10.0.2.2`; for a
/// real device, use the host machine's LAN IP.
const policyApiBaseUrl = 'http://127.0.0.1:8000';
