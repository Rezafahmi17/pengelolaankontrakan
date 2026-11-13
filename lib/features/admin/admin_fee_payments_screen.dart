import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

class AdminFeePaymentsScreen extends StatefulWidget {
  const AdminFeePaymentsScreen({super.key});

  @override
  State<AdminFeePaymentsScreen> createState() => _AdminFeePaymentsScreenState();
}

class _AdminFeePaymentsScreenState extends State<AdminFeePaymentsScreen> {
  final _key = GlobalKey<AsyncPageState>();
  String _filter = 'pending';

  void _showEnlargedProof(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    Api.resolveUrl(url),
                    height: 340,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Gagal memuat gambar', style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verify(BuildContext context, int id, bool approve) async {
    String? note;
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tolak Pembayaran Setoran', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Berikan alasan penolakan agar driver dapat memperbaikinya:', style: TextStyle(fontSize: 13, color: AppColors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alasan Penolakan',
                  hintText: 'Misal: Bukti buram, nominal tidak sesuai, dsb.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Tolak Setoran'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      note = ctrl.text.trim();
    } else {
      final ok = await confirm(
        context,
        'Setujui Pembayaran Setoran?',
        'Pastikan dana sudah masuk ke rekening/QRIS Super Admin.',
        confirmText: 'Ya, Setujui',
        cancelText: 'Batal',
      );
      if (!ok) return;
    }

    try {
      await Api.post('admin/fee-payments/$id/verify', body: {
        'action': approve ? 'approve' : 'reject',
        if (note != null && note.isNotEmpty) 'admin_note': note,
      });
      if (mounted) {
        showMsg(context, approve ? 'Pembayaran setoran berhasil disetujui!' : 'Pembayaran setoran telah ditolak.');
        _key.currentState?.reload();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openSettings(BuildContext context, Map summary) async {
    final feeCtrl = TextEditingController(text: '${summary['withdrawal_fee'] ?? 1000}');
    File? newQris;
    String currentQris = summary['admin_qris_url'] ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Text('Pengaturan Biaya & QRIS Super Admin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    const Text(
                      '1. Biaya Potongan Aplikasi per Transaksi Driver:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Setiap driver menyelesaikan 1 pesanan, kewajiban setoran akan bertambah sejumlah biaya ini.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: feeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Biaya per Trip Selesai (Rp)',
                        prefixText: 'Rp ',
                        prefixIcon: Icon(Icons.payments_rounded, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '2. Barcode QRIS Resmi Super Admin:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'QRIS ini akan ditampilkan kepada semua driver saat mereka membayar setoran ke Super Admin.',
                      style: TextStyle(color: AppColors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.greyLight),
                        ),
                        child: Column(
                          children: [
                            if (newQris != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Foto Baru Dipilih (Belum Disimpan)',
                                  style: TextStyle(color: AppColors.warning, fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(6),
                                  child: Image.file(newQris!, width: 170, height: 170, fit: BoxFit.contain),
                                ),
                              ),
                            ] else if (currentQris.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                    SizedBox(width: 4),
                                    Text(
                                      'Barcode QRIS Aktif di Sistem',
                                      style: TextStyle(color: AppColors.success, fontSize: 11.5, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(6),
                                  child: Image.network(
                                    Api.resolveUrl(currentQris),
                                    width: 170,
                                    height: 170,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(
                                        width: 170,
                                        height: 170,
                                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Column(
                                        children: [
                                          Icon(Icons.broken_image_rounded, size: 48, color: AppColors.danger),
                                          SizedBox(height: 4),
                                          Text('Gagal memuat gambar', style: TextStyle(color: AppColors.danger, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.qr_code_2_rounded, size: 64, color: AppColors.grey),
                                    SizedBox(height: 6),
                                    Text('Belum ada QRIS Super Admin', style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
                                if (f != null) {
                                  setS(() => newQris = File(f.path));
                                }
                              },
                              icon: const Icon(Icons.photo_library_rounded, size: 18),
                              label: Text(newQris != null || currentQris.isNotEmpty ? 'Ganti Foto QRIS' : 'Pilih Foto QRIS'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final fee = int.tryParse(feeCtrl.text.trim()) ?? 1000;
                        try {
                          if (newQris != null) {
                            await Api.multipart('admin/qris', fields: {'withdrawal_fee': '$fee'}, files: {'qris': newQris!.path});
                          } else {
                            await Api.post('admin/settings', body: {'key': 'withdrawal_fee', 'value': '$fee'});
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            showMsg(context, 'Pengaturan QRIS & Biaya berhasil diperbarui!');
                            _key.currentState?.reload();
                          }
                        } catch (e) {
                          if (ctx.mounted) showError(ctx, e);
                        }
                      },
                      child: const Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Setoran Driver (QRIS)'),
      ),
      body: AsyncPage(
        key: _key,
        load: () => Api.get('admin/fee-payments', query: {'status': _filter}),
        builder: (context, data) {
          final summary = (data['summary'] as Map? ?? {});
          final collected = summary['total_collected'] as num? ?? 0;
          final pendingCnt = summary['pending_count'] as num? ?? 0;
          final pendingAmt = summary['pending_amount'] as num? ?? 0;
          final fee = summary['withdrawal_fee'] as num? ?? 1000;
          final paymentsRaw = (data['payments'] as List? ?? []);
          final payments = paymentsRaw.map((e) => DriverFeePayment.fromJson(Map<String, dynamic>.from(e))).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Setoran Diterima', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        InkWell(
                          onTap: () => _openSettings(context, summary),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.settings_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Kelola QRIS & Fee', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.rupiah(collected),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Menunggu Verifikasi', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('$pendingCnt transaksi (${Fmt.rupiah(pendingAmt)})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Biaya per Penarikan', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text(Fmt.rupiah(fee), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in const [
                      ('pending', 'Menunggu Verifikasi'),
                      ('approved', 'Disetujui'),
                      ('rejected', 'Ditolak'),
                      ('all', 'Semua Data'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.$2),
                          selected: _filter == f.$1,
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _filter == f.$1 ? AppColors.primaryDark : AppColors.grey,
                          ),
                          onSelected: (_) {
                            setState(() => _filter = f.$1);
                            _key.currentState?.reload();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (payments.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.grey),
                          const SizedBox(height: 10),
                          Text('Tidak ada setoran dalam kategori ini', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                for (final p in payments)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Avatar(
                                (p.driverName ?? '?').split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase(),
                                size: 44,
                                bg: AppColors.primaryLight,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.driverName ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p.driverNpm != null ? "NPM: ${p.driverNpm} • " : ""}${p.driverPhone ?? ""}',
                                      style: const TextStyle(color: AppColors.grey, fontSize: 12),
                                    ),
                                    if (p.brandModel != null || p.plateNumber != null)
                                      Text(
                                        '${p.brandModel ?? ""} • ${p.plateNumber ?? ""}',
                                        style: const TextStyle(color: AppColors.grey, fontSize: 11.5),
                                      ),
                                  ],
                                ),
                              ),
                              StatusChip(p.statusLabel, p.statusColor),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Nominal Pembayaran Setoran', style: TextStyle(color: AppColors.grey, fontSize: 11.5)),
                                  Text(Fmt.rupiah(p.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryDark)),
                                ],
                              ),
                              Text(Fmt.dateTime(p.createdAt), style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                            ],
                          ),
                          if (p.notes != null && p.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                              child: Text('Catatan Driver: ${p.notes}', style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                          if (p.adminNote != null && p.adminNote!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: p.status == 'rejected' ? AppColors.danger.withValues(alpha: 0.1) : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Catatan Super Admin: ${p.adminNote}', style: TextStyle(fontSize: 12, color: p.status == 'rejected' ? AppColors.danger : AppColors.grey)),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (p.proofImage != null && p.proofImage!.isNotEmpty)
                            InkWell(
                              onTap: () => _showEnlargedProof(context, p.proofImage!, 'Bukti Transfer: ${p.driverName}'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.greyLight),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        Api.resolveUrl(p.proofImage!),
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.receipt_rounded, color: AppColors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Foto Bukti Pembayaran / Transfer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                          Text('Ketuk untuk melihat foto ukuran penuh', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.zoom_in_rounded, color: AppColors.primary, size: 22),
                                  ],
                                ),
                              ),
                            ),
                          if (p.isPending) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                      side: const BorderSide(color: AppColors.danger),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _verify(context, p.id, false),
                                    child: const Text('Tolak Setoran', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _verify(context, p.id, true),
                                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                                    label: const Text('Setujui & Verifikasi', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

