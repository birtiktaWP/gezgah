<?php
/**
 * Mekan videoları API testi (MEKAN_VIDEO.md).
 *
 * Uygulamanın yaptığı gibi cihaz token'ı alır, mekanı arar, `GET /mekanlar/{id}`
 * yanıtındaki `videolar[]` alanını ve video dosyalarına erişimi kontrol eder.
 *
 * Kullanım (PowerShell):
 *   $env:GEZGAH_APP_KEY = '<X-App-Key>'      # lib/data/app_secrets.dart
 *   php tool/api_video_test.php "beyaz bahçe"   # ya da mekan id'si: 1234
 *
 * Not: `/mekanlar/{id}` sunucuda tiklama sayacını +1 arttırır.
 */

const BASE = 'https://api.gezgah.com/rest';

$appKey = getenv('GEZGAH_APP_KEY') ?: '';
$secret = getenv('GEZGAH_SIGNING_SECRET') ?: ''; // sunucuda imza kapalıysa boş
$arg    = $argv[1] ?? 'beyaz bahçe';

function req(string $method, string $path, ?array $body = null, ?string $token = null, array $q = []): array
{
    global $appKey, $secret;
    $json = $body === null ? '' : json_encode($body, JSON_UNESCAPED_UNICODE);
    $h = ['Accept: application/json', 'Content-Type: application/json'];
    if ($appKey !== '') { $h[] = 'X-App-Key: ' . $appKey; }
    if ($token)         { $h[] = 'Authorization: Bearer ' . $token; }
    if ($secret !== '') { // api.dart _SecurityInterceptor ile aynı imza
        $ts = (string) time();
        $nonce = bin2hex(random_bytes(16));
        $base = strtoupper($method) . "\n$path\n$ts\n$nonce\n" . hash('sha256', $json);
        $h[] = "X-Timestamp: $ts";
        $h[] = "X-Nonce: $nonce";
        $h[] = 'X-Signature: ' . hash_hmac('sha256', $base, $secret);
    }
    $url = BASE . $path . ($q ? '?' . http_build_query($q) : '');
    $c = curl_init($url);
    curl_setopt_array($c, [
        CURLOPT_CUSTOMREQUEST  => $method,
        CURLOPT_HTTPHEADER     => $h,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 20,
    ]);
    if ($body !== null) { curl_setopt($c, CURLOPT_POSTFIELDS, $json); }
    $raw  = curl_exec($c);
    $code = curl_getinfo($c, CURLINFO_RESPONSE_CODE);
    $err  = curl_error($c);
    curl_close($c);
    return [$code, json_decode((string) $raw, true), $err ?: null, (string) $raw];
}

/** Video dosyasına uygulamanın yaptığı gibi Range isteği atar. */
function probe(string $url): string
{
    $c = curl_init($url);
    curl_setopt_array($c, [
        CURLOPT_RANGE          => '0-1023',
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HEADER         => true,
        CURLOPT_NOBODY         => false,
        CURLOPT_TIMEOUT        => 20,
        CURLOPT_FOLLOWLOCATION => false,
    ]);
    $raw = (string) curl_exec($c);
    $code = curl_getinfo($c, CURLINFO_RESPONSE_CODE);
    $type = curl_getinfo($c, CURLINFO_CONTENT_TYPE);
    $hsz  = curl_getinfo($c, CURLINFO_HEADER_SIZE);
    curl_close($c);
    $head = substr($raw, 0, $hsz);
    preg_match('/^content-range:\s*(.+)$/im', $head, $cr);
    preg_match('/^accept-ranges:\s*(.+)$/im', $head, $ar);
    preg_match('/^location:\s*(.+)$/im', $head, $loc);
    $body = substr($raw, $hsz, 12);
    $sig = strpos($body, 'ftyp') !== false ? 'mp4/mov(ftyp)' : (substr($body, 0, 4) === "\x1A\x45\xDF\xA3" ? 'webm(EBML)' : 'imza yok');
    return sprintf('HTTP %d | %s | range: %s | accept-ranges: %s | %s%s',
        $code, $type ?: '-', trim($cr[1] ?? '-'), trim($ar[1] ?? '-'), $sig,
        isset($loc[1]) ? ' | yönlendirme: ' . trim($loc[1]) : '');
}

