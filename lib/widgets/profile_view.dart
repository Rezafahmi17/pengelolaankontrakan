import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/auth_provider.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'common.dart';

/// Tampilan profil bersama (customer, driver, admin).
class ProfileView extends StatelessWidget {
  final List<Widget> sections;
  final bool showVehicleEdit;
  const ProfileView({super.key, this.sections = const [], this.showVehicleEdit = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user;
    if (u == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: auth.refreshUser,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Avatar(u.initials, url: u.avatarUrl, size: 64, bg: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(u.roleLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                if (u.npm != null && u.npm!.isNotEmpty) InfoRow(Icons.badge_outlined, 'NPM', u.npm!),
                InfoRow(Icons.alternate_email_rounded, 'Email', u.email),
                InfoRow(Icons.phone_android_rounded, 'Nomor HP', u.phone),
              ]),
            ),
          ),
          ...sections,
          const SectionTitle('Pengaturan akun'),
          Card(
            child: Column(children: [
              _tile(Icons.edit_rounded, 'Edit profil', () => _editProfile(context, u)),
              const Divider(indent: 56),
              _tile(Icons.lock_reset_rounded, 'Ubah password', () => _changePassword(context)),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: () async {
              if (await confirm(context, 'Keluar dari akun?', 'Anda perlu login kembali untuk menggunakan aplikasi.', confirmText: 'Keluar', danger: true)) {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                  await context.read<AuthProvider>().logout();
                }
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar'),
          ),
          const SizedBox(height: 14),
          const Center(child: Text('JEKPOL • Politeknik Negeri Lampung v1.0', style: TextStyle(color: AppColors.grey, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) => ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );

  Future<void> _editProfile(BuildContext context, AppUser u) async {
    final name = TextEditingController(text: u.name);
    final phone = TextEditingController(text: u.phone);
    final model = TextEditingController(text: u.driver?.vehicle ?? '');
    final plate = TextEditingController(text: u.driver?.plate ?? '');
    final color = TextEditingController(text: u.driver?.vehicleColor ?? '');
    File? pickedFile;

    await showDialog(
      context: context,
      builder: (ctx) {
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          Future<void> pick(ImageSource source) async {
            try {
              final f = await ImagePicker().pickImage(source: source, maxWidth: 1000, maxHeight: 1000, imageQuality: 85);
              if (f != null) {
                setS(() => pickedFile = File(f.path));
              }
            } catch (e) {
              if (ctx.mounted) showMsg(ctx, 'Gagal memilih gambar: $e', error: true);
            }
          }

          void showImageSourceOptions() {
            showModalBottomSheet(
              context: ctx,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (bCtx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pilih Foto Profil', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                        title: const Text('Ambil dari Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(bCtx);
                          pick(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                        title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(bCtx);
                          pick(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Edit Profil', style: TextStyle(fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: showImageSourceOptions,
                        child: Avatar(
                          u.initials,
                          url: u.avatarUrl,
                          file: pickedFile,
                          size: 88,
                          bg: AppColors.primaryLight,
                        ),
                      ),
                      Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: showImageSourceOptions,
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: showImageSourceOptions,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text(
                    pickedFile != null ? 'Ganti Foto Pilihan' : 'Upload Foto Profil',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama lengkap')),
                const SizedBox(height: 12),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP')),
                if (showVehicleEdit && u.role == 'driver') ...[
                  const SizedBox(height: 12),
                  TextField(controller: model, decoration: const InputDecoration(labelText: 'Merek & tipe motor')),
                  const SizedBox(height: 12),
                  TextField(controller: plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Plat nomor')),
                  const SizedBox(height: 12),
                  TextField(controller: color, decoration: const InputDecoration(labelText: 'Warna')),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: AppColors.grey))),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
                onPressed: busy
                    ? null
                    : () async {
                        setS(() => busy = true);
                        try {
                          final fields = <String, String>{
                            'name': name.text.trim(),
                            'phone': phone.text.trim(),
                            if (showVehicleEdit && u.role == 'driver') ...{
                              'vehicle_model': model.text.trim(),
                              'plate_number': plate.text.trim(),
                              'vehicle_color': color.text.trim(),
                            },
                          };
                          Map<String, dynamic> r;
                          if (pickedFile != null) {
                            r = await Api.multipart('profile/update', fields: fields, files: {'avatar': pickedFile!.path});
                          } else {
                            r = await Api.post('profile/update', body: fields);
                          }
                          if (context.mounted) context.read<AuthProvider>().setUser(AppUser.fromJson(r['user']));
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) showMsg(context, 'Profil berhasil diperbarui');
                        } catch (e) {
                          setS(() => busy = false);
                          if (ctx.mounted) showError(ctx, e);
                        }
                      },
                child: const Text('Simpan'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Ubah Password', style: TextStyle(fontWeight: FontWeight.w800)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: oldC, obscureText: true, decoration: const InputDecoration(labelText: 'Password lama')),
              const SizedBox(height: 12),
              TextField(controller: newC, obscureText: true, decoration: const InputDecoration(labelText: 'Password baru (min. 6 karakter)')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: AppColors.grey))),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
                onPressed: busy
                    ? null
                    : () async {
                        setS(() => busy = true);
                        try {
                          await Api.post('profile/password', body: {'old_password': oldC.text, 'new_password': newC.text});
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) showMsg(context, 'Password berhasil diubah');
                        } catch (e) {
                          setS(() => busy = false);
                          if (ctx.mounted) showError(ctx, e);
                        }
                      },
                child: const Text('Simpan'),
              ),
            ],
          );
        });
      },
    );
  }
}

