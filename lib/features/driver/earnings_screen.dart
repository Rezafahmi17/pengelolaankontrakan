import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/order_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => EarningsScreenState();
}

class EarningsScreenState extends State<EarningsScreen> {
  final _key = GlobalKey<AsyncPageState>();
  final _feeKey = GlobalKey<_DriverFeePaymentSectionState>();

  void reload() {
    _key.currentState?.reload();
    _feeKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendapatan & Penalti'),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang Data',
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AsyncPage(
        key: _key,
        load: () async {
          _feeKey.currentState?.reload();
          return Api.get('driver/summary');
        },
        builder: (context, data) {
          final total = data['total_earnings'] as num? ?? 0;
          final today = data['today_earnings'] as num? ?? 0;
          final completed = data['completed_orders'] as num? ?? 0;
          final todayCompleted = data['today_orders'] as num? ?? 0;
          final penalties = (data['penalties'] as List? ?? []).cast<Map>();
          final txs = (data['transactions'] as List? ?? []).map((e) => Order.fromJson(e)).toList();
          final driver = data['driver'] as Map?;
          final points = driver?['penalty_points'] as num? ?? 0;
          final threshold = driver?['penalty_threshold'] as num? ?? 3;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total Pendapatan Tunai',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(Fmt.rupiah(total),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text(Fmt.rupiah(today),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Trip Selesai Hari Ini', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('$todayCompleted trip',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // Grid Stat
              Row(children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.check_circle_rounded,
                    label: 'Total Trip Selesai',
                    value: '$completed',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Poin Pelanggaran',
                    value: '$points / $threshold',
                    color: points > 0 ? AppColors.danger : AppColors.grey,
                  ),
                ),
              ]),
              if (points > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Peringatan: Akun Anda akan diblokir otomatis jika mencapai $threshold poin pelanggaran akibat pembatalan.',
                        style: const TextStyle(color: AppColors.danger, fontSize: 12.5, height: 1.3),
                      ),
                    ),
                  ]),
                ),
              ],
              if (penalties.isNotEmpty) ...[
                const SectionTitle('Riwayat penalti & pelanggaran'),
                Card(
                  child: Column(children: [
                    for (final p in penalties)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                          child: const Icon(Icons.warning_rounded, color: AppColors.danger, size: 20),
                        ),
                        title: Text('${p['reason_text']}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text('${Fmt.dateTime(p['created_at'])}\nStatus: ${p['status'] == 'pending_review' ? 'Menunggu Review Admin' : (p['status'] == 'dismissed' ? 'Dibatalkan (Bebas)' : 'Pelanggaran')}'),
                        isThreeLine: true,
                        trailing: Text(
                          '+${p['points']} poin',
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ]),
                ),
              ],
              const SectionTitle('Setoran Biaya Aplikasi (QRIS Admin)'),
              _DriverFeePaymentSection(
                key: _feeKey,
                completedOrdersFallback: completed.toInt(),
                onChanged: () => _key.currentState?.reload(),
              ),
              SectionTitle('Riwayat transaksi lunas',
                  trailing: Text('${txs.length} transaksi',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12.5))),
              if (txs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Belum ada transaksi perjalanan selesai',
                          style: TextStyle(color: AppColors.grey)),
                    ),
                  ),
                )
              else
                for (final o in txs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OrderTile(order: o, perspective: 'driver'),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _DriverFeePaymentSection extends StatefulWidget {
  final VoidCallback onChanged;
  final int completedOrdersFallback;
  const _DriverFeePaymentSection({
    super.key,
    required this.onChanged,
    this.completedOrdersFallback = 0,
  });

  @override
  State<_DriverFeePaymentSection> createState() => _DriverFeePaymentSectionState();
}

class _DriverFeePaymentSectionState extends State<_DriverFeePaymentSection> {
  final _key = GlobalKey<AsyncPageState>();

  void reload() {
    _key.currentState?.reload();
  }

  void _openPaySheet(BuildContext context, Map data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PayFeeSheet(
        data: data,
        onSuccess: () {
          _key.currentState?.reload();
          widget.onChanged();
        },
      ),
    );
  }

  void _showEnlargedProof(BuildContext context, String url) {
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
                  const Expanded(
                    child: Text('Bukti Pembayaran Setoran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                    height: 320,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Gagal memuat bukti pembayaran', style: TextStyle(color: AppColors.danger)),
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

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      key: _key,
      load: () => Api.get('driver/fee-payments'),
      builder: (context, data) {
        final paymentsRaw = (data['payments'] as List? ?? []);
        final payments = paymentsRaw.map((e) => DriverFeePayment.fromJson(Map<String, dynamic>.from(e))).toList();

        // Hitung fallback dari list pembayaran jika key lama/baru berbeda
        int calcApproved = 0;
        int calcPending = 0;
        for (final p in payments) {
          if (p.status == 'approved') calcApproved += p.amount;
          if (p.status == 'pending') calcPending += p.amount;
        }

        final num feePerTrip = (data['fee_per_trip'] ?? data['fee_per_order'] ?? 1000) as num;
        final int rawTrips = ((data['completed_trips'] ?? data['completed_orders'] ?? 0) as num).toInt();
        final int completedTrips = rawTrips > 0 ? rawTrips : widget.completedOrdersFallback;
        final int totalObligation = ((data['total_fee_obligation'] ?? (completedTrips * feePerTrip)) as num).toInt();
        final int rawPaid = ((data['total_fee_paid'] ?? data['total_paid'] ?? 0) as num).toInt();
        final int totalPaid = rawPaid > 0 ? rawPaid : calcApproved;
        final int rawPending = ((data['total_fee_pending'] ?? data['total_pending'] ?? 0) as num).toInt();
        final int totalPending = rawPending > 0 ? rawPending : calcPending;

        final int unpaidFee = (totalObligation - totalPaid) > 0 ? (totalObligation - totalPaid) : 0;
        final int overpaidFee = (totalPaid - totalObligation) > 0 ? (totalPaid - totalObligation) : 0;
        final bool isWaitingVerification = unpaidFee > 0 && totalPending > 0;
        final Color statusColor = unpaidFee > 0
            ? (isWaitingVerification ? AppColors.warning : AppColors.danger)
            : AppColors.success;
        final String statusTitle = unpaidFee > 0
            ? (isWaitingVerification
                ? 'Menunggu Verifikasi Super Admin'
                : 'Sisa Setoran yang Harus Dibayar')
            : (totalPaid > 0
                ? 'Status Kewajiban Setoran (Disetujui)'
                : 'Status Kewajiban Setoran');
        final String statusValue = unpaidFee > 0
            ? (isWaitingVerification
                ? '${Fmt.rupiah(totalPending)} sedang diverifikasi'
                : Fmt.rupiah(unpaidFee))
            : (totalPaid > 0
                ? (overpaidFee > 0
                    ? 'Lunas • Saldo Setoran +${Fmt.rupiah(overpaidFee)}'
                    : 'Lunas (${Fmt.rupiah(totalPaid)} Disetujui)')
                : 'Lunas (Tidak ada tunggakan)');
        final IconData statusIcon = unpaidFee > 0
            ? (isWaitingVerification ? Icons.hourglass_top_rounded : Icons.error_outline_rounded)
            : Icons.check_circle_rounded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Biaya Setoran ke Super Admin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              Text(
                                '${Fmt.rupiah(feePerTrip)} / transaksi selesai (ditetapkan Admin)',
                                style: const TextStyle(color: AppColors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Trip', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                                Text('$completedTrips trip', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                const SizedBox(height: 4),
                                const Text('Kewajiban', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                                Text(Fmt.rupiah(totalObligation), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sudah Disetujui', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                                Text(Fmt.rupiah(totalPaid), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.success)),
                                const SizedBox(height: 4),
                                const Text('Menunggu Verifikasi', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                                Text(Fmt.rupiah(totalPending), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.warning)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  statusValue,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            statusIcon,
                            color: statusColor,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _openPaySheet(context, data),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text('Bayar Setoran via QRIS Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Riwayat Pembayaran Setoran ke Admin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              for (final p in payments)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.proofImage != null && p.proofImage!.isNotEmpty)
                          GestureDetector(
                            onTap: () => _showEnlargedProof(context, p.proofImage!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(
                                    Api.resolveUrl(p.proofImage!),
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 54,
                                      height: 54,
                                      color: AppColors.background,
                                      child: const Icon(Icons.receipt_rounded, color: AppColors.grey),
                                    ),
                                  ),
                                  Container(
                                    width: 54,
                                    height: 54,
                                    color: Colors.black26,
                                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_rounded, color: AppColors.grey),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(Fmt.rupiah(p.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                  StatusChip(p.statusLabel, p.statusColor),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(Fmt.dateTime(p.createdAt), style: const TextStyle(color: AppColors.grey, fontSize: 11.5)),
                              if (p.notes != null && p.notes!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Catatan: ${p.notes}', style: const TextStyle(fontSize: 12, color: AppColors.text)),
                              ],
                              if (p.adminNote != null && p.adminNote!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p.status == 'rejected' ? AppColors.danger.withValues(alpha: 0.1) : AppColors.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Pesan Admin: ${p.adminNote}',
                                    style: TextStyle(fontSize: 11.5, color: p.status == 'rejected' ? AppColors.danger : AppColors.grey, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _PayFeeSheet extends StatefulWidget {
  final Map data;
  final VoidCallback onSuccess;
  const _PayFeeSheet({required this.data, required this.onSuccess});

  @override
  State<_PayFeeSheet> createState() => _PayFeeSheetState();
}

class _PayFeeSheetState extends State<_PayFeeSheet> {
  late final TextEditingController _amountCtrl;
  final _notesCtrl = TextEditingController();
  File? _proofFile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final feePerTrip = (widget.data['fee_per_trip'] ?? widget.data['fee_per_order'] ?? 1000) as num;
    final totalObligation = (widget.data['total_fee_obligation'] ?? 0) as num;
    final totalPaid = (widget.data['total_fee_paid'] ?? widget.data['total_paid'] ?? 0) as num;
    final unpaid = (widget.data['unpaid_fee'] ?? ((totalObligation - totalPaid) > 0 ? (totalObligation - totalPaid) : 0)) as num;
    _amountCtrl = TextEditingController(text: '${unpaid > 0 ? unpaid : feePerTrip}');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 12),
              const Text('Upload Bukti Transfer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(c, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                title: const Text('Ambil dengan Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(c, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final f = await picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    if (f != null && mounted) {
      setState(() => _proofFile = File(f.path));
    }
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      showMsg(context, 'Masukkan jumlah nominal pembayaran yang valid', error: true);
      return;
    }
    if (_proofFile == null) {
      showMsg(context, 'Silakan unggah foto bukti transfer / pembayaran QRIS', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await Api.multipart(
        'driver/fee-payments',
        fields: {
          'amount': '$amount',
          'notes': _notesCtrl.text.trim(),
        },
        files: {
          'proof': _proofFile!.path,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        showMsg(context, 'Bukti pembayaran berhasil dikirim! Menunggu verifikasi Super Admin.');
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showEnlarged(String url) {
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
                  const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('QRIS Resmi Super Admin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                    height: 300,
                    fit: BoxFit.contain,
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

  @override
  Widget build(BuildContext context) {
    final adminQris = widget.data['admin_qris_url'] as String?;
    final hasAdminQris = adminQris != null && adminQris.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
                const Text('Bayar Setoran Biaya Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
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
                  '1. Scan Barcode QRIS Resmi Super Admin di bawah ini melalui m-Banking / E-Wallet:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                if (hasAdminQris)
                  Center(
                    child: InkWell(
                      onTap: () => _showEnlarged(adminQris),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.greyLight),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
                                  SizedBox(width: 4),
                                  Text(
                                    'QRIS Resmi Super Admin',
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
                                padding: const EdgeInsets.all(8),
                                child: Image.network(
                                  Api.resolveUrl(adminQris),
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
                                        Text('Gagal memuat barcode QRIS', style: TextStyle(color: AppColors.danger, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Ketuk untuk perbesar barcode', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.warning),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Super Admin belum mengunggah barcode QRIS resmi. Anda tetap dapat mengunggah bukti transfer manual jika sudah melakukan transfer.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.warning, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  '2. Masukkan Nominal yang Anda Bayarkan:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal Transfer (Rp)',
                    prefixText: 'Rp ',
                    prefixIcon: Icon(Icons.payments_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '3. Unggah Foto Bukti Transfer / Screenshot Pembayaran:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                if (_proofFile != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_proofFile!, width: 50, height: 50, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Foto bukti siap dikirim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text('Ketuk tombol di kanan untuk mengganti', style: TextStyle(fontSize: 11.5, color: AppColors.grey)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _pickProof,
                          child: const Text('Ganti'),
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _pickProof,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Pilih Foto Bukti Pembayaran'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Setoran (Opsional)',
                    hintText: 'Misal: "Setoran 5 trip tanggal 11 Nov"',
                    prefixIcon: Icon(Icons.notes_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Mengirim Bukti...' : 'Kirim Bukti Pembayaran ke Super Admin'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

