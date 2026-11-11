import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/custom_nav_bar.dart';
import '../../widgets/profile_view.dart';
import 'driver_controller.dart';
import 'earnings_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  late final DriverController _ctrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = DriverController(context.read<AuthProvider>());
    _ctrl.start();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final driver = user?.driver;

    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Consumer<DriverController>(
        builder: (context, c, _) => Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              DriverHomeScreen(onOpenOrders: () => setState(() => _index = 1)),
              const DriverOrdersScreen(),
              const EarningsScreen(),
              Scaffold(
                appBar: AppBar(title: const Text('Profil Driver')),
                body: ProfileView(
                  showVehicleEdit: true,
                  sections: [
                    const SectionTitle('Status driver'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(children: [
                          InfoRow(
                            Icons.verified_user_rounded,
                            'Verifikasi',
                            switch (driver?.verificationStatus) {
                              'approved' => 'Terverifikasi (Disetujui)',
                              'rejected' => 'Ditolak: ${driver?.rejectionReason ?? ""}',
                              _ => 'Menunggu verifikasi admin',
                            },
                            valueColor: switch (driver?.verificationStatus) {
                              'approved' => AppColors.success,
                              'rejected' => AppColors.danger,
                              _ => AppColors.warning,
                            },
                          ),
                          InfoRow(
                            Icons.star_rounded,
                            'Rating driver',
                            '${driver?.ratingAvg.toStringAsFixed(1) ?? "0.0"} (${driver?.ratingCount ?? 0} ulasan)',
                            valueColor: AppColors.warning,
                          ),
                          InfoRow(
                            Icons.warning_amber_rounded,
                            'Poin pelanggaran',
                            '${driver?.penaltyPoints ?? 0} poin (Batas: ${driver?.penaltyThreshold ?? 3})',
                            valueColor: (driver?.penaltyPoints ?? 0) > 0 ? AppColors.danger : AppColors.grey,
                          ),
                        ]),
                      ),
                    ),
                    const SectionTitle('Data kendaraan'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(children: [
                          InfoRow(Icons.two_wheeler_rounded, 'Kendaraan', driver?.vehicle ?? '-'),
                          InfoRow(Icons.tag_rounded, 'Plat Nomor', driver?.plate ?? '-'),
                          InfoRow(Icons.palette_outlined, 'Warna', driver?.vehicleColor ?? '-'),
                        ]),
                      ),
                    ),
                    const SectionTitle('QRIS Pembayaran Driver'),
                    const _DriverQrisCard(),
                  ],
                ),
              ),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: CustomFloatingNavBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: [
              const NavItem(
                icon: Icons.navigation_outlined,
                activeIcon: Icons.navigation_rounded,
                label: 'Beranda',
              ),
              NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Pesanan',
                showBadge: c.active != null,
              ),
              const NavItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: 'Pendapatan',
              ),
              const NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverQrisCard extends StatelessWidget {
  const _DriverQrisCard();

  Future<void> _pickAndUpload(BuildContext context) async {
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
              const Text('Upload Barcode QRIS Anda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
    if (f == null) return;

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await Api.multipart('driver/qris', files: {'qris': f.path});
      if (context.mounted) {
        await context.read<AuthProvider>().refreshUser();
        Navigator.of(context, rootNavigator: true).pop();
        showMsg(context, 'Foto QRIS berhasil diperbarui!');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showError(context, e);
      }
    }
  }

  void _showEnlarged(BuildContext context, String url) {
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
                    child: Text('Barcode QRIS Anda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                    height: 280,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Gagal memuat gambar', style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
    final auth = context.watch<AuthProvider>();
    final qris = auth.user?.driver?.qrisUrl;
    final hasQris = qris != null && qris.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Foto QRIS Anda akan ditampilkan secara otomatis kepada customer yang memilih opsi pembayaran QRIS saat memesan.',
              style: TextStyle(color: AppColors.grey, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (hasQris) ...[
              Center(
                child: InkWell(
                  onTap: () => _showEnlarged(context, qris),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.greyLight),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            Api.resolveUrl(qris),
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2_rounded, size: 80, color: AppColors.grey),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Ketuk untuk perbesar', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _pickAndUpload(context),
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Ganti Foto QRIS'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.greyLight),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 54, color: AppColors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada QRIS yang diunggah',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upload barcode QRIS Anda agar customer dapat membayar non-tunai langsung ke Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _pickAndUpload(context),
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Upload Foto QRIS Driver'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

