/// Uygulamanın alt sekme (footer) yönlendirmesini TEK merkezden yönetir.
///
/// Sorun: Etkinlikler, Kategori, Favoriler gibi itilerek açılan sayfaların her
/// biri kendi footer `onTap` mantığını farklı uyguluyordu (kimi `popUntil`,
/// kimi `pop`), MainShell'in aktif sekmesi sıfırlanmıyordu. Sonuç: bir alt
/// sayfadan "Ana Sayfa"ya basınca shell'in kaldığı sekme (ör. Hesabım)
/// görünüyordu.
///
/// Çözüm: MainShell açılışta [attach] ile kendini kaydeder. İtilen tüm
/// sayfalar footer dokunuşlarını [select] ile buraya devreder. MainShell önce
/// üstteki tüm sayfaları kapatır, ardından doğru sekmeyi/aksiyonu tetikler.
class MainNav {
  MainNav._();
  static final MainNav instance = MainNav._();

  void Function(int index)? _select;

  /// MainShell tarafından çağrılır (initState).
  void attach(void Function(int index) handler) => _select = handler;

  /// MainShell tarafından çağrılır (dispose).
  void detach(void Function(int index) handler) {
    if (_select == handler) _select = null;
  }

  /// Footer sekme indeksi:
  /// 0 Ana Sayfa · 1 Arama · 2 Kedy · 3 Etkinlikler · 4 Hesabım.
  void select(int index) => _select?.call(index);
}
