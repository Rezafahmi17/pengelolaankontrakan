import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/auth_provider.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    try {
      await context.read<AuthProvider>().login(_id.text.trim(), _pw.text);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordSheet(
        initialIdentifier: _id.text.trim(),
        onResetSuccess: (identifier) {
          setState(() {
            _id.text = identifier;
            _pw.clear();
          });
        },
      ),
    );
  }

  void _showServerDialog() {
    final cur = AppConfig.baseUrl;
    final c = TextEditingController(text: cur);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pengaturan IP Server', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alamat API backend di laptop Anda (pastikan satu Wi-Fi):',
              style: TextStyle(fontSize: 13, color: AppColors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              decoration: const InputDecoration(
                labelText: 'URL Server / IP Laptop',
                hintText: 'http://192.168.18.11/gojek_polinela/api/index.php',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('IP Wi-Fi Laptop Ini', style: TextStyle(fontSize: 11)),
                  onPressed: () => c.text = 'http://192.168.18.11/gojek_polinela/api/index.php',
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                  onPressed: () => c.text = 'http://10.0.2.2/gojek_polinela/api/index.php',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final val = c.text.trim();
              if (val.isNotEmpty) {
                await context.read<AuthProvider>().setBaseUrl(val);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  showMsg(context, 'Alamat server berhasil diperbarui');
                  context.read<AuthProvider>().init();
                }
              }
            },
            child: const Text('Simpan & Hubungkan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startupError = context.watch<AuthProvider>().startupError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background emerald header with smooth curves
          Container(
            height: MediaQuery.of(context).size.height * 0.44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF063B1F), AppColors.primary, Color(0xFF0F7A44)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  // Rider Logo (Tekan lama untuk Pengaturan IP Server)
                  GestureDetector(
                    onLongPress: _showServerDialog,
                    child: const AppLogo(size: 88, light: true),
                  ),
                  const SizedBox(height: 12),
                  // JEKPOL Brand Name
                  const Text(
                    'JEKPOL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Politeknik Negeri Lampung',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Main Login Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.black.withValues(alpha: 0.04), width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Selamat Datang',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Silakan masuk ke akun JEKPOL Anda',
                              style: TextStyle(color: AppColors.grey, fontSize: 13.5),
                            ),
                            if (startupError != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            startupError,
                                            style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: AppColors.primary,
                                        ),
                                        onPressed: _showServerDialog,
                                        icon: const Icon(Icons.settings_rounded, size: 16),
                                        label: const Text('Ganti IP Server', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _id,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email atau NPM',
                                hintText: 'nama@student.polinela.ac.id',
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Email atau NPM wajib diisi' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _pw,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.grey,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _showForgotPasswordSheet,
                                child: const Text(
                                  'Lupa Kata Sandi?',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _login,
                              icon: const Icon(Icons.login_rounded, size: 20),
                              label: const Text(
                                'Masuk Sekarang',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Belum punya akun? ', style: TextStyle(color: AppColors.grey)),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'Daftar di sini',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialIdentifier;
  final ValueChanged<String> onResetSuccess;

  const _ForgotPasswordSheet({
    required this.initialIdentifier,
    required this.onResetSuccess,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _idCtrl;
  final _phoneCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _verified = false;
  bool _busy = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  Map<String, dynamic>? _matchedUser;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyIdentity() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await Api.post('auth/forgot-password/verify', body: {
        'identifier': _idCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _verified = true;
        _matchedUser = r['user'] is Map<String, dynamic>
            ? r['user'] as Map<String, dynamic>
            : null;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await Api.post('auth/forgot-password/reset', body: {
        'identifier': _idCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'new_password': _newPwCtrl.text,
      });
      if (!mounted) return;
      final id = _idCtrl.text.trim();
      Navigator.pop(context);
      widget.onResetSuccess(id);
      showMsg(context, r['_message'] ?? 'Kata sandi berhasil diperbarui!');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _roleName(String? role) => switch (role) {
        'driver' => 'Driver',
        'admin' => 'Admin',
        'super_admin' => 'Super Admin',
        _ => 'Customer',
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _verified ? Icons.lock_reset_rounded : Icons.verified_user_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _verified ? 'Buat Kata Sandi Baru' : 'Lupa Kata Sandi',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              _verified
                                  ? 'Langkah 2 dari 2 • Atur ulang kata sandi Anda'
                                  : 'Langkah 1 dari 2 • Verifikasi identitas akun',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (!_verified) ...[
                    const Text(
                      'Masukkan Email atau NPM beserta Nomor HP yang terdaftar pada akun JEKPOL Anda untuk mereset kata sandi:',
                      style: TextStyle(fontSize: 13, color: AppColors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _idCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email atau NPM Terdaftar',
                        hintText: 'Contoh: budi@student.polinela.ac.id / 2215011001',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Email atau NPM wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _verifyIdentity(),
                      decoration: InputDecoration(
                        labelText: 'Nomor HP Terdaftar',
                        hintText: 'Contoh: 0812xxxxxxxx',
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 7) ? 'Masukkan nomor HP yang terdaftar' : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _busy ? null : _verifyIdentity,
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        _busy ? 'Memverifikasi...' : 'Verifikasi Akun',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ] else ...[
                    if (_matchedUser != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_matchedUser!['name'] ?? 'Pengguna'} (${_roleName(_matchedUser!['role']?.toString())})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  Text(
                                    '${_matchedUser!['email'] ?? ''}${_matchedUser!['npm'] != null ? ' • NPM: ${_matchedUser!['npm']}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: _newPwCtrl,
                      obscureText: _obscure1,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi Baru (min. 6 karakter)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.grey,
                          ),
                          onPressed: () => setState(() => _obscure1 = !_obscure1),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Kata sandi baru minimal 6 karakter' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPwCtrl,
                      obscureText: _obscure2,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _resetPassword(),
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi Kata Sandi Baru',
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.grey,
                          ),
                          onPressed: () => setState(() => _obscure2 = !_obscure2),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
                        if (v != _newPwCtrl.text) return 'Konfirmasi kata sandi tidak cocok';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(100, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _busy ? null : () => setState(() => _verified = false),
                          child: const Text('Kembali'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _busy ? null : _resetPassword,
                            icon: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              _busy ? 'Menyimpan...' : 'Simpan Kata Sandi',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
