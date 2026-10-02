/// Mekan kayıtlarındaki bayrakları toleranslı biçimde okuyan yardımcılar.
///
/// Backend alan adı/tipi henüz kesinleşmediği için (HARITA_PLUS_IKON.md)
/// birden fazla anahtar ve değer biçimi kabul edilir.
library;

/// İşletmenin Gezgah Plus olup olmadığını döner.
///
/// Sırayla `is_plus`, `plus`, `isletme_plus` anahtarlarına bakılır; null
/// olmayan ilk değer belirleyicidir. Doğru kabul edilenler: `true`, 0'dan
/// farklı sayı, `"1"` / `"true"` / `"yes"` / `"evet"` (boşluk ve büyük-küçük
/// harf duyarsız) ve `aktif` alanı doğru olan bir nesne
/// (ör. `plus: {aktif: true}`). Diğer her durumda (alan yoksa dahil) false.
bool parsePlusFlag(Map<String, dynamic> j) {
  for (final key in const ['is_plus', 'plus', 'isletme_plus']) {
    final v = j[key];
    if (v != null) return _truthy(v);
  }
  return false;
}

bool _truthy(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'evet';
  }
  if (v is Map) return _truthy(v['aktif']);
  return false;
}
