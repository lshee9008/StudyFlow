// API 베이스 URL
// - 로컬 개발: http://127.0.0.1:8000
// - 프로덕션: https://awake-reverence-production-0a05.up.railway.app
const String baseUrl = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://awake-reverence-production-0a05.up.railway.app',
);

bool isOnlineMode = true;
