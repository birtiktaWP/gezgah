import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'api.dart';

/// Mekan görüntülenme sayacı (GORUNTULENME.md).
///
/// Olay türleri (Gezgah Pro raporları, ISTATISTIK-OLAYLARI-MOBIL.md):
///  - `liste`: mekan kartı bir listede (kategori, tip, arama) ekranda en az
///    %50 görünür halde 1 sn kaldı (bkz. `TrackImpression` widget'ı).
///  - `detay`: mekan detay sayfası açıldı.
///  - `qr`: mekanın QR menüsü açıldı.
///  - `yol_tarifi`: mekan için yol tarifi başlatıldı.
///
/// Olaylar bellekte biriktirilir ve `POST /istatistik/goruntulenme` ile toplu
/// gönderilir: [_flushAt] olay birikince, [_flushEvery] aralıkla ve uygulama
/// arka plana geçerken. Gönderim hatası kullanıcıya yansımaz; ağ/5xx/429'da
/// olaylar kuyruğa geri konur, uç yayında değilse (404) oturum boyunca
/// gönderim kapatılır.
class ViewTracker with WidgetsBindingObserver {
  ViewTracker._();
  static final ViewTracker instance = ViewTracker._();

  static const String _path = '/istatistik/goruntulenme';
  static const Duration _flushEvery = Duration(seconds: 15);
  static const int _flushAt = 20;
  static const int _maxBatch = 100; // istek başına en fazla olay
  static const int _maxQueue = 500; // taşarsa en eski olaylar atılır

  /// Uygulama açılışı başına rastgele oturum kimliği (sunucuda tekilleştirme).
  final String session = _randomId();

  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _sending = false;
  bool _observing = false;
  bool _disabled = false;

  /// Listede görünme olayı. [kaynak] listenin türü (`kategori`, `tip`…),
  /// [kaynakId] o listenin kimliği (kategori id'si ya da tip adı), [sira]
  /// listedeki 0 tabanlı konum, [oneCikan] sabitlenmiş/öne çıkan kart.
  void liste(
    int mekanId, {
    required String kaynak,
    String? kaynakId,
    int? sira,
    bool oneCikan = false,
  }) {
    _add({
      'mekan_id': mekanId,
      'tip': 'liste',
      'kaynak': kaynak,
      if (kaynakId != null && kaynakId.isNotEmpty) 'kaynak_id': kaynakId,
      'sira': ?sira,
      if (oneCikan) 'one_cikan': true,
    });
  }

  /// Detay sayfası açılma olayı (Pro: Tıklanma).
  void detay(int mekanId) => _add({'mekan_id': mekanId, 'tip': 'detay'});

  /// QR menü açıldı (Pro: QR Tıklama, ISTATISTIK-OLAYLARI-MOBIL.md §2).
  void qr(int mekanId) => _add({'mekan_id': mekanId, 'tip': 'qr'});

  /// Yol tarifi başlatıldı (Pro: Yol Tarifi, ISTATISTIK-OLAYLARI-MOBIL.md §3).
  /// Harici harita uygulaması açılmadan **önce** çağrılmalı; Gezgah arka plana
  /// geçerken kuyruk gönderilir.
  void yolTarifi(int mekanId) =>
      _add({'mekan_id': mekanId, 'tip': 'yol_tarifi'});

  void _add(Map<String, dynamic> e) {
    if (_disabled || (e['mekan_id'] as int) <= 0) return;
    e['zaman'] = DateTime.now().toUtc().toIso8601String();
    _queue.add(e);
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }
    _ensureObserving();
    if (_queue.length >= _flushAt) {
      flush();
    } else {
      _timer ??= Timer(_flushEvery, flush);
    }
  }

  void _ensureObserving() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      flush();
    }
  }

  /// Kuyruktaki olayları gönderir. Aynı anda tek istek çalışır.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_sending || _disabled || _queue.isEmpty) return;
    _sending = true;
    final n = min(_queue.length, _maxBatch);
    final batch = _queue.sublist(0, n);
    _queue.removeRange(0, n);
    var retry = false;
    try {
      final res = await Api.instance.dio.post(
        _path,
        data: {'oturum': session, 'olaylar': batch},
      );
      final code = res.statusCode ?? 0;
      if (code == 404) {
        // Uç henüz yayında değil: oturum boyunca deneme.
        _disabled = true;
        _queue.clear();
      } else if (code == 429) {
        retry = true;
      }
      // Diğer 4xx: veri geçersiz sayılır, tekrar gönderilmez.
    } on DioException catch (e) {
      // Ağ hatası / 5xx: sonra yeniden dene.
      debugPrint('Görüntülenme gönderilemedi: ${e.type} ${e.message}');
      retry = true;
    } catch (e) {
      debugPrint('Görüntülenme gönderilemedi: $e');
    } finally {
      _sending = false;
    }
    if (retry) {
      _queue.insertAll(0, batch);
      if (_queue.length > _maxQueue) {
        _queue.removeRange(0, _queue.length - _maxQueue);
      }
      _timer ??= Timer(_flushEvery, flush);
    } else if (_queue.isNotEmpty) {
      _timer ??= Timer(
        _queue.length >= _flushAt ? Duration.zero : _flushEvery,
        flush,
      );
    }
  }

  @visibleForTesting
  List<Map<String, dynamic>> get queued => List.unmodifiable(_queue);

  static String _randomId() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

/// Bir liste ekranı ziyaretine ait görünme kapsamı: aynı ziyarette bir mekan
/// yalnız bir kez `liste` olayı üretir (aşağı-yukarı kaydırma sayılmaz).
/// Ekran her açıldığında yeni bir kapsam oluşturulmalıdır.
class ImpressionScope {
  ImpressionScope({required this.kaynak, this.kaynakId});

  final String kaynak;
  final String? kaynakId;
  final Set<int> _seen = {};

  bool hasSeen(int mekanId) => _seen.contains(mekanId);

  void seen(int mekanId, {int? sira, bool oneCikan = false}) {
    if (mekanId <= 0 || !_seen.add(mekanId)) return;
    ViewTracker.instance.liste(
      mekanId,
      kaynak: kaynak,
      kaynakId: kaynakId,
      sira: sira,
      oneCikan: oneCikan,
    );
  }
}
