import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/credentials.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _serverController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// If the user logged out but the keychain entry survived, prefill the form.
  Future<void> _prefill() async {
    final stored = await ref.read(authRepositoryProvider).readStored();
    if (stored == null || !mounted) return;
    _serverController.text = stored.serverUrl;
    _userController.text = stored.username;
    _passController.text = stored.password;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    final credentials = Credentials(
      serverUrl: _serverController.text,
      username: _userController.text.trim(),
      password: _passController.text,
    );

    final result = await ref.read(authRepositoryProvider).login(credentials);
    if (!mounted) return;

    result.fold(
      onSuccess: (creds) {
        ref.read(sessionProvider.notifier).set(creds);
      },
      onFailure: (failure) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Header(),
                    const SizedBox(height: 36),
                    _Field(
                      controller: _serverController,
                      label: 'رابط الخادم',
                      hint: 'http://example.com:8080',
                      icon: Icons.dns_outlined,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'أدخل رابط الخادم';
                        }
                        final normalized =
                            Credentials(serverUrl: v, username: 'x', password: 'x')
                                .baseUrl;
                        if (Uri.tryParse(normalized)?.host.isEmpty ?? true) {
                          return 'الرابط غير صالح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _userController,
                      label: 'اسم المستخدم',
                      icon: Icons.person_outline,
                      textDirection: TextDirection.ltr,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'أدخل اسم المستخدم'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _passController,
                      label: 'كلمة المرور',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      textDirection: TextDirection.ltr,
                      trailing: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? 'إظهار' : 'إخفاء',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _busy ? null : _connect,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.white,
                              ),
                            )
                          : const Text('اتصال'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(AppConstants.supportWhatsAppUrl);
                        // externalApplication hands off to WhatsApp itself
                        // rather than opening a web view inside the app.
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.support_agent_rounded, size: 20),
                      label: const Text('الدعم الفني'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'تُحفظ بيانات الدخول في Keychain على جهازك، ولن يُطلب '
                      'منك إدخالها مرة أخرى.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(Icons.download_rounded,
              size: 40, color: AppColors.accent),
        ),
        const SizedBox(height: 20),
        Text('مدير التحميل',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 6),
        Text(
          'حمّل الأفلام والمسلسلات إلى جهازك',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

/// Text field with the paste and clear affordances the brief asked for.
class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textDirection,
    this.validator,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final String? Function(String?)? validator;
  final Widget? trailing;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    widget.controller.text = text;
    widget.controller.selection =
        TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Row(
            children: [
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const Spacer(),
              _MiniButton(
                label: 'لصق',
                icon: Icons.content_paste_rounded,
                onTap: _paste,
              ),
              const SizedBox(width: 8),
              _MiniButton(
                label: 'مسح',
                icon: Icons.backspace_outlined,
                onTap: hasText ? _clear : null,
              ),
            ],
          ),
        ),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          textDirection: widget.textDirection,
          autocorrect: false,
          enableSuggestions: false,
          validator: widget.validator,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintTextDirection: TextDirection.ltr,
            prefixIcon: Icon(widget.icon, size: 20),
            suffixIcon: widget.trailing,
          ),
        ),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: enabled ? AppColors.accent : AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.accent : AppColors.textTertiary,
                )),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: AppColors.danger, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
