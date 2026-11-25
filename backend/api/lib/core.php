<?php
declare(strict_types=1);
require_once __DIR__ . '/../config.php';
date_default_timezone_set(APP_TIMEZONE);

class ApiException extends Exception {
    public array $extra;
    public function __construct(string $message, int $code = 400, array $extra = []) {
        parent::__construct($message, $code);
        $this->extra = $extra;
    }
}

/* ---------------- Database ---------------- */
function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = 'mysql:host=' . DB_HOST . ';port=' . DB_PORT . ';dbname=' . DB_NAME . ';charset=utf8mb4';
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        $pdo->exec("SET time_zone = '" . DB_TIMEZONE_OFFSET . "'");
        ensure_schema($pdo);
    }
    return $pdo;
}
function ensure_schema(PDO $pdo): void {
    static $checked = false;
    if ($checked) return;
    $checked = true;
    try {
        $col = $pdo->query("SHOW COLUMNS FROM orders LIKE 'offered_driver_id'")->fetch();
        if (!$col) {
            $pdo->exec("ALTER TABLE orders ADD COLUMN offered_driver_id INT UNSIGNED NULL AFTER driver_id, ADD COLUMN offered_at DATETIME NULL AFTER offered_driver_id");
        }
    } catch (Throwable $e) {
        // abaikan jika kolom sudah ada
    }
}
function q(string $sql, array $params = []): PDOStatement {
    $st = db()->prepare($sql);
    $st->execute($params);
    return $st;
}
function row(string $sql, array $params = []): ?array {
    $r = q($sql, $params)->fetch();
    return $r === false ? null : $r;
}
function rows(string $sql, array $params = []): array { return q($sql, $params)->fetchAll(); }
function scalar(string $sql, array $params = []) {
    $r = q($sql, $params)->fetch(PDO::FETCH_NUM);
    return $r === false ? null : $r[0];
}
function insert_id(): int { return (int) db()->lastInsertId(); }

/* ---------------- Request / Response ---------------- */
function input(): array {
    static $data = null;
    if ($data === null) {
        $data = $_POST;
        $raw = file_get_contents('php://input');
        if ($raw !== '' && $raw !== false) {
            $json = json_decode($raw, true);
            if (is_array($json)) $data = array_merge($data, $json);
        }
        foreach ($_GET as $k => $v) if (!isset($data[$k])) $data[$k] = $v;
    }
    return $data;
}
function in(string $key, $default = null) {
    $d = input();
    return array_key_exists($key, $d) && $d[$key] !== '' ? $d[$key] : $default;
}
function need(string ...$keys): array {
    $out = [];
    foreach ($keys as $k) {
        $v = in($k);
        if ($v === null || (is_string($v) && trim($v) === '')) throw new ApiException("Field '$k' wajib diisi", 422);
        $out[$k] = is_string($v) ? trim($v) : $v;
    }
    return $out;
}
function json_out($data, int $code = 200): void {
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
    exit;
}
function ok(array $data = [], string $message = 'OK'): void {
    json_out(['success' => true, 'message' => $message, 'data' => (object) $data]);
}

/* ---------------- Auth ---------------- */
function bearer_token(): ?string {
    $h = $_SERVER['HTTP_X_AUTH_TOKEN'] ?? '';
    if ($h === '') {
        $a = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
        if (stripos($a, 'Bearer ') === 0) $h = substr($a, 7);
    }
    if ($h === '' && isset($_GET['token'])) $h = (string) $_GET['token'];
    return $h !== '' ? $h : null;
}
function current_user(bool $required = true): ?array {
    static $user = false;
    if ($user === false) {
        $user = null;
        $t = bearer_token();
        if ($t !== null) {
            $user = row("SELECT * FROM users WHERE api_token = ? AND token_expires_at > NOW() AND status <> 'deleted'", [hash('sha256', $t)]);
        }
    }
    if ($required && $user === null) throw new ApiException('Sesi berakhir, silakan login kembali', 401);
    return $user;
}
function require_role(string ...$roles): array {
    $u = current_user();
    if (!in_array($u['role'], $roles, true)) throw new ApiException('Anda tidak memiliki akses ke fitur ini', 403);
    if ($u['status'] === 'blocked' && $u['role'] !== 'driver') throw new ApiException('Akun Anda diblokir', 403);
    return $u;
}
function issue_token(int $userId): string {
    $token = bin2hex(random_bytes(32));
    q("UPDATE users SET api_token = ?, token_expires_at = DATE_ADD(NOW(), INTERVAL " . TOKEN_TTL_DAYS . " DAY), last_login_at = NOW() WHERE id = ?",
        [hash('sha256', $token), $userId]);
    return $token;
}

