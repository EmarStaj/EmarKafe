import 'package:emar_kafe/models/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/stock_manager_sheet.dart';

enum _RevenueRange { daily, weekly }

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  _RevenueRange _range = _RevenueRange.daily;

  // Saat 09 - 24 arası göreli sipariş yoğunluğu (0-1)
  final List<double> _hourly = [
    0.30,
    0.45,
    0.88,
    0.95,
    0.40,
    0.35,
    0.55,
    0.80,
    0.92,
    0.50,
    0.28,
    0.18,
  ];

  // Günlük ciro (son 7 gün) ve haftalık ciro (son 6 hafta) — mock ₺ verisi (API bağlanana kadar).
  final List<int> _dailyRevenue = [4200, 4800, 5100, 3900, 6200, 7400, 6800];
  final List<int> _weeklyRevenue = [28400, 31200, 29800, 33500, 36100, 38900];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStaff());
  }

  Future<void> _loadStaff() async {
    if (!mounted) return;
    final app = context.read<AppState>();
    await app.staff.fetchStaff(branchId: app.selectedBranchId);
    if (mounted) setState(() {});
  }

  Future<void> _openAddStaffDialog(AppState app) async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String? errorMsg;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Yeni Barista Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Şifre (min 8 karakter)',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      color: EmarColors.paprikaDim,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final password = passwordCtrl.text;
                      if (name.isEmpty ||
                          email.isEmpty ||
                          password.length < 8) {
                        setDialogState(
                          () => errorMsg =
                              'Ad, e-posta ve en az 8 karakterli şifre zorunlu.',
                        );
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorMsg = null;
                      });
                      final ok = await app.staff.createStaff(
                        email: email,
                        password: password,
                        fullName: name,
                        role: 'barista',
                        branchId: app.selectedBranchId,
                      );
                      if (ok) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = app.staff.error;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStaff(AppState app, StaffMember s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Personeli Çıkar'),
        content: Text('${s.fullName} adlı personel şubenizden çıkarılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: EmarColors.paprika,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Çıkar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await app.staff.deleteStaff(
        s.id,
        branchId: app.selectedBranchId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? '${s.fullName} kaldırıldı.' : 'Hata: ${app.staff.error}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final revenueData = _range == _RevenueRange.daily
        ? _dailyRevenue
        : _weeklyRevenue;
    final revenueLabels = _range == _RevenueRange.daily
        ? const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
        : const ['-5h', '-4h', '-3h', '-2h', '-1h', 'Bu h.'];
    final maxRevenue = revenueData.reduce((a, b) => a > b ? a : b);
    final totalRevenue = revenueData.fold(0, (a, b) => a + b);
    final staffList = app.staff.staffList;

    return Scaffold(
      appBar: AppBar(
        title: Text('Yönetici – ${app.selectedBranchName}'),
        actions: [
          IconButton(
            tooltip: 'Stok Yönetimi',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => showStockManager(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: EmarColors.espresso,
        foregroundColor: EmarColors.surface,
        tooltip: 'Yeni Barista Ekle',
        onPressed: () => _openAddStaffDialog(app),
        child: const Icon(Icons.person_add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Şube Personeli',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
                if (app.staff.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _loadStaff,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (staffList.isEmpty && !app.staff.isLoading)
              Text(
                app.staff.error != null
                    ? 'Yüklenirken hata: ${app.staff.error}'
                    : 'Henüz personel yok.',
                style: TextStyle(
                  fontSize: 12,
                  color: EmarColors.espresso.withValues(alpha: 0.5),
                ),
              )
            else
              ...staffList.map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: EmarColors.moss,
                            child: Text(
                              s.fullName.isNotEmpty
                                  ? s.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: EmarColors.surface,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: EmarColors.oatDark,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              s.roleLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                            ),
                            color: EmarColors.paprikaDim,
                            onPressed: () => _deleteStaff(app, s),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ciro',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
                SegmentedButton<_RevenueRange>(
                  segments: const [
                    ButtonSegment(
                      value: _RevenueRange.daily,
                      label: Text('Günlük', style: TextStyle(fontSize: 11.5)),
                    ),
                    ButtonSegment(
                      value: _RevenueRange.weekly,
                      label: Text('Haftalık', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: EmarColors.espresso,
                    selectedForegroundColor: EmarColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_range == _RevenueRange.daily ? "Son 7 gün" : "Son 6 hafta"} toplam: $totalRevenue₺ (demo)',
              style: TextStyle(
                fontSize: 11.5,
                color: EmarColors.espresso.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: revenueData.map((v) {
                  final peak = v == maxRevenue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 420),
                        heightFactor: v / maxRevenue,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: peak
                                ? EmarColors.paprika
                                : EmarColors.oatDark,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: revenueLabels
                  .map(
                    (t) => Text(
                      t,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: EmarColors.espresso.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 24),
            Text(
              'Bugünün Saatlik Sipariş Yoğunluğu (demo)',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _hourly.map((v) {
                  final peak = v >= 0.8;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FractionallySizedBox(
                        heightFactor: v,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: peak
                                ? EmarColors.paprika
                                : EmarColors.oatDark,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['09', '12', '15', '18', '21', '24']
                  .map(
                    (t) => Text(
                      t,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: EmarColors.espresso.withValues(alpha: 0.55),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

/// Implicit animasyon sarmalayıcısı — yükseklik oranı değiştiğinde yumuşak geçiş.
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double heightFactor;
  final Alignment alignment;
  final Widget child;
  const AnimatedFractionallySizedBox({
    super.key,
    required this.heightFactor,
    required this.alignment,
    required this.child,
    required super.duration,
  });

  @override
  ImplicitlyAnimatedWidgetState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends ImplicitlyAnimatedWidgetState<AnimatedFractionallySizedBox> {
  Tween<double>? _factor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _factor =
        visitor(
              _factor,
              widget.heightFactor,
              (v) => Tween<double>(begin: v as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final value = _factor?.evaluate(animation) ?? widget.heightFactor;
    return FractionallySizedBox(
      heightFactor: value,
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}
