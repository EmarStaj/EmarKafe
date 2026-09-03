import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order_record.dart';
import '../../models/product.dart';
import '../../models/staff_member.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/stock_manager_sheet.dart';

enum _RevenueRange { daily, weekly }

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _RevenueRange _range = _RevenueRange.daily;

  String _staffSearch = '';
  String _stockSearch = '';
  ProductCategory? _selectedStockCategory;
  String _orderStatusFilter = 'Tümü';

  // Saat 09 - 24 arası göreli sipariş yoğunluğu (0-1)
  final List<double> _hourly = [
    0.30, 0.45, 0.88, 0.95, 0.40, 0.35, 0.55, 0.80, 0.92, 0.50, 0.28, 0.18, 0.35,
  ];

  // Günlük ciro (son 7 gün) ve haftalık ciro (son 6 hafta)
  final List<int> _dailyRevenue = [4200, 4800, 5100, 3900, 6200, 7400, 6800];
  final List<int> _weeklyRevenue = [28400, 31200, 29800, 33500, 36100, 38900];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final app = context.read<AppState>();
    await Future.wait([
      app.staff.fetchStaff(branchId: app.selectedBranchId),
      app.menu.fetchFirstPage(),
      app.orders.fetchOrders(),
    ]);
    if (app.selectedBranchId != null) {
      await app.stock.fetchBranchStock(app.selectedBranchId!);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          title: const Text('Yeni Barista Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Şifre (en az 8 karakter)', prefixIcon: Icon(Icons.lock)),
                  obscureText: true,
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMsg!, style: const TextStyle(color: EmarColors.paprikaDim, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: EmarColors.espresso),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final password = passwordCtrl.text;
                      if (name.isEmpty || email.isEmpty || password.length < 8) {
                        setDialogState(() => errorMsg = 'Ad, e-posta ve en az 8 karakterli şifre zorunlu.');
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
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name baristalara eklendi.')),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = app.staff.error ?? 'Personel eklenemedi.';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        content: Text('${s.fullName} adlı barista şubenizden çıkarılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EmarColors.paprika),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Çıkar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await app.staff.deleteStaff(s.id, branchId: app.selectedBranchId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '${s.fullName} kaldırıldı.' : 'Hata: ${app.staff.error}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: EmarColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yönetici · ${app.selectedBranchName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Şube Yönetim Paneli', style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hızlı Stok Sheet',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => showStockManager(context),
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadInitialData(),
          ),
          IconButton(
            tooltip: 'Çıkış Yap',
            icon: const Icon(Icons.logout),
            onPressed: () => app.auth.logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: EmarColors.espresso,
          unselectedLabelColor: EmarColors.espresso.withValues(alpha: 0.5),
          indicatorColor: EmarColors.paprika,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Şube Özeti & Ciro'),
            Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Ekip & Baristalar'),
            Tab(icon: Icon(Icons.inventory_outlined, size: 18), text: 'Canlı Stok Kontrolü'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Siparişler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(app),
          _buildStaffTab(app),
          _buildStockTab(app),
          _buildOrdersTab(app),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ŞUBE ÖZETİ & CİRO
  // ==========================================
  Widget _buildOverviewTab(AppState app) {
    final revenueData = _range == _RevenueRange.daily ? _dailyRevenue : _weeklyRevenue;
    final revenueLabels = _range == _RevenueRange.daily
        ? const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
        : const ['-5h', '-4h', '-3h', '-2h', '-1h', 'Bu h.'];
    final maxRevenue = revenueData.reduce((a, b) => a > b ? a : b);
    final totalRevenue = revenueData.fold(0, (a, b) => a + b);

    final branchOrders = app.orderHistory.where((o) => o.branch == app.selectedBranchName).toList();
    final outOfStockCount = app.stock.currentBranchOutOfStock.length;
    final staffCount = app.staff.staffList.length;

    return RefreshIndicator(
      onRefresh: () => _loadInitialData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 4 KPI Cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _KpiCard(
                title: 'Bugünkü Ciro (Tahmini)',
                value: '${_dailyRevenue.last}₺',
                icon: Icons.payments,
                color: EmarColors.paprika,
              ),
              _KpiCard(
                title: 'Şube Siparişleri',
                value: '${branchOrders.length} Adet',
                icon: Icons.receipt_long,
                color: EmarColors.moss,
              ),
              _KpiCard(
                title: 'Aktif Barista',
                value: '$staffCount Kişi',
                icon: Icons.coffee,
                color: EmarColors.espresso,
              ),
              _KpiCard(
                title: 'Tükenen Ürün',
                value: '$outOfStockCount Ürün',
                icon: Icons.block,
                color: outOfStockCount > 0 ? EmarColors.paprika : EmarColors.moss,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Revenue Chart Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EmarColors.oatDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ciro Analizi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Toplam: ${totalRevenue.toString()}₺', style: TextStyle(fontSize: 12, color: EmarColors.espresso.withValues(alpha: 0.6))),
                      ],
                    ),
                    SegmentedButton<_RevenueRange>(
                      segments: const [
                        ButtonSegment(value: _RevenueRange.daily, label: Text('Günlük', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: _RevenueRange.weekly, label: Text('Haftalık', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_range},
                      onSelectionChanged: (s) => setState(() => _range = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(revenueData.length, (i) {
                      final val = revenueData[i];
                      final ratio = val / maxRevenue;
                      final isLast = i == revenueData.length - 1;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${(val / 1000).toStringAsFixed(1)}k', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: 70 * ratio,
                            decoration: BoxDecoration(
                              color: isLast ? EmarColors.paprika : EmarColors.espresso.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(revenueLabels[i], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Peak Hours Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EmarColors.oatDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saatlik Sipariş Yoğunluğu (09:00 - 22:00)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('En yoğun saat: 12:00 - 13:00 ve 18:00 - 19:00', style: TextStyle(fontSize: 11.5, color: EmarColors.espresso.withValues(alpha: 0.6))),
                const SizedBox(height: 14),
                SizedBox(
                  height: 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _hourly.map((h) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 60 * h,
                            decoration: BoxDecoration(
                              color: h > 0.8 ? EmarColors.paprika : EmarColors.moss,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: EKİP & BARİSTALAR
  // ==========================================
  Widget _buildStaffTab(AppState app) {
    final staffList = app.staff.staffList.where((s) {
      return s.fullName.toLowerCase().contains(_staffSearch.toLowerCase()) ||
          (s.email?.toLowerCase().contains(_staffSearch.toLowerCase()) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EmarColors.espresso,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Barista Ekle'),
        onPressed: () => _openAddStaffDialog(app),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Barista ara (isim veya e-posta)...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: EmarColors.oatDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (v) => setState(() => _staffSearch = v),
          ),
          const SizedBox(height: 14),

          if (staffList.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Bu şubeye kayıtlı barista bulunamadı.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...staffList.map((s) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EmarColors.oatDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: EmarColors.moss,
                      child: Icon(Icons.coffee, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          if (s.email != null)
                            Text(s.email!, style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.6))),
                          Text('📍 ${app.selectedBranchName}', style: TextStyle(fontSize: 10.5, color: EmarColors.espresso.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: EmarColors.paprika, size: 20),
                      onPressed: () => _deleteStaff(app, s),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: CANLI STOK KONTROLÜ
  // ==========================================
  Widget _buildStockTab(AppState app) {
    final products = app.menu.products.where((p) {
      final matchesCat = _selectedStockCategory == null || p.category == _selectedStockCategory;
      final matchesSearch = p.name.toLowerCase().contains(_stockSearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Ürün ara...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: EmarColors.oatDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: (v) => setState(() => _stockSearch = v),
        ),
        const SizedBox(height: 10),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Tümü', style: TextStyle(fontSize: 11.5)),
                  selected: _selectedStockCategory == null,
                  selectedColor: EmarColors.espresso,
                  labelStyle: TextStyle(color: _selectedStockCategory == null ? Colors.white : EmarColors.espresso, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _selectedStockCategory = null),
                ),
              ),
              ...ProductCategory.values.map((cat) {
                final selected = cat == _selectedStockCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat.label, style: const TextStyle(fontSize: 11.5)),
                    selected: selected,
                    selectedColor: EmarColors.espresso,
                    labelStyle: TextStyle(color: selected ? Colors.white : EmarColors.espresso, fontWeight: FontWeight.w700),
                    onSelected: (_) => setState(() => _selectedStockCategory = cat),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ...products.map((p) {
          final isOut = app.isOutOfStock(p.id);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: EmarColors.oatDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isOut ? EmarColors.paprika.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Text(p.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          decoration: isOut ? TextDecoration.lineThrough : null,
                          color: isOut ? EmarColors.espresso.withValues(alpha: 0.5) : null,
                        ),
                      ),
                      Text('${p.price.toStringAsFixed(0)}₺ · ${p.category.label}', style: TextStyle(fontSize: 11, color: isOut ? EmarColors.paprikaDim : EmarColors.espresso.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                if (isOut)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: EmarColors.paprika.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Tükendi', style: TextStyle(fontSize: 10, color: EmarColors.paprika, fontWeight: FontWeight.bold)),
                  ),
                Switch(
                  value: !isOut,
                  activeThumbColor: EmarColors.moss,
                  onChanged: (_) => app.toggleStock(p.id),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // TAB 4: ŞUBE SİPARİŞLERİ & KUYRUK
  // ==========================================
  Widget _buildOrdersTab(AppState app) {
    final branchOrders = app.orderHistory.where((o) {
      final matchesBranch = o.branch == app.selectedBranchName;
      if (!matchesBranch) return false;

      if (_orderStatusFilter == 'Tümü') return true;
      if (_orderStatusFilter == 'Hazırlanıyor') return o.manualStatus == OrderStatus.preparing || o.manualStatus == OrderStatus.received;
      if (_orderStatusFilter == 'Tamamlandı') return o.manualStatus == OrderStatus.completed;
      if (_orderStatusFilter == 'İptal') return o.manualStatus == OrderStatus.cancelled;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Tümü', 'Hazırlanıyor', 'Tamamlandı', 'İptal'].map((st) {
              final selected = st == _orderStatusFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(st, style: const TextStyle(fontSize: 11.5)),
                  selected: selected,
                  selectedColor: EmarColors.espresso,
                  labelStyle: TextStyle(color: selected ? Colors.white : EmarColors.espresso, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _orderStatusFilter = st),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        if (branchOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Text('Bu filtreye uygun sipariş bulunmuyor.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...branchOrders.map((o) {
            final isCompleted = o.manualStatus == OrderStatus.completed;
            final isCancelled = o.manualStatus == OrderStatus.cancelled;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EmarColors.oatDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Sipariş #${o.id.length >= 6 ? o.id.substring(0, 6) : o.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const Spacer(),
                      Text('${o.total.toStringAsFixed(0)}₺', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: EmarColors.paprika)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(o.itemsSummary, style: TextStyle(fontSize: 11.5, color: EmarColors.espresso.withValues(alpha: 0.8))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCompleted ? EmarColors.moss : (isCancelled ? Colors.grey : Colors.orange),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isCompleted ? 'Teslim Edildi' : (isCancelled ? 'İptal' : 'Hazırlanıyor'),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      if (!isCompleted && !isCancelled)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EmarColors.moss,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => app.advanceOrderStatus(o),
                          child: const Text('Tamamla', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ==========================================
// SUB-WIDGETS & TILES
// ==========================================

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EmarColors.oatDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Georgia',
              color: EmarColors.espresso,
            ),
          ),
        ],
      ),
    );
  }
}
