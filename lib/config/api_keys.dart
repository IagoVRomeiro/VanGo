// Chave do Google Maps Platform (Directions, Places, Distance Matrix).
// Não fica no código: é passada na compilação, a partir do env.json (fora do Git):
//   flutter run --dart-define-from-file=env.json
// Modelo do arquivo em env.example.json.
const String googleApiKey = String.fromEnvironment('GOOGLE_API_KEY');