// 1) Cihaz token'ı (device_service.dart → POST /cihaz/kayit)
$local = bin2hex(random_bytes(32));
[$code, $j] = req('POST', '/cihaz/kayit', ['token' => $local, 'platform' => 'other', 'app_version' => 'php-test']);
$token = $j['data']['token'] ?? $local;
echo "cihaz/kayit: HTTP $code, success=" . json_encode($j['success'] ?? null) . "\n";

// 2) Mekan id'si
if (ctype_digit($arg)) {
    $id = (int) $arg;
} else {
    [$code, $j, $err, $raw] = req('GET', '/arama', null, $token, ['q' => $arg, 'tab' => 'mekan', 'limit' => 10]);
    echo "arama '$arg': HTTP $code\n";
    $list = $j['data'] ?? [];
    if (!is_array($list) || !$list) { echo "Sonuç yok. Yanıt: " . substr($raw, 0, 400) . "\n"; exit(1); }
    foreach ($list as $r) {
        $m = $r['mekan'] ?? $r;
        printf("  #%d  %s\n", $m['id'] ?? 0, $m['name'] ?? $m['baslik'] ?? $m['title'] ?? '?');
    }
    $first = $list[0]['mekan'] ?? $list[0];
    $id = (int) ($first['id'] ?? 0);
}
echo "\nmekan id: $id\n";

// 3) Detay
[$code, $j, $err, $raw] = req('GET', "/mekanlar/$id", null, $token);
echo "GET /mekanlar/$id: HTTP $code" . ($err ? " ($err)" : '') . "\n";
$d = $j['data'] ?? null;
if (!is_array($d)) { echo "data yok. Yanıt: " . substr($raw, 0, 400) . "\n"; exit(1); }
echo 'ad: ' . ($d['name'] ?? $d['baslik'] ?? '?') . "\n";

if (!array_key_exists('videolar', $d)) {
    echo "\n[SORUN] Yanıtta 'videolar' alanı YOK → backend show() içine eklenmemiş ya da eski önbellek dönüyor.\n";
    echo 'Mevcut alanlar: ' . implode(', ', array_keys($d)) . "\n";
} elseif (!is_array($d['videolar'])) {
    echo "\n[SORUN] 'videolar' dizi değil: " . json_encode($d['videolar']) . "\n";
} elseif (!$d['videolar']) {
    echo "\n[SORUN] 'videolar' boş dizi → meta okunmuyor (post_id / meta_key / regex kontrol edilmeli).\n";
} else {
    echo "\nvideolar: " . count($d['videolar']) . " adet\n";
    foreach ($d['videolar'] as $i => $v) {
        echo "\n[$i] " . json_encode($v, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT) . "\n";
        $url = (string) ($v['url'] ?? '');
        if ($url === '') { echo "  [SORUN] url boş → uygulama bu videoyu atar\n"; continue; }
        if (strpos($url, 'http') !== 0) { echo "  [UYARI] url mutlak değil, uygulama api.gezgah.com ile tamamlar\n"; }
        echo '  video : ' . probe($url) . "\n";
        if (!empty($v['poster'])) { echo '  poster: ' . probe((string) $v['poster']) . "\n"; }
    }
}

// Eski yol: galeri içinde video/* öğeler
$gv = array_filter($d['galeri'] ?? [], function ($g) {
    return is_array($g) && stripos((string) ($g['mime_type'] ?? ''), 'video/') === 0;
});
echo "\ngaleri içindeki video öğeleri: " . count($gv) . "\n";
foreach ($gv as $g) {
    echo json_encode($g, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n";
    $u = (string) ($g['url'] ?? $g['image'] ?? '');
    if ($u !== '') {
        if (strpos($u, 'http') !== 0) { $u = 'https://api.gezgah.com' . $u; }
        echo '  video : ' . probe($u) . "\n";
    }
}
