<?php
/**
 * Mesafe alanları testi (MESAFE-MOBIL.md §8). Üsküdar konumuyla uçları çağırır,
 * gelen mesafe alanlarını listeler.
 *
 *   $env:GEZGAH_APP_KEY = '<X-App-Key>'   # lib/data/app_secrets.dart
 *   php tool/api_mesafe_test.php
 *
 * Not: `/mekanlar/{id}` her çağrıda tiklama sayacını +1 arttırır.
 */

const BASE = 'https://api.gezgah.com/rest';
const LAT = 41.0255;
const LNG = 29.0153;

$appKey = getenv('GEZGAH_APP_KEY') ?: '';

function req(string $path, array $q = [], ?string $token = null, ?array $body = null): array
{
    global $appKey;
    $h = ['Accept: application/json', 'Content-Type: application/json'];
    if ($appKey !== '') { $h[] = 'X-App-Key: ' . $appKey; }
    if ($token) { $h[] = 'Authorization: Bearer ' . $token; }
    $c = curl_init(BASE . $path . ($q ? '?' . http_build_query($q) : ''));
    curl_setopt_array($c, [CURLOPT_HTTPHEADER => $h, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 25]);
    if ($body !== null) {
        curl_setopt($c, CURLOPT_POST, true);
        curl_setopt($c, CURLOPT_POSTFIELDS, json_encode($body));
    }
    $raw = curl_exec($c);
    $code = curl_getinfo($c, CURLINFO_RESPONSE_CODE);
    curl_close($c);
    return [$code, json_decode((string) $raw, true)];
}

/** Bir kayıttaki mesafe ile ilgili alanları döker. */
function dist(array $r): string
{
    $out = [];
    foreach ($r as $k => $v) {
        if (preg_match('/mesafe|kus_ucusu|distance/i', (string) $k)) { $out[] = "$k=" . json_encode($v); }
    }
    return $out ? implode(' ', $out) : '(mesafe alanı yok)';
}

function show(string $label, array $res, callable $pick): void
{
    [$code, $j] = $res;
    echo "\n== $label  HTTP $code\n";
    $rows = $pick($j);
    if (!$rows) { echo "  (kayıt yok)\n"; return; }
    foreach (array_slice($rows, 0, 3) as $r) {
        $name = $r['name'] ?? $r['ad'] ?? $r['urun'] ?? $r['baslik'] ?? '?';
        echo '  #' . ($r['id'] ?? $r['urun_id'] ?? '?') . " $name | " . dist($r);
        if (isset($r['mekan']) && is_array($r['mekan'])) { echo ' | mekan: ' . dist($r['mekan']); }
        echo "\n";
    }
}

[, $j] = req('/cihaz/kayit', [], null, ['token' => bin2hex(random_bytes(32)), 'platform' => 'other', 'app_version' => 'php-test']);
$t = $j['data']['token'] ?? null;
$ll = ['lat' => LAT, 'lng' => LNG];
$list = function ($j) { $d = $j['data'] ?? []; return is_array($d) && array_is_list_($d) ? $d : ($d['mekanlar'] ?? $d['items'] ?? []); };
function array_is_list_(array $a): bool { return $a === [] || array_keys($a) === range(0, count($a) - 1); }

show('detay 4740 (konumlu)', req('/mekanlar/4740', $ll, $t), function ($j) { return isset($j['data']) ? [$j['data']] : []; });
show('detay 1231 (konumlu)', req('/mekanlar/1231', $ll, $t), function ($j) { return isset($j['data']) ? [$j['data']] : []; });
show('detay 4740 (konumsuz)', req('/mekanlar/4740', [], $t), function ($j) { return isset($j['data']) ? [$j['data']] : []; });
show('yakindakiler (konumlu)', req('/mekanlar/yakindakiler', $ll + ['limit' => 5], $t), $list);
show('yakindakiler (konumsuz)', req('/mekanlar/yakindakiler', ['limit' => 5], $t), $list);
show('arama mekan poseidon', req('/arama', $ll + ['q' => 'poseidon', 'tab' => 'mekan'], $t), $list);
show('arama yemek kebap', req('/arama', $ll + ['q' => 'kebap', 'tab' => 'yemek', 'limit' => 3], $t), $list);
show('mekanlar type=plaj (konumlu)', req('/mekanlar', $ll + ['type' => 'plaj', 'limit' => 3], $t), $list);
[, $kj] = req('/kategoriler', [], $t);
$kid = $kj['data'][0]['id'] ?? null;
if ($kid) {
    show("kategoriler/$kid (konumlu)", req("/kategoriler/$kid", $ll + ['limit' => 3], $t), function ($j) {
        $d = $j['data'] ?? []; return $d['mekanlar'] ?? (array_is_list_((array) $d) ? $d : []);
    });
}
show('harita (konumlu)', req('/harita', $ll, $t), $list);
show('rotalar kesfet (konumlu)', req('/rotalar', $ll + ['limit' => 3], $t), $list);
