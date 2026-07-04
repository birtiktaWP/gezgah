import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının son aramalarını yerelde (SharedPreferences) tutar.
///
/// Sunucu tarafı `arama_gecmisi` tablosu `/arama` çağrısıyla otomatik dolar;
/// bu servis ise kullanıcıya arama ekranında gösterilecek "Son Aramalar"
/// listesini cihazda saklar. En yeni arama başta olacak şekilde tekilleştirilir
/// ve en fazla [_maxItems] kayıt tutulur.
class SearchHistory {
  SearchHistory._();
  static final SearchHistory instance = SearchHistory._();

  static const _key = 'search_history';
  static const _maxItems = 10;

  Future<List<String>> list() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<List<String>> add(String term) async {
    final t = term.trim();
    if (t.isEmpty) return list();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    // Aynı terimi (büyük/küçük harf duyarsız) kaldırıp en başa ekle.
    current.removeWhere((e) => e.toLowerCase() == t.toLowerCase());
    current.insert(0, t);
    final trimmed = current.take(_maxItems).toList();
    await prefs.setStringList(_key, trimmed);
    return trimmed;
  }

  Future<List<String>> remove(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? <String>[];
    current.removeWhere((e) => e.toLowerCase() == term.toLowerCase());
    await prefs.setStringList(_key, current);
    return current;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
