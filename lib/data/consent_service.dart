import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'legal_texts.dart';
import 'models.dart';

/// Sözleşme onayı takibi — her üye ilk girişinden sonra zorunlu sözleşmeleri
/// onaylamak zorundadır (SOZLESMELER.md).
///
/// Onaylanacak metinler `GET /sozlesmeler?tip=zorunlu` ile gelir. Her `slug`
/// için onaylanan `surum` yerelde saklanır; sunucudaki sürüm değişirse o metin
/// yeniden onaya sunulur. Sunucuya erişilemezse uygulamaya gömülü liste
/// ([kOnayGerekenSozlesmeler]) kullanılır.
///
/// Not: Onay kaydı şu an **yalnız cihazda** tutulur; sunucu tarafında onay
/// saklayan bir uç henüz yok (bkz. SOZLESMELER.md → "Onay takibi").
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  /// Yerel kayıt şeması sürümü (şema değişirse artır).
  static const int _schema = 2;

  static String _key(int uyeId) => 'consent_v${_schema}_$uyeId';

  /// Aktif üyenin onay durumu. `true` = onay tamam / gerekmiyor.
  final ValueNotifier<bool> accepted = ValueNotifier<bool>(true);

  int? _uyeId;

  /// Onaya sunulacak metinler (sunucudan; erişilemezse gömülü yedek).
  List<Sozlesme> pending = const [];

  /// Üye oturumu geldiğinde/değiştiğinde çağrılır: zorunlu metinleri çeker ve
  /// kayıtlı onaylarla karşılaştırır.
  Future<void> load(int? uyeId) async {
    _uyeId = uyeId;
    if (uyeId == null || uyeId <= 0) {
      pending = const [];
      accepted.value = true; // giriş yok → kapı gösterilmez
      return;
    }

    final zorunlu = await _zorunluMetinler();
    Map<String, String> saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = _decode(prefs.getString(_key(uyeId)));
    } catch (_) {
      // Yerel depolama okunamazsa kullanıcıyı kilitlemek yerine geç.
      pending = const [];
      accepted.value = true;
      return;
    }

    // Onaylanmamış ya da sürümü değişmiş metinler yeniden sunulur.
    pending = zorunlu
        .where((s) => saved[s.slug] != (s.surum.isEmpty ? 'v1' : s.surum))
        .toList();
    accepted.value = pending.isEmpty;
  }

  /// Zorunlu metinler: sunucudan; erişilemezse gömülü başlık listesinden üretir.
  Future<List<Sozlesme>> _zorunluMetinler() async {
    final list = await SozlesmeRepository.instance.liste(tip: 'zorunlu');
    if (list.isNotEmpty) return list;
    // Yedek: uçlar yayında değilse gömülü metinler onaya sunulur.
    return [
      for (final t in kOnayGerekenSozlesmeler)
        Sozlesme(slug: 'local:$t', baslik: t, surum: 'v1'),
    ];
  }

  /// Verilen metinlerin onayını kaydeder (slug → sürüm).
  Future<void> accept(List<Sozlesme> onaylananlar) async {
    final id = _uyeId;
    pending = const [];
    accepted.value = true;
    if (id == null || id <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = _decode(prefs.getString(_key(id)));
      for (final s in onaylananlar) {
        saved[s.slug] = s.surum.isEmpty ? 'v1' : s.surum;
      }
      await prefs.setString(_key(id), jsonEncode(saved));
    } catch (_) {
      // yut: kayıt yazılamazsa bir sonraki açılışta yeniden sorulur
    }
  }

  /// Çıkış yapıldığında durumu sıfırla (kapı gösterilmesin).
  void clear() {
    _uyeId = null;
    pending = const [];
    accepted.value = true;
  }

  Map<String, String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      };
    } catch (_) {
      return {};
    }
  }
}
