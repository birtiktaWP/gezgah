import 'package:flutter/foundation.dart';

import 'api.dart';
import 'auth_service.dart';

/// Uygulama genelinde favori durumunu tutan servis.
///
/// Favori mekan id'lerini [ids] içinde tutar; kartlar/detay bunu dinleyerek
/// kalp ikonunu senkron gösterir. Ekleme/çıkarma iyimser (optimistic) yapılır,
/// hata olursa geri alınır. Favoriler üyeye bağlıdır (FAVORILER.md); giriş
/// yoksa değişiklik yapılmaz.
class FavoritesService {
  FavoritesService._() {
    // Giriş/çıkışta favori kümesini otomatik senkronla.
    AuthService.instance.user.addListener(_onAuthChanged);
  }
  static final FavoritesService instance = FavoritesService._();

  /// Favori mekan id'leri (post_id). Dinleyiciler değişimde bilgilenir.
  final ValueNotifier<Set<int>> ids = ValueNotifier<Set<int>>(<int>{});

  bool isFavorite(int postId) => ids.value.contains(postId);

  void _onAuthChanged() {
    if (AuthService.instance.isLoggedIn) {
      load();
    } else {
      ids.value = <int>{};
    }
  }

  /// Giriş yapılmışsa favori id'lerini sunucudan (sayfalayarak) yükler.
  Future<void> load() async {
    if (!AuthService.instance.isLoggedIn) {
      ids.value = <int>{};
      return;
    }
    try {
      ids.value = await FavRepository.instance.tumFavoriIdleri();
    } catch (_) {
      // Sessiz: kalpler mevcut durumda kalır.
    }
  }

  /// Favoriyi ekler/çıkarır (iyimser). Giriş yoksa [AuthException] fırlatır.
  /// Ağ hatasında değişiklik geri alınır ve hata yeniden fırlatılır.
  Future<void> toggle(int postId) async {
    if (!AuthService.instance.isLoggedIn) {
      throw AuthException('Favoriler için giriş yapmalısın.');
    }
    final wasFav = isFavorite(postId);
    _apply(postId, add: !wasFav);
    try {
      if (wasFav) {
        await FavRepository.instance.cikar(postId);
      } else {
        await FavRepository.instance.ekle(postId);
      }
    } catch (e) {
      _apply(postId, add: wasFav); // geri al
      rethrow;
    }
  }

  void _apply(int postId, {required bool add}) {
    final next = Set<int>.from(ids.value);
    if (add) {
      next.add(postId);
    } else {
      next.remove(postId);
    }
    ids.value = next;
  }
}