/* ---------------- Helpers ---------------- */
function setting(string $key, string $default = ''): string {
    $v = scalar('SELECT setting_value FROM system_settings WHERE setting_key = ?', [$key]);
    return $v === null ? $default : (string) $v;
}
function tariff(): array {
    $t = row('SELECT id, base_fare, per_km_rate FROM tariff_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1');
    return $t ?: ['id' => 0, 'base_fare' => 3000, 'per_km_rate' => 2500];
}
function calc_fare(float $km, array $t): int {
    // Total Tarif = Tarif Dasar + (Jarak x Tarif per Km), dibulatkan ke Rp100 terdekat
    $raw = (int) $t['base_fare'] + $km * (int) $t['per_km_rate'];
    return (int) (round($raw / 100) * 100);
}
function haversine_km(float $lat1, float $lng1, float $lat2, float $lng2): float {
    $r = 6371.0;
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;
    return $r * 2 * atan2(sqrt($a), sqrt(1 - $a));
}
function notify(int $userId, string $title, string $body, string $type = 'info', ?int $orderId = null): void {
    q('INSERT INTO notifications (user_id, title, body, type, order_id) VALUES (?,?,?,?,?)', [$userId, $title, $body, $type, $orderId]);
}
function admin_log(?int $adminId, string $action, ?string $targetType = null, ?int $targetId = null, ?string $details = null): void {
    q('INSERT INTO admin_logs (admin_id, action, target_type, target_id, details) VALUES (?,?,?,?,?)',
        [$adminId, $action, $targetType, $targetId, $details]);
}
function order_history(int $orderId, string $status, ?string $note = null, ?int $actorId = null): void {
    q('INSERT INTO order_status_history (order_id, status, note, actor_id) VALUES (?,?,?,?)', [$orderId, $status, $note, $actorId]);
}
function make_order_code(): string {
    do {
        $code = 'GP' . date('ymd') . strtoupper(substr(bin2hex(random_bytes(3)), 0, 5));
    } while (scalar('SELECT 1 FROM orders WHERE order_code = ?', [$code]));
    return $code;
}
function status_label(string $s, string $paymentStatus = 'pending'): string {
    if ($s === 'completed' && $paymentStatus === 'pending') {
        return 'Menunggu Konfirmasi Pembayaran';
    }
    return [
        'waiting' => 'Menunggu', 'accepted' => 'Diterima', 'heading_pickup' => 'Menuju Penjemputan',
        'picked_up' => 'Dijemput', 'in_trip' => 'Dalam Perjalanan', 'completed' => 'Selesai',
        'cancelled_customer' => 'Dibatalkan Customer', 'cancelled_driver' => 'Dibatalkan Driver',
        'no_driver' => 'Tidak Mendapat Driver',
    ][$s] ?? $s;
}
function save_upload(string $field, string $subdir, array $allowedExt = ['jpg', 'jpeg', 'png', 'pdf']): ?array {
    if (!isset($_FILES[$field]) || $_FILES[$field]['error'] === UPLOAD_ERR_NO_FILE) return null;
    $f = $_FILES[$field];
    if ($f['error'] !== UPLOAD_ERR_OK) throw new ApiException("Upload '$field' gagal (kode {$f['error']})", 422);
    if ($f['size'] > MAX_UPLOAD_BYTES) throw new ApiException('Ukuran file maksimal 5 MB', 422);
    $ext = strtolower(pathinfo($f['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, $allowedExt, true)) throw new ApiException('Format file harus ' . implode('/', $allowedExt), 422);
    $dir = __DIR__ . '/../uploads/' . $subdir;
    if (!is_dir($dir)) mkdir($dir, 0775, true);
    $name = bin2hex(random_bytes(12)) . '.' . $ext;
    if (!move_uploaded_file($f['tmp_name'], $dir . '/' . $name)) throw new ApiException('Gagal menyimpan file', 500);
    return ['path' => $subdir . '/' . $name, 'original' => $f['name']];
}

/* ---------------- Serializers ---------------- */
function driver_info(int $userId): ?array {
    $d = row("SELECT dp.verification_status, dp.rejection_reason, dp.is_online, dp.is_busy, dp.penalty_points,
                     dp.rating_avg, dp.rating_count, dp.last_online_at, dp.qris_url,
                     v.brand_model, v.plate_number, v.color
              FROM driver_profiles dp
              LEFT JOIN vehicles v ON v.driver_id = dp.user_id
              WHERE dp.user_id = ? LIMIT 1", [$userId]);
    if (!$d) return null;
    $d['is_online'] = (bool) $d['is_online'];
    $d['is_busy'] = (bool) $d['is_busy'];
    $d['penalty_points'] = (int) $d['penalty_points'];
    $d['rating_avg'] = (float) $d['rating_avg'];
    $d['rating_count'] = (int) $d['rating_count'];
    $d['qris_url'] = $d['qris_url'] ?? null;
    $d['penalty_threshold'] = (int) setting('penalty_block_threshold', '3');
    return $d;
}
function user_public(array $u): array {
    $out = [
        'id' => (int) $u['id'], 'role' => $u['role'], 'name' => $u['name'], 'npm' => $u['npm'],
        'email' => $u['email'], 'phone' => $u['phone'], 'avatar_url' => $u['avatar_url'] ?? null, 'status' => $u['status'],
        'blocked_reason' => $u['blocked_reason'], 'created_at' => $u['created_at'],
    ];
    if ($u['role'] === 'driver') $out['driver'] = driver_info((int) $u['id']);
    return $out;
}

const ACTIVE_STATUSES = "'waiting','accepted','heading_pickup','picked_up','in_trip'";

function order_full(int $id): ?array {
    $o = row("SELECT o.*, c.name AS customer_name, c.phone AS customer_phone, c.avatar_url AS customer_avatar_url,
                     d.name AS driver_name, d.phone AS driver_phone, d.avatar_url AS driver_avatar_url,
                     p.status AS payment_status, p.paid_at,
                     (SELECT COUNT(*) FROM ratings r WHERE r.order_id = o.id) AS rated,
                     (SELECT r.rating FROM ratings r WHERE r.order_id = o.id) AS rating_value
              FROM orders o
              JOIN users c ON c.id = o.customer_id
              LEFT JOIN users d ON d.id = o.driver_id
              LEFT JOIN payments p ON p.order_id = o.id
              WHERE o.id = ?", [$id]);
    if (!$o) return null;
    return shape_order($o);
}
function shape_order(array $o): array {
    foreach (['id', 'customer_id', 'driver_id', 'duration_min', 'base_fare', 'per_km_rate', 'total_fare'] as $k)
        if (isset($o[$k])) $o[$k] = (int) $o[$k];
    foreach (['pickup_lat', 'pickup_lng', 'dest_lat', 'dest_lng', 'distance_km'] as $k) $o[$k] = (float) $o[$k];
    $o['payment_status'] = $o['payment_status'] ?? 'pending';
    $o['status_label'] = status_label($o['status'], $o['payment_status']);
    $o['rated'] = !empty($o['rated']);
    $o['customer_avatar_url'] = $o['customer_avatar_url'] ?? null;
    $o['driver'] = null;
    if (!empty($o['driver_id'])) {
        $di = driver_info($o['driver_id']);
        $loc = row('SELECT lat, lng, heading, updated_at FROM driver_locations WHERE driver_id = ?', [$o['driver_id']]);
        $o['driver'] = [
            'id' => $o['driver_id'], 'name' => $o['driver_name'], 'phone' => $o['driver_phone'],
            'avatar_url' => $o['driver_avatar_url'] ?? null,
            'qris_url' => $di ? ($di['qris_url'] ?? null) : null,
            'vehicle' => $di ? trim(($di['brand_model'] ?? '') . ' ' . ($di['color'] ?? '')) : null,
            'plate_number' => $di['plate_number'] ?? null,
            'rating_avg' => $di['rating_avg'] ?? 0, 'rating_count' => $di['rating_count'] ?? 0,
            'location' => $loc ? ['lat' => (float) $loc['lat'], 'lng' => (float) $loc['lng'],
                                  'heading' => $loc['heading'] !== null ? (float) $loc['heading'] : null,
                                  'updated_at' => $loc['updated_at']] : null,
        ];
    }
    return $o;
}

/** Sinkronisasi flag is_busy driver agar selalu akurat dengan pesanan yang belum selesai/belum dibayar. */
function sync_driver_busy_flags(): void {
    q("UPDATE driver_profiles dp
       SET dp.is_busy = CASE
           WHEN EXISTS (
               SELECT 1 FROM orders o
               LEFT JOIN payments p ON p.order_id = o.id
               WHERE o.driver_id = dp.user_id
                 AND (o.status IN ('accepted','heading_pickup','picked_up','in_trip')
                      OR (o.status = 'completed' AND COALESCE(p.status, 'pending') = 'pending'))
           ) THEN 1
           ELSE 0
       END");
}

/**
 * Distribusi pesanan waiting secara ACAK (Random Single-Driver Dispatch) & Anti-Penumpukan:
 * - Setiap pesanan waiting hanya ditawarkan ke 1 driver online yang sedang bebas (tidak punya order aktif & tidak sedang ditawari order lain).
 * - Jika ada banyak pesanan & banyak driver online, masing-masing pesanan dibagi merata secara acak (1 driver = maks 1 tawaran/pesanan).
 */
function assign_waiting_orders(): void {
    sync_driver_busy_flags();

    // 1. Lepaskan offered_driver_id jika driver tersebut tidak lagi memenuhi syarat (offline, sibuk, diblokir, atau sudah menolak)
    q("UPDATE orders o
       LEFT JOIN driver_profiles dp ON dp.user_id = o.offered_driver_id
       LEFT JOIN users u ON u.id = o.offered_driver_id
       SET o.offered_driver_id = NULL, o.offered_at = NULL
       WHERE o.status = 'waiting'
         AND o.offered_driver_id IS NOT NULL
         AND (
             dp.user_id IS NULL
             OR dp.is_online = 0
             OR dp.is_busy = 1
             OR dp.verification_status <> 'approved'
             OR u.status <> 'active'
             OR EXISTS (
                 SELECT 1 FROM order_rejections r
                 WHERE r.order_id = o.id AND r.driver_id = o.offered_driver_id
             )
         )");

    // 2. Pastikan 1 driver tidak pernah memegang lebih dari 1 waiting order sekaligus (anti-penumpukan)
    $dups = rows("SELECT offered_driver_id, MIN(id) AS keep_id
                  FROM orders
                  WHERE status = 'waiting' AND offered_driver_id IS NOT NULL
                  GROUP BY offered_driver_id
                  HAVING COUNT(*) > 1");
    foreach ($dups as $d) {
        q("UPDATE orders SET offered_driver_id = NULL, offered_at = NULL
           WHERE status = 'waiting' AND offered_driver_id = ? AND id <> ?",
           [$d['offered_driver_id'], $d['keep_id']]);
    }

    // 3. Distribusikan setiap pesanan waiting yang belum punya offered_driver_id ke 1 driver online bebas secara ACAK
    $unassigned = rows("SELECT id, pickup_address, dest_address
                        FROM orders
                        WHERE status = 'waiting'
                          AND driver_id IS NULL
                          AND offered_driver_id IS NULL
                          AND (search_expires_at IS NULL OR search_expires_at > NOW())
                        ORDER BY id ASC");

    foreach ($unassigned as $ord) {
        $oid = (int) $ord['id'];
        $cand = row("SELECT dp.user_id
                     FROM driver_profiles dp
                     JOIN users u ON u.id = dp.user_id
                     WHERE dp.is_online = 1
                       AND dp.is_busy = 0
                       AND dp.verification_status = 'approved'
                       AND u.status = 'active'
                       AND NOT EXISTS (
                           SELECT 1 FROM orders o2
                           LEFT JOIN payments p2 ON p2.order_id = o2.id
                           WHERE (
                               (o2.driver_id = dp.user_id AND (
                                   o2.status IN ('accepted','heading_pickup','picked_up','in_trip')
                                   OR (o2.status = 'completed' AND COALESCE(p2.status, 'pending') = 'pending')
                               ))
                               OR (o2.status = 'waiting' AND o2.offered_driver_id = dp.user_id)
                           )
                       )
                       AND NOT EXISTS (
                           SELECT 1 FROM order_rejections r
                           WHERE r.order_id = ? AND r.driver_id = dp.user_id
                       )
                     ORDER BY RAND()
                     LIMIT 1", [$oid]);

        if ($cand) {
            $targetDriverId = (int) $cand['user_id'];
            $n = q("UPDATE orders SET offered_driver_id = ?, offered_at = NOW()
                    WHERE id = ? AND status = 'waiting' AND offered_driver_id IS NULL",
                    [$targetDriverId, $oid])->rowCount();
            if ($n > 0) {
                notify($targetDriverId, 'Pesanan baru!', $ord['pickup_address'] . ' → ' . $ord['dest_address'], 'new_order', $oid);
            }
        }
    }
}

/** Tandai pesanan yang melewati batas waktu pencarian sebagai "Tidak Mendapat Driver". */
function expire_stale_orders(): void {
    $stale = rows("SELECT id, customer_id FROM orders WHERE status = 'waiting' AND search_expires_at IS NOT NULL AND search_expires_at < NOW()");
    foreach ($stale as $s) {
        $n = q("UPDATE orders SET status = 'no_driver', offered_driver_id = NULL, offered_at = NULL WHERE id = ? AND status = 'waiting'", [$s['id']])->rowCount();
        if ($n) {
            order_history((int) $s['id'], 'no_driver', 'Tidak ada driver yang menerima pesanan');
            notify((int) $s['customer_id'], 'Driver tidak ditemukan', 'Belum ada driver yang menerima pesanan Anda. Silakan coba lagi.', 'order', (int) $s['id']);
        }
    }
    assign_waiting_orders();
}

