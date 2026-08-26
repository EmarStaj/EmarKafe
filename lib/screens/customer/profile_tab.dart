import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/menu_data.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/page_transitions.dart';
import '../../utils/turkish_date.dart';
import '../../widgets/loyalty_card.dart';
import '../../widgets/pressable_scale.dart';
import '../login_screen.dart';
import 'order_history_screen.dart';
import 'wallet_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final app = context.read<AppState>();
        if (app.loggedIn) {
          app.wallet.fetchWalletBalance();
          app.orders.fetchOrders();
        }
      }
    });
  }

  Future<void> _refresh() async {
    final app = context.read<AppState>();
    if (app.loggedIn) {
      await Future.wait([
        app.wallet.fetchWalletBalance(),
        app.orders.fetchOrders(),
        app.auth.fetchMe(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.loggedIn) return const _GuestProfile();

    final rated = app.ratings.entries.toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: EmarColors.paprika,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: EmarColors.moss,
                child: Text(
                  app.userName.isNotEmpty ? app.userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    color: EmarColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.userName,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 17),
                    ),
                    Text(
                      app.userEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: EmarColors.espresso.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Profili Düzenle',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EmarColors.oatDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: EmarColors.espresso,
                  ),
                ),
                onPressed: () => _showEditProfileDialog(context, app),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProfileLine(
            label: '🎂 Doğum Tarihi',
            value: app.birthday == null
                ? '—'
                : formatTurkishDate(app.birthday!),
          ),
          _ProfileLine(label: '📍 Şube', value: app.selectedBranchName),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  n: '${app.orderHistory.length}',
                  l: 'Toplam Sipariş',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  n: '${app.freeCoffeesEarned}',
                  l: 'Hediye Kahve',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                Navigator.of(context).push(softRoute(const WalletScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: EmarColors.oatDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: EmarColors.espresso,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cüzdanım',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${app.walletBalance.toStringAsFixed(2)}₺',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: EmarColors.paprika,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: EmarColors.espresso,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(
              context,
            ).push(softRoute(const OrderHistoryScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: EmarColors.oatDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: EmarColors.espresso,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Geçmiş Siparişlerim',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${app.orderHistory.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: EmarColors.espresso.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: EmarColors.espresso,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LoyaltyCard(progress: 0, freeCoffeesEarned: 0),
          const SizedBox(height: 20),
          Text(
            'Puanladığın Ürünler',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          if (rated.isEmpty)
            Text(
              'Henüz puanlama yapmadın.',
              style: TextStyle(
                fontSize: 12.5,
                color: EmarColors.espresso.withValues(alpha: 0.55),
              ),
            )
          else
            ...rated.map((e) {
              final product = productById(e.key);
              final stars = e.value.round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(product.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '★' * stars,
                      style: const TextStyle(
                        color: EmarColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: EmarColors.paprikaDim,
                side: BorderSide(
                  color: EmarColors.paprikaDim.withValues(alpha: 0.5),
                ),
              ),
              onPressed: () => _showDeleteAccountDialog(context, app),
              child: const Text('Hesabımı Sil'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.read<AppState>().logout(),
              child: const Text('Çıkış Yap'),
            ),
          ),
        ],
      ),
    ),
  );
}

  void _showEditProfileDialog(BuildContext context, AppState app) {
    final nameController = TextEditingController(text: app.userName);
    final emailController = TextEditingController(text: app.userEmail);
    DateTime? selectedBirthDate = app.birthday;
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: EmarColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit_outlined, color: EmarColors.espresso, size: 22),
                SizedBox(width: 8),
                Text(
                  'Profili Düzenle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ad Soyad',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Adınız Soyadınız',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                          isDense: true,
                        ),
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (text.isEmpty) return 'İsim alanı boş bırakılamaz';
                          if (text.length < 2) return 'En az 2 karakter giriniz';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'E-posta',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'ornek@email.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                          isDense: true,
                        ),
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (text.isEmpty) return 'E-posta alanı boş bırakılamaz';
                          if (!text.contains('@') || !text.contains('.')) {
                            return 'Geçerli bir e-posta giriniz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Doğum Tarihi',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedBirthDate ?? DateTime(2000, 1, 1),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedBirthDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cake_outlined, size: 20, color: EmarColors.espresso),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selectedBirthDate == null
                                      ? 'Doğum Tarihi Seçiniz'
                                      : formatTurkishDate(selectedBirthDate!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selectedBirthDate == null ? Colors.grey.shade600 : EmarColors.espresso,
                                  ),
                                ),
                              ),
                              if (selectedBirthDate != null)
                                GestureDetector(
                                  onTap: () => setDialogState(() => selectedBirthDate = null),
                                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          await app.updateProfile(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                            birthDate: selectedBirthDate,
                          );
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profil bilgileriniz başarıyla güncellendi.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text('Hata: $e')),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kaydet'),
              ),
            ],
          );
        },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AppState app) {
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: EmarColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: EmarColors.paprika,
                  size: 28,
                ),
                SizedBox(width: 8),
                Text(
                  'Hesabımı Sil',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EmarColors.paprika,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Hesabınızı silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz. Cüzdan bakiyeniz, sipariş geçmişiniz ve sadakat puanlarınız kalıcı olarak silinecektir.',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EmarColors.paprika,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        try {
                          await app.deleteAccount();
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hesabınız başarıyla silindi.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isDeleting = false);
                          if (dialogCtx.mounted) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(content: Text('Silme başarısız: $e')),
                            );
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Hesabı Kalıcı Olarak Sil',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 110),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, t, child) =>
                  Transform.scale(scale: t, child: child),
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: EmarColors.oatDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 40,
                  color: EmarColors.espresso,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz giriş yapmadın',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Sipariş verebilmek, kahve puanlarını takip edebilmek ve ödül kazanmak için hesabına giriş yap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: EmarColors.espresso.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            PressableScale(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(softRoute(const LoginScreen())),
                  child: const Text('Giriş Yap / Kayıt Ol'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: EmarColors.espresso.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String n;
  final String l;
  const _StatBox({required this.n, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: EmarColors.oatDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            n,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            l,
            style: TextStyle(
              fontSize: 10.5,
              color: EmarColors.espresso.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
