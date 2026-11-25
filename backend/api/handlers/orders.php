<?php
// Handler: pemesanan, distribusi pesanan, alur driver, pembayaran tunai, rating, penalti

/* ======================= CUSTOMER ======================= */

function h_quote(): void {
    require_role('customer');
    $km = (float) need('distance_km')['distance_km'];
    if ($km <= 0) throw new ApiException('Jarak tidak valid', 422);
    $t = tariff();
    ok(['base_fare' => (int) $t['base_fare'], 'per_km_rate' => (int) $t['per_km_rate'], 'total_fare' => calc_fare($km, $t)]);
}

function h_nearby_drivers(): void {
    require_role('customer');
    sync_driver_busy_flags();
    $list = rows("SELECT u.id, u.name,
                         COALESCE(dl.lat, -5.358214) AS lat,
                         COALESCE(dl.lng, 105.233129) AS lng,
                         dp.rating_avg, v.brand_model, v.plate_number
                  FROM driver_profiles dp
                  JOIN users u ON u.id = dp.user_id AND u.status = 'active'
                  LEFT JOIN driver_locations dl ON dl.driver_id = dp.user_id
                  LEFT JOIN vehicles v ON v.driver_id = dp.user_id
                  WHERE dp.is_online = 1 AND dp.is_busy = 0 AND dp.verification_status = 'approved'");
    ok(['drivers' => array_map(fn($r) => [
        'id' => (int) $r['id'], 'name' => $r['name'], 'lat' => (float) $r['lat'], 'lng' => (float) $r['lng'],
        'rating_avg' => (float) $r['rating_avg'], 'vehicle' => $r['brand_model'], 'plate_number' => $r['plate_number'],
    ], $list)]);
}

function h_order_create(): void {
    $u = require_role('customer');
    $d = need('pickup_address', 'pickup_lat', 'pickup_lng', 'dest_address', 'dest_lat', 'dest_lng', 'distance_km');
    $km = round((float) $d['distance_km'], 2);
    if ($km <= 0 || $km > MAX_TRIP_KM) throw new ApiException('Jarak perjalanan harus antara 0 dan ' . MAX_TRIP_KM . ' km', 422);
    $line = haversine_km((float) $d['pickup_lat'], (float) $d['pickup_lng'], (float) $d['dest_lat'], (float) $d['dest_lng']);
    if ($line < 0.05) throw new ApiException('Lokasi penjemputan dan tujuan terlalu dekat', 422);
    if ($km < $line * 0.9) $km = round($line, 2); // jarak rute tidak mungkin lebih pendek dari garis lurus

    expire_stale_orders();
    $existing = scalar("SELECT o.id FROM orders o LEFT JOIN payments p ON p.order_id = o.id
                        WHERE o.customer_id = ? AND (o.status IN (" . ACTIVE_STATUSES . ")
                           OR (o.status = 'completed' AND p.status = 'pending'))
                        LIMIT 1", [$u['id']]);
    if ($existing) throw new ApiException('Anda masih memiliki pesanan yang sedang berlangsung', 409, ['order_id' => (int) $existing]);

    $t = tariff();
    $fare = calc_fare($km, $t);
    $timeout = (int) setting('order_search_timeout_sec', '120');
    $method = in('payment_method', 'cash');
    if (!in_array($method, ['cash', 'qris'], true)) $method = 'cash';

    q("INSERT INTO orders (order_code, customer_id, pickup_address, pickup_lat, pickup_lng, dest_address, dest_lat, dest_lng,
                           distance_km, duration_min, base_fare, per_km_rate, total_fare, payment_method, status, search_expires_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'waiting', DATE_ADD(NOW(), INTERVAL ? SECOND))",
        [make_order_code(), $u['id'], mb_substr($d['pickup_address'], 0, 250), $d['pickup_lat'], $d['pickup_lng'],
         mb_substr($d['dest_address'], 0, 250), $d['dest_lat'], $d['dest_lng'], $km, (int) in('duration_min', 0),
         $t['base_fare'], $t['per_km_rate'], $fare, $method, $timeout]);
    $id = insert_id();
    q('INSERT INTO payments (order_id, amount, method, status) VALUES (?,?,?,?)', [$id, $fare, $method, 'pending']);
    order_history($id, 'waiting', 'Pesanan dibuat, mencari driver', (int) $u['id']);

    // Distribusikan pesanan secara ACAK ke 1 driver online yang sedang bebas (tidak menumpuk)
    assign_waiting_orders();

    ok(['order' => order_full($id)], 'Pesanan dibuat, sedang mencari driver');
}

function h_order_cancel_customer(array $p): void {
    $u = require_role('customer');
    $id = (int) $p['id'];
    $n = q("UPDATE orders SET status = 'cancelled_customer', cancel_reason = ? WHERE id = ? AND customer_id = ? AND status = 'waiting'",
        [in('reason', 'Dibatalkan oleh customer'), $id, $u['id']])->rowCount();
    if (!$n) throw new ApiException('Pesanan tidak dapat dibatalkan karena sudah diterima driver', 409);
    order_history($id, 'cancelled_customer', (string) in('reason', 'Dibatalkan oleh customer'), (int) $u['id']);
    ok(['order' => order_full($id)], 'Pesanan dibatalkan');
}

function h_order_rate(array $p): void {
    $u = require_role('customer');
    $id = (int) $p['id'];
    $rating = (int) need('rating')['rating'];
    if ($rating < 1 || $rating > 5) throw new ApiException('Rating harus 1-5', 422);
    $o = row('SELECT * FROM orders WHERE id = ? AND customer_id = ?', [$id, $u['id']]);
    if (!$o) throw new ApiException('Pesanan tidak ditemukan', 404);
    if ($o['status'] !== 'completed') throw new ApiException('Rating hanya dapat diberikan setelah perjalanan selesai', 409);
    if (scalar('SELECT 1 FROM ratings WHERE order_id = ?', [$id])) throw new ApiException('Pesanan ini sudah dinilai', 409);
    q('INSERT INTO ratings (order_id, customer_id, driver_id, rating, comment) VALUES (?,?,?,?,?)',
        [$id, $u['id'], $o['driver_id'], $rating, in('comment') ? mb_substr((string) in('comment'), 0, 500) : null]);
    q('UPDATE driver_profiles SET rating_avg = (SELECT ROUND(AVG(rating), 2) FROM ratings WHERE driver_id = ?),
                                  rating_count = (SELECT COUNT(*) FROM ratings WHERE driver_id = ?) WHERE user_id = ?',
        [$o['driver_id'], $o['driver_id'], $o['driver_id']]);
    notify((int) $o['driver_id'], 'Rating baru', "Anda mendapat $rating bintang dari {$u['name']}.", 'rating', $id);
    ok(['order' => order_full($id)], 'Terima kasih atas penilaian Anda');
}

/* ======================= SHARED ======================= */

function h_order_active(): void {
    $u = require_role('customer', 'driver');
    expire_stale_orders();
    if ($u['role'] === 'customer') {
        $id = scalar("SELECT o.id FROM orders o LEFT JOIN payments p ON p.order_id = o.id
                      WHERE o.customer_id = ? AND (o.status IN ('waiting','accepted','heading_pickup','picked_up','in_trip')
                         OR (o.status = 'completed' AND p.status = 'pending'))
                      ORDER BY o.id DESC LIMIT 1", [$u['id']]);
    } else {
        $id = scalar("SELECT o.id FROM orders o LEFT JOIN payments p ON p.order_id = o.id
                      WHERE o.driver_id = ? AND (o.status IN ('accepted','heading_pickup','picked_up','in_trip')
                         OR (o.status = 'completed' AND p.status = 'pending'))
                      ORDER BY o.id DESC LIMIT 1", [$u['id']]);
    }
    ok(['order' => $id ? order_full((int) $id) : null]);
}

function h_order_get(array $p): void {
    $u = current_user();
    expire_stale_orders();
    $o = order_full((int) $p['id']);
    if (!$o) throw new ApiException('Pesanan tidak ditemukan', 404);
    $isAdmin = in_array($u['role'], ['admin', 'super_admin'], true);
    if (!$isAdmin && $o['customer_id'] !== (int) $u['id'] && $o['driver_id'] !== (int) $u['id']) throw new ApiException('Tidak memiliki akses', 403);
    $o['history'] = rows('SELECT status, note, created_at FROM order_status_history WHERE order_id = ? ORDER BY id', [$o['id']]);
    ok(['order' => $o]);
}

function h_orders_history(): void {
    $u = require_role('customer', 'driver');
    $col = $u['role'] === 'customer' ? 'customer_id' : 'driver_id';
    $ids = rows("SELECT id FROM orders WHERE $col = ? ORDER BY id DESC LIMIT 100", [$u['id']]);
    ok(['orders' => array_map(fn($r) => order_full((int) $r['id']), $ids)]);
}

/* ======================= DRIVER ======================= */

function driver_gate(array $u): array {
    $dp = row('SELECT * FROM driver_profiles WHERE user_id = ?', [$u['id']]);
    if (!$dp) throw new ApiException('Profil driver tidak ditemukan', 404);
    return $dp;
}

function h_driver_status(): void {
    $u = require_role('driver');
    sync_driver_busy_flags();
    $dp = driver_gate($u);
    $online = filter_var(in('online', false), FILTER_VALIDATE_BOOLEAN);
    if ($online) {
        if ($u['status'] === 'blocked') throw new ApiException('Akun Anda diblokir' . ($u['blocked_reason'] ? ': ' . $u['blocked_reason'] : '') . '. Hubungi admin.', 403);
        if ($dp['verification_status'] === 'pending') throw new ApiException('Akun Anda belum diverifikasi admin', 403);
        if ($dp['verification_status'] === 'rejected') throw new ApiException('Pendaftaran ditolak: ' . $dp['rejection_reason'], 403);
        $lat = in('lat') !== null ? (float) in('lat') : -5.358214;
        $lng = in('lng') !== null ? (float) in('lng') : 105.233129;
        q('INSERT INTO driver_locations (driver_id, lat, lng) VALUES (?,?,?) ON DUPLICATE KEY UPDATE lat = VALUES(lat), lng = VALUES(lng)',
            [$u['id'], $lat, $lng]);
        q('UPDATE driver_profiles SET is_online = 1, last_online_at = NOW() WHERE user_id = ?', [$u['id']]);
        assign_waiting_orders();
    } else {
        $hasActive = scalar("SELECT o.id FROM orders o LEFT JOIN payments p ON p.order_id = o.id
                             WHERE o.driver_id = ? AND (o.status IN ('accepted','heading_pickup','picked_up','in_trip')
                                OR (o.status = 'completed' AND COALESCE(p.status, 'pending') = 'pending'))
                             LIMIT 1", [$u['id']]);
        if ((int) $dp['is_busy'] === 1 || $hasActive) throw new ApiException('Selesaikan pesanan aktif sebelum offline', 409);
        q('UPDATE driver_profiles SET is_online = 0, last_online_at = NOW() WHERE user_id = ?', [$u['id']]);
        // Jika ada pesanan waiting yang sedang ditawarkan ke driver ini, langsung alihkan ke driver online lain
        q("UPDATE orders SET offered_driver_id = NULL, offered_at = NULL WHERE status = 'waiting' AND offered_driver_id = ?", [$u['id']]);
        assign_waiting_orders();
    }
    ok(['user' => user_public(row('SELECT * FROM users WHERE id = ?', [$u['id']]))], $online ? 'Anda sekarang online' : 'Anda sekarang offline');
}

function h_driver_location(): void {
    $u = require_role('driver');
    $d = need('lat', 'lng');
    q('INSERT INTO driver_locations (driver_id, lat, lng, heading) VALUES (?,?,?,?)
       ON DUPLICATE KEY UPDATE lat = VALUES(lat), lng = VALUES(lng), heading = VALUES(heading)',
        [$u['id'], $d['lat'], $d['lng'], in('heading')]);
    q('UPDATE driver_profiles SET last_online_at = NOW() WHERE user_id = ? AND is_online = 1', [$u['id']]);
    ok([]);
}

function h_driver_incoming(): void {
    $u = require_role('driver');
    expire_stale_orders();
    $dp = driver_gate($u);
    if (!$dp['is_online'] || $dp['is_busy'] || $dp['verification_status'] !== 'approved' || $u['status'] !== 'active') ok(['orders' => []]);
    // Anti-penumpukan: jika masih ada pesanan aktif / belum dikonfirmasi pembayarannya, tidak boleh menerima pesanan masuk
    $hasActive = scalar("SELECT o.id FROM orders o LEFT JOIN payments p ON p.order_id = o.id
                         WHERE o.driver_id = ? AND (o.status IN ('accepted','heading_pickup','picked_up','in_trip')
                            OR (o.status = 'completed' AND COALESCE(p.status, 'pending') = 'pending'))
                         LIMIT 1", [$u['id']]);
    if ($hasActive) ok(['orders' => []]);

    $loc = row('SELECT lat, lng FROM driver_locations WHERE driver_id = ?', [$u['id']]);
    // Hanya tampilkan Maksimal 1 pesanan yang secara acak sedang ditawarkan khusus ke driver ini (offered_driver_id = ?)
    $list = rows("SELECT o.id, o.order_code, o.pickup_address, o.pickup_lat, o.pickup_lng, o.dest_address, o.dest_lat, o.dest_lng,
                         o.distance_km, o.duration_min, o.total_fare, o.payment_method, c.name AS customer_name,
                         GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), o.search_expires_at)) AS seconds_left
                  FROM orders o JOIN users c ON c.id = o.customer_id
                  WHERE o.status = 'waiting'
                    AND o.driver_id IS NULL
                    AND o.offered_driver_id = ?
                    AND (o.search_expires_at IS NULL OR o.search_expires_at > NOW())
                    AND NOT EXISTS (SELECT 1 FROM order_rejections r WHERE r.order_id = o.id AND r.driver_id = ?)
                  ORDER BY o.id ASC LIMIT 1", [$u['id'], $u['id']]);
    ok(['orders' => array_map(function ($o) use ($loc) {
        $o['id'] = (int) $o['id'];
        foreach (['pickup_lat', 'pickup_lng', 'dest_lat', 'dest_lng', 'distance_km'] as $k) $o[$k] = (float) $o[$k];
        $o['total_fare'] = (int) $o['total_fare'];
        $o['duration_min'] = (int) $o['duration_min'];
        $o['seconds_left'] = (int) $o['seconds_left'];
        $o['pickup_distance_km'] = $loc ? round(haversine_km((float) $loc['lat'], (float) $loc['lng'], $o['pickup_lat'], $o['pickup_lng']), 2) : null;
        return $o;
    }, $list)]);
}

/** Pengambilan pesanan atomik: hanya satu driver yang dapat memenangkan pesanan, dan tidak boleh menumpuk pesanan. */
function h_order_accept(array $p): void {
    $u = require_role('driver');
    $id = (int) $p['id'];
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $dp = row('SELECT * FROM driver_profiles WHERE user_id = ? FOR UPDATE', [$u['id']]);
        $fresh = row('SELECT status FROM users WHERE id = ?', [$u['id']]);
        if (!$dp || $dp['verification_status'] !== 'approved' || $fresh['status'] !== 'active') throw new ApiException('Akun driver tidak dapat menerima pesanan', 403);
        if (!$dp['is_online']) throw new ApiException('Aktifkan status online terlebih dahulu', 409);

        $hasActive = scalar("SELECT o.id FROM orders o LEFT JOIN payments p ON p.order_id = o.id
                             WHERE o.driver_id = ? AND (o.status IN ('accepted','heading_pickup','picked_up','in_trip')
                                OR (o.status = 'completed' AND COALESCE(p.status, 'pending') = 'pending'))
                             LIMIT 1", [$u['id']]);
        if ($dp['is_busy'] || $hasActive) throw new ApiException('Selesaikan pesanan aktif Anda terlebih dahulu sebelum mengambil pesanan baru', 409);

        $o = row('SELECT * FROM orders WHERE id = ? FOR UPDATE', [$id]);
        if (!$o) throw new ApiException('Pesanan tidak ditemukan', 404);
        if ($o['status'] !== 'waiting' || $o['driver_id'] !== null)
            throw new ApiException('Pesanan sudah diambil driver lain', 409, ['code' => 'ORDER_TAKEN']);
        if ($o['offered_driver_id'] !== null && (int) $o['offered_driver_id'] !== (int) $u['id'])
            throw new ApiException('Pesanan sudah dialihkan ke driver lain', 409, ['code' => 'ORDER_TAKEN']);
        if ($o['search_expires_at'] !== null && strtotime($o['search_expires_at']) < time())
            throw new ApiException('Pesanan sudah kedaluwarsa', 409, ['code' => 'ORDER_EXPIRED']);

        $n = q("UPDATE orders SET driver_id = ?, offered_driver_id = NULL, offered_at = NULL, status = 'accepted', accepted_at = NOW() WHERE id = ? AND status = 'waiting' AND driver_id IS NULL", [$u['id'], $id])->rowCount();
        if ($n !== 1) throw new ApiException('Pesanan sudah diambil driver lain', 409, ['code' => 'ORDER_TAKEN']);
        q('UPDATE driver_profiles SET is_busy = 1 WHERE user_id = ?', [$u['id']]);
        // Lepaskan pesanan waiting lain jika ada yang mengarah ke driver ini
        q("UPDATE orders SET offered_driver_id = NULL, offered_at = NULL WHERE status = 'waiting' AND offered_driver_id = ?", [$u['id']]);
        order_history($id, 'accepted', 'Diterima oleh ' . $u['name'], (int) $u['id']);
        notify((int) $o['customer_id'], 'Driver ditemukan!', $u['name'] . ' menerima pesanan Anda dan segera menjemput.', 'order', $id);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    assign_waiting_orders();
    ok(['order' => order_full($id)], 'Pesanan berhasil diambil');
}

function h_order_reject(array $p): void {
    $u = require_role('driver');
    $id = (int) $p['id'];
    $uid = (int) $u['id'];
    q("INSERT IGNORE INTO order_rejections (order_id, driver_id, reason) VALUES (?,?, 'rejected')", [$id, $uid]);

    // Lepaskan pesanan dari driver ini & perpanjang durasi pencarian untuk driver berikutnya
    $timeout = (int) setting('order_search_timeout_sec', '120');
    q("UPDATE orders
       SET offered_driver_id = NULL,
           offered_at = NULL,
           search_expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND)
       WHERE id = ? AND status = 'waiting' AND (offered_driver_id = ? OR offered_driver_id IS NULL)",
       [$timeout, $id, $uid]);

    // Periksa apakah masih ada driver online bebas lain yang belum pernah menolak pesanan ini
    $hasOtherUnrejected = scalar("SELECT dp.user_id
        FROM driver_profiles dp
        JOIN users usr ON usr.id = dp.user_id
        WHERE dp.is_online = 1 AND dp.is_busy = 0 AND dp.verification_status = 'approved' AND usr.status = 'active'
          AND dp.user_id <> ?
          AND NOT EXISTS (
              SELECT 1 FROM orders o2 LEFT JOIN payments p2 ON p2.order_id = o2.id
              WHERE (o2.driver_id = dp.user_id AND (o2.status IN ('accepted','heading_pickup','picked_up','in_trip') OR (o2.status = 'completed' AND COALESCE(p2.status, 'pending') = 'pending')))
                 OR (o2.status = 'waiting' AND o2.offered_driver_id = dp.user_id)
          )
          AND NOT EXISTS (SELECT 1 FROM order_rejections r WHERE r.order_id = ? AND r.driver_id = dp.user_id)
        LIMIT 1", [$uid, $id]);

    if (!$hasOtherUnrejected) {
        // Jika semua driver online lain yang bebas sudah pernah menolak sebelumnya,
        // bersihkan riwayat penolakan driver lain (kecuali driver yang baru saja menolak)
        // agar pesanan tetap terlempar ke driver online lain yang sedang aktif.
        $hasAnyOtherFree = scalar("SELECT dp.user_id
            FROM driver_profiles dp
            JOIN users usr ON usr.id = dp.user_id
            WHERE dp.is_online = 1 AND dp.is_busy = 0 AND dp.verification_status = 'approved' AND usr.status = 'active'
              AND dp.user_id <> ?
              AND NOT EXISTS (
                  SELECT 1 FROM orders o2 LEFT JOIN payments p2 ON p2.order_id = o2.id
                  WHERE (o2.driver_id = dp.user_id AND (o2.status IN ('accepted','heading_pickup','picked_up','in_trip') OR (o2.status = 'completed' AND COALESCE(p2.status, 'pending') = 'pending')))
                     OR (o2.status = 'waiting' AND o2.offered_driver_id = dp.user_id)
              )
            LIMIT 1", [$uid]);
        if ($hasAnyOtherFree) {
            q("DELETE FROM order_rejections WHERE order_id = ? AND driver_id <> ?", [$id, $uid]);
        }
    }

    // Lempar otomatis secara acak ke driver online lain yang sedang bebas
    assign_waiting_orders();
    ok([], 'Pesanan ditolak dan dialihkan ke driver lain');
}

function own_driver_order(array $u, int $id): array {
    $o = row('SELECT * FROM orders WHERE id = ? AND driver_id = ?', [$id, $u['id']]);
    if (!$o) throw new ApiException('Pesanan tidak ditemukan', 404);
    return $o;
}

function h_order_advance(array $p): void {
    $u = require_role('driver');
    $id = (int) $p['id'];
    $action = (string) need('action')['action'];
    $o = own_driver_order($u, $id);
    $s = $o['status'];
    $cust = (int) $o['customer_id'];
    switch ($action) {
        case 'start_pickup':
            if ($s !== 'accepted') throw new ApiException('Status pesanan tidak sesuai', 409);
            q("UPDATE orders SET status = 'heading_pickup' WHERE id = ?", [$id]);
            order_history($id, 'heading_pickup', 'Driver menuju lokasi penjemputan', (int) $u['id']);
            notify($cust, 'Driver menuju lokasi Anda', 'Pantau posisi driver di peta.', 'order', $id);
            break;
        case 'picked_up':
            if (!in_array($s, ['accepted', 'heading_pickup'], true)) throw new ApiException('Status pesanan tidak sesuai', 409);
            q("UPDATE orders SET status = 'in_trip', picked_up_at = NOW() WHERE id = ?", [$id]);
            order_history($id, 'picked_up', 'Customer sudah dijemput', (int) $u['id']);
            order_history($id, 'in_trip', 'Perjalanan menuju tujuan', (int) $u['id']);
            notify($cust, 'Perjalanan dimulai', 'Anda dalam perjalanan menuju tujuan.', 'order', $id);
            break;
        case 'complete':
            if ($s !== 'in_trip') throw new ApiException('Perjalanan belum dimulai', 409);
            q("UPDATE orders SET status = 'completed', completed_at = NOW() WHERE id = ?", [$id]);
            order_history($id, 'completed', 'Tiba di tujuan, menunggu konfirmasi pembayaran', (int) $u['id']);
            $isQris = strtolower((string)($o['payment_method'] ?? 'cash')) === 'qris';
            $fareStr = number_format((int) $o['total_fare'], 0, ',', '.');
            $msg = $isQris
                ? "Tiba di tujuan. Silakan scan/bayar QRIS Rp $fareStr dan tunggu konfirmasi driver."
                : "Tiba di tujuan. Silakan bayar tunai Rp $fareStr dan tunggu konfirmasi driver.";
            notify($cust, 'Tiba di Tujuan', $msg, 'order', $id);
            break;
        default:
            throw new ApiException('Aksi tidak dikenal', 422);
    }
    ok(['order' => order_full($id)]);
}

function h_order_confirm_payment(array $p): void {
    $u = require_role('driver');
    $id = (int) $p['id'];
    $o = own_driver_order($u, $id);
    if ($o['status'] !== 'completed') throw new ApiException('Perjalanan belum selesai', 409);
    q("UPDATE payments SET status = 'paid', paid_at = NOW(), confirmed_by = ? WHERE order_id = ? AND status = 'pending'", [$u['id'], $id]);
    q('UPDATE driver_profiles SET is_busy = 0 WHERE user_id = ?', [$u['id']]);
    order_history($id, 'payment_confirmed', 'Pembayaran dikonfirmasi driver. Perjalanan selesai.', (int) $u['id']);
    notify((int) $o['customer_id'], 'Pembayaran Dikonfirmasi', 'Driver telah mengkonfirmasi pembayaran Anda. Perjalanan selesai! Silakan beri penilaian.', 'payment', $id);
    assign_waiting_orders();
    ok(['order' => order_full($id)], 'Pembayaran berhasil dikonfirmasi');
}

function h_order_driver_cancel(array $p): void {
    $u = require_role('driver');
    $id = (int) $p['id'];
    $d = need('category', 'reason');
    if (mb_strlen($d['reason']) < 5) throw new ApiException('Alasan pembatalan minimal 5 karakter', 422);
    $categories = ['emergency', 'technical', 'customer_unreachable', 'other'];
    if (!in_array($d['category'], $categories, true)) throw new ApiException('Kategori tidak valid', 422);

    $pdo = db();
    $pdo->beginTransaction();
    $blocked = false;
    $status = 'violation';
    $points = 0;
    try {
        $o = row('SELECT * FROM orders WHERE id = ? AND driver_id = ? FOR UPDATE', [$id, $u['id']]);
        if (!$o) throw new ApiException('Pesanan tidak ditemukan', 404);
        if (!in_array($o['status'], ['accepted', 'heading_pickup', 'picked_up', 'in_trip'], true)) throw new ApiException('Pesanan tidak dapat dibatalkan', 409);
        $beforePickup = in_array($o['status'], ['accepted', 'heading_pickup'], true);

        // Evaluasi alasan: darurat/teknis ditinjau admin (tanpa poin sementara), lainnya = pelanggaran
        if (in_array($d['category'], ['emergency', 'technical'], true)) {
            $status = 'pending_review';
        } else {
            $points = (int) setting('penalty_points_per_violation', '1');
        }
        q('INSERT INTO penalties (driver_id, order_id, reason_category, reason_text, points, status) VALUES (?,?,?,?,?,?)',
            [$u['id'], $id, $d['category'], $d['reason'], $points, $status]);
        q('UPDATE driver_profiles SET is_busy = 0 WHERE user_id = ?', [$u['id']]);
        q("INSERT IGNORE INTO order_rejections (order_id, driver_id, reason) VALUES (?,?, 'cancelled')", [$id, $u['id']]);

        if ($beforePickup) {
            // kembalikan ke pencarian driver dan lempar ke driver online lain secara acak
            $timeout = (int) setting('order_search_timeout_sec', '120');
            q("UPDATE orders SET status = 'waiting', driver_id = NULL, offered_driver_id = NULL, offered_at = NULL, accepted_at = NULL, search_expires_at = DATE_ADD(NOW(), INTERVAL ? SECOND) WHERE id = ?", [$timeout, $id]);
            order_history($id, 'cancelled_driver', 'Driver membatalkan: ' . $d['reason'], (int) $u['id']);
            order_history($id, 'waiting', 'Mencari driver pengganti', null);
            notify((int) $o['customer_id'], 'Driver membatalkan', 'Kami sedang mencarikan driver pengganti untuk Anda.', 'order', $id);
        } else {
            q("UPDATE orders SET status = 'cancelled_driver', cancel_reason = ? WHERE id = ?", [$d['reason'], $id]);
            order_history($id, 'cancelled_driver', 'Driver membatalkan: ' . $d['reason'], (int) $u['id']);
            notify((int) $o['customer_id'], 'Perjalanan dibatalkan driver', 'Mohon maaf, driver membatalkan perjalanan: ' . $d['reason'], 'order', $id);
        }

        if ($points > 0) {
            q('UPDATE driver_profiles SET penalty_points = penalty_points + ? WHERE user_id = ?', [$points, $u['id']]);
            $blocked = apply_auto_block((int) $u['id']);
        }
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    assign_waiting_orders();
    $msg = $status === 'pending_review'
        ? 'Pembatalan dicatat dan akan ditinjau admin (darurat/teknis).'
        : "Pembatalan dicatat sebagai pelanggaran (+$points poin)." . ($blocked ? ' Akun Anda diblokir karena batas pelanggaran tercapai.' : '');
    ok(['blocked' => $blocked, 'penalty_status' => $status, 'points' => $points], $msg);
}

/** Blokir otomatis jika poin mencapai ambang. */
function apply_auto_block(int $driverId): bool {
    $threshold = (int) setting('penalty_block_threshold', '3');
    $pts = (int) scalar('SELECT penalty_points FROM driver_profiles WHERE user_id = ?', [$driverId]);
    if ($pts >= $threshold) {
        q("UPDATE users SET status = 'blocked', blocked_reason = ? WHERE id = ? AND status = 'active'",
            ["Batas pelanggaran tercapai ($pts poin)", $driverId]);
        q('UPDATE driver_profiles SET is_online = 0 WHERE user_id = ?', [$driverId]);
        notify($driverId, 'Akun diblokir', "Akun Anda diblokir otomatis karena mencapai $pts poin pelanggaran.", 'penalty');
        admin_log(null, 'auto_block_driver', 'user', $driverId, "Poin pelanggaran: $pts");
        return true;
    }
    return false;
}

function h_driver_summary(): void {
    $u = require_role('driver');
    $uid = (int) $u['id'];
    $total = (int) scalar("SELECT COALESCE(SUM(p.amount),0) FROM payments p JOIN orders o ON o.id = p.order_id WHERE o.driver_id = ? AND p.status = 'paid'", [$uid]);
    $today = (int) scalar("SELECT COALESCE(SUM(p.amount),0) FROM payments p JOIN orders o ON o.id = p.order_id WHERE o.driver_id = ? AND p.status = 'paid' AND DATE(p.paid_at) = CURDATE()", [$uid]);
    $count = (int) scalar("SELECT COUNT(*) FROM orders o JOIN payments p ON p.order_id = o.id WHERE o.driver_id = ? AND o.status = 'completed' AND p.status = 'paid'", [$uid]);
    $todayCount = (int) scalar("SELECT COUNT(*) FROM orders o JOIN payments p ON p.order_id = o.id WHERE o.driver_id = ? AND o.status = 'completed' AND p.status = 'paid' AND DATE(p.paid_at) = CURDATE()", [$uid]);
    $penalties = rows('SELECT id, order_id, reason_category, reason_text, points, status, created_at FROM penalties WHERE driver_id = ? ORDER BY id DESC LIMIT 50', [$uid]);
    $recent = rows("SELECT o.id FROM orders o WHERE o.driver_id = ? AND o.status = 'completed' ORDER BY o.id DESC LIMIT 30", [$uid]);
    ok([
        'total_earnings' => $total, 'today_earnings' => $today, 'completed_orders' => $count, 'today_orders' => $todayCount,
        'penalties' => array_map(function ($p) { $p['id'] = (int) $p['id']; $p['points'] = (int) $p['points']; return $p; }, $penalties),
        'transactions' => array_map(fn($r) => order_full((int) $r['id']), $recent),
        'driver' => driver_info($uid),
    ]);
}
