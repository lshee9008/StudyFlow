// API 베이스 URL
// - 로컬 개발: http://127.0.0.1:8000 (기본값)
// - 프로덕션: flutter build web --dart-define=API_BASE=https://studyflow-api.onrender.com
const String baseUrl = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:8000',
);

bool isOnlineMode = true;
