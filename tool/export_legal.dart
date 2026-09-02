// Sözleşme metinlerini ana dizine ayrı .txt dosyaları olarak çıkarır.
// Kullanım: dart run tool/export_legal.dart
//
// Amaç: metinleri web API'ye (veya panele) taşımak. Çıktı UTF-8'dir ve
// paragraflardaki `**...**` (kalın) işaretleri korunur — uygulama bu işareti
// render ettiği için biçim bilgisi kaybolmasın.
import 'dart:io';

import 'package:gezgah/data/legal_texts.dart';

/// Dosya adı için sade slug (Türkçe karakterler sadeleştirilir).
String slug(String s) {
  const map = {
    'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i',
    'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u',
  };
  var out = s;
  map.forEach((k, v) => out = out.replaceAll(k, v));
  out = out.toLowerCase();
  out = out.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return out.replaceAll(RegExp(r'^-+|-+$'), '');
}

void main() {
  // Çıktı proje ana dizinine yazılır.
  final dir = Directory('.');

  final index = <String>[];
  kLegalTexts.forEach((title, sections) {
    final b = StringBuffer()
      ..writeln(title)
      ..writeln('=' * title.length)
      ..writeln();
    for (final s in sections) {
      final h = s.heading;
      if (h != null && h.isNotEmpty) {
        b
          ..writeln(h)
          ..writeln();
      }
      for (final p in s.paragraphs) {
        b
          ..writeln(p)
          ..writeln();
      }
    }
    final name = 'sozlesme-${slug(title)}.txt';
    File('${dir.path}/$name').writeAsStringSync(b.toString());
    index.add('$name  ←  $title (${sections.length} bölüm)');
    stdout.writeln('yazıldı: $name');
  });

  stdout.writeln('\nToplam ${kLegalTexts.length} metin.');
  stdout.writeln(index.join('\n'));
}
