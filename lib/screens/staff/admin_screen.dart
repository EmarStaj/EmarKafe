import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/campaigns_data.dart';
import '../../models/branch.dart';
import '../../models/order_record.dart';
import '../../models/product.dart';
import '../../models/staff_member.dart';
import '../../state/app_state.dart';
import '../../theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Overview Filters
  String _orderBranchFilter = 'Tümü';

  // Staff Search & Filter
  String _staffSearch = '';
  String _staffRoleFilter = 'Tümü';

  // Branch Search
  String _branchSearch = '';

  // Menu Search & Filter
  String _menuSearch = '';
  ProductCategory? _selectedCategory;

  // System Settings State
  int _loyaltyThreshold = 5;
  double _taxRate = 10.0;
  bool _isLoadingSettings = false;
  bool _isSavingSettings = false;

  static const _campaignColorPool = [
    [EmarColors.paprika, EmarColors.paprikaDim],
    [EmarColors.moss, EmarColors.espresso],
    [EmarColors.gold, EmarColors.moss],
    [EmarColors.espresso, EmarColors.roast],
  ];
  int _colorPoolIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final app = context.read<AppState>();
    await Future.wait([
      app.staff.fetchStaff(),
      app.auth.refreshBranches(),
      app.menu.fetchFirstPage(),
      app.orders.fetchOrders(),
    ]);
    _loadSettings(app);
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings(AppState app) async {
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await app.api.getSystemSettings();
      if (mounted && settings.isNotEmpty) {
        setState(() {
          _loyaltyThreshold = settings['loyalty_threshold'] is int
              ? settings['loyalty_threshold']
              : int.tryParse('${settings['loyalty_threshold']}') ?? 5;
          _taxRate = settings['tax_rate'] is num
              ? (settings['tax_rate'] as num).toDouble()
              : double.tryParse('${settings['tax_rate']}') ?? 10.0;
        });
      }
    } catch (_) {
      // Fallback to default
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveSettings(AppState app) async {
    setState(() => _isSavingSettings = true);
    try {
      await app.api.updateSystemSettings({
        'loyalty_threshold': _loyaltyThreshold,
        'tax_rate': _taxRate,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sistem ayarları başarıyla güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayar kaydetme hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Dialogs ---

  Future<void> _openAddStaffDialog(AppState app) async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedRole = 'barista';
    String? selectedBranchId = app.branches.firstOrNull?.id;
    String? errorMsg;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Yeni Personel Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Şifre (en az 8 karakter)',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Yetki Rolü', prefixIcon: Icon(Icons.shield_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'barista', child: Text('Barista')),
                    DropdownMenuItem(value: 'branch_manager', child: Text('Şube Müdürü')),
                    DropdownMenuItem(value: 'admin', child: Text('Sistem Yöneticisi')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v ?? 'barista'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedBranchId,
                  decoration: const InputDecoration(labelText: 'Atanacak Şube', prefixIcon: Icon(Icons.storefront_outlined)),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Merkez / Tüm Şubeler')),
                    ...app.branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedBranchId = v),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: EmarColors.paprikaDim, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
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
                        role: selectedRole,
                        branchId: selectedBranchId,
                      );
                      if (ok) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name başarıyla eklendi.')),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = app.staff.error ?? 'Personel oluşturulamadı.';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kaydet'),
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
        title: const Text('Personeli Sil'),
        content: Text('${s.fullName} (${s.roleLabel}) sistemden silinecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EmarColors.paprika),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await app.staff.deleteStaff(s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '${s.fullName} silindi.' : 'Hata: ${app.staff.error}')),
        );
      }
    }
  }

  Future<void> _openAddBranchDialog(AppState app, {Branch? editBranch}) async {
    final nameCtrl = TextEditingController(text: editBranch?.name ?? '');
    final addressCtrl = TextEditingController(text: editBranch?.address ?? '');
    final phoneCtrl = TextEditingController();
    bool isActive = editBranch?.isActive ?? true;
    String? errorMsg;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(editBranch == null ? 'Yeni Şube Ekle' : 'Şubeyi Düzenle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Şube Adı', prefixIcon: Icon(Icons.storefront)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Adres', prefixIcon: Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Telefon Numarası', prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Şube Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pasif şubeler menüde ve siparişte görünmez', style: TextStyle(fontSize: 11)),
                  value: isActive,
                  activeThumbColor: EmarColors.moss,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: EmarColors.paprikaDim, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
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
                      if (name.isEmpty) {
                        setDialogState(() => errorMsg = 'Şube adı zorunludur.');
                        return;
                      }
                      setDialogState(() {
                        isLoading = true;
                        errorMsg = null;
                      });

                      bool ok;
                      if (editBranch == null) {
                        ok = await app.createBranch(
                          name: name,
                          address: addressCtrl.text.trim(),
                          phoneNumber: phoneCtrl.text.trim(),
                          isActive: isActive,
                        );
                      } else {
                        ok = await app.updateBranch(
                          editBranch.id,
                          name: name,
                          address: addressCtrl.text.trim(),
                          phoneNumber: phoneCtrl.text.trim(),
                          isActive: isActive,
                        );
                      }

                      if (ok) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(editBranch == null ? '$name şubesi eklendi.' : '$name güncellendi.')),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = 'İşlem başarısız oldu. Lütfen tekrar deneyin.';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(editBranch == null ? 'Ekle' : 'Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddProductDialog(AppState app, {Product? editProduct}) async {
    final nameCtrl = TextEditingController(text: editProduct?.name ?? '');
    final priceCtrl = TextEditingController(text: editProduct != null ? editProduct.price.toStringAsFixed(0) : '');
    final descCtrl = TextEditingController(text: editProduct?.description ?? '');
    ProductCategory cat = editProduct?.category ?? ProductCategory.hotCoffee;
    bool isLoyalty = editProduct?.isLoyaltyEligible ?? true;
    bool isActive = editProduct?.isActive ?? true;
    String? errorMsg;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(editProduct == null ? 'Yeni Ürün Ekle' : 'Ürünü Düzenle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Ürün Adı', prefixIcon: Icon(Icons.coffee)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Fiyat (₺)', prefixIcon: Icon(Icons.payments_outlined)),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProductCategory>(
                  initialValue: cat,
                  decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category_outlined)),
                  items: ProductCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                  onChanged: (v) => setDialogState(() => cat = v ?? ProductCategory.hotCoffee),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Açıklama (Opsiyonel)', prefixIcon: Icon(Icons.description_outlined)),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Sadakat Programına Uygun', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Bedava kahve ödülü ile alınabilir', style: TextStyle(fontSize: 11)),
                  value: isLoyalty,
                  activeThumbColor: EmarColors.moss,
                  onChanged: (v) => setDialogState(() => isLoyalty = v),
                ),
                SwitchListTile(
                  title: const Text('Menüde Aktif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: isActive,
                  activeThumbColor: EmarColors.moss,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMsg!,
                    style: const TextStyle(color: EmarColors.paprikaDim, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
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
                      final price = double.tryParse(priceCtrl.text.trim());
                      if (name.isEmpty || price == null || price <= 0) {
                        setDialogState(() => errorMsg = 'Geçerli bir ürün adı ve fiyat giriniz.');
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMsg = null;
                      });

                      // Determine category UUID from DB or default
                      String categoryId = '6e6652da-0fc2-4a8a-98a8-86e20a820f79';
                      if (cat == ProductCategory.icedCoffee) categoryId = 'a528e0e6-ea63-4941-b586-b385e7b9f8b3';
                      if (cat == ProductCategory.dessert) categoryId = 'd4aa8bc1-a005-44d3-a7b6-fe2c20e8a806';

                      bool ok;
                      if (editProduct == null) {
                        ok = await app.createProduct(
                          categoryId: categoryId,
                          name: name,
                          basePrice: price,
                          description: descCtrl.text.trim(),
                          isActive: isActive,
                          isLoyaltyEligible: isLoyalty,
                        );
                      } else {
                        ok = await app.updateProduct(
                          editProduct.id,
                          categoryId: categoryId,
                          name: name,
                          basePrice: price,
                          description: descCtrl.text.trim(),
                          isActive: isActive,
                          isLoyaltyEligible: isLoyalty,
                        );
                      }

                      if (ok) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(editProduct == null ? '$name menüye eklendi.' : '$name güncellendi.')),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = 'İşlem başarısız oldu. Lütfen tekrar deneyin.';
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(editProduct == null ? 'Ekle' : 'Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(AppState app, Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: Text('${p.name} menüden tamamen kaldırılacak. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: EmarColors.paprika),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await app.deleteProduct(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '${p.name} menüden silindi.' : 'Ürün silinemedi.')),
        );
      }
    }
  }

  Future<void> _openAddCampaignDialog(AppState app) async {
    final titleCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    final badgeCtrl = TextEditingController(text: 'YENİ');
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Yeni Kampanya Oluştur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Başlık')),
                const SizedBox(height: 10),
                TextField(controller: subtitleCtrl, decoration: const InputDecoration(labelText: 'Kısa Açıklama')),
                const SizedBox(height: 10),
                TextField(controller: detailsCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Detaylar')),
                const SizedBox(height: 10),
                TextField(controller: badgeCtrl, decoration: const InputDecoration(labelText: 'Rozet (örn: %20 İNDİRİM)')),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: EmarColors.paprikaDim, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: EmarColors.espresso),
              onPressed: () {
                final title = titleCtrl.text.trim();
                final subtitle = subtitleCtrl.text.trim();
                if (title.isEmpty || subtitle.isEmpty) {
                  setDialogState(() => error = 'Başlık ve açıklama zorunludur.');
                  return;
                }
                final colors = _campaignColorPool[_colorPoolIndex % _campaignColorPool.length];
                _colorPoolIndex++;
                app.addCampaign(
                  Campaign(
                    title: title,
                    subtitle: subtitle,
                    details: detailsCtrl.text.trim().isEmpty ? subtitle : detailsCtrl.text.trim(),
                    badge: badgeCtrl.text.trim().isEmpty ? 'YENİ' : badgeCtrl.text.trim().toUpperCase(),
                    icon: '🎁',
                    colors: colors,
                  ),
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title kampanyası yayınlandı.')));
              },
              child: const Text('Yayınla'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: EmarColors.surface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, size: 22),
            SizedBox(width: 8),
            Text('Admin · Genel Bakış', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Verileri Yenile',
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
            Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Genel Bakış'),
            Tab(icon: Icon(Icons.people_alt_outlined, size: 18), text: 'Personel'),
            Tab(icon: Icon(Icons.storefront_outlined, size: 18), text: 'Şubeler'),
            Tab(icon: Icon(Icons.restaurant_menu_outlined, size: 18), text: 'Menü & Ürünler'),
            Tab(icon: Icon(Icons.settings_outlined, size: 18), text: 'Ayarlar & Kampanya'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(app),
          _buildStaffTab(app),
          _buildBranchesTab(app),
          _buildMenuTab(app),
          _buildSettingsTab(app),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: GENEL BAKIŞ & ANALİTİK (OVERVIEW)
  // ==========================================
  Widget _buildOverviewTab(AppState app) {
    final branches = app.branches;
    final totalOrders = app.orderHistory.length;
    final totalRevenue = app.orderHistory.fold<double>(0.0, (sum, o) => sum + o.total);
    final totalStaff = app.staff.staffList.length;
    final totalProducts = app.menu.products.length;

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
                title: 'Aktif Şube',
                value: '${branches.length}',
                icon: Icons.store,
                color: EmarColors.espresso,
              ),
              _KpiCard(
                title: 'Toplam Ciro',
                value: '${totalRevenue.toStringAsFixed(0)}₺',
                icon: Icons.payments,
                color: EmarColors.paprika,
              ),
              _KpiCard(
                title: 'Sipariş Hacmi',
                value: '$totalOrders Adet',
                icon: Icons.receipt_long,
                color: EmarColors.moss,
              ),
              _KpiCard(
                title: 'Personel / Ürün',
                value: '$totalStaff / $totalProducts',
                icon: Icons.group_work,
                color: EmarColors.gold,
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text('Şubeler Arası Dağılım & Karşılaştırma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Tüm şubelerin aktiflik ve sipariş hacmi', style: TextStyle(fontSize: 12, color: EmarColors.espresso.withValues(alpha: 0.6))),
          const SizedBox(height: 12),

          ...branches.map((b) {
            final branchOrders = app.orderHistory.where((o) => o.branch == b.name).length;
            final maxOrd = totalOrders == 0 ? 1 : totalOrders;
            final ratio = (branchOrders / maxOrd).clamp(0.05, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: EmarColors.oatDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: b.isActive ? EmarColors.moss : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '$branchOrders sp.',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Canlı Sipariş Akışı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${app.orderHistory.length} Kayıt', style: TextStyle(fontSize: 12, color: EmarColors.espresso.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 8),

          // Branch Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Tümü', ...branches.map((b) => b.name)].map((b) {
                final selected = b == _orderBranchFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(b, style: const TextStyle(fontSize: 11.5)),
                    selected: selected,
                    selectedColor: EmarColors.espresso,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : EmarColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _orderBranchFilter = b),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Builder(
            builder: (context) {
              final filtered = app.orderHistory.where((o) => _orderBranchFilter == 'Tümü' || o.branch == _orderBranchFilter).toList();
              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: EmarColors.oatDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Bu şubeye ait henüz sipariş kaydı yok.'),
                );
              }
              return Column(
                children: filtered.take(10).map((o) => _OrderRowTile(order: o)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: PERSONEL YÖNETİMİ (STAFF)
  // ==========================================
  Widget _buildStaffTab(AppState app) {
    final staffList = app.staff.staffList.where((s) {
      final matchesSearch = s.fullName.toLowerCase().contains(_staffSearch.toLowerCase()) ||
          (s.email?.toLowerCase().contains(_staffSearch.toLowerCase()) ?? false);
      final matchesRole = _staffRoleFilter == 'Tümü' ||
          (_staffRoleFilter == 'Barista' && s.role == 'barista') ||
          (_staffRoleFilter == 'Şube Müdürü' && s.role == 'branch_manager') ||
          (_staffRoleFilter == 'Admin' && s.role == 'admin');
      return matchesSearch && matchesRole;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EmarColors.espresso,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Personel Ekle'),
        onPressed: () => _openAddStaffDialog(app),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Personel ara (isim veya e-posta)...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: EmarColors.oatDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (v) => setState(() => _staffSearch = v),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Tümü', 'Barista', 'Şube Müdürü', 'Admin'].map((role) {
                final selected = role == _staffRoleFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(role, style: const TextStyle(fontSize: 11.5)),
                    selected: selected,
                    selectedColor: EmarColors.espresso,
                    labelStyle: TextStyle(color: selected ? Colors.white : EmarColors.espresso, fontWeight: FontWeight.w700),
                    onSelected: (_) => setState(() => _staffRoleFilter = role),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (staffList.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Kriterlere uygun personel bulunamadı.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...staffList.map((s) {
              final branchName = s.branchName ?? app.getBranchName(s.branchId);
              final isBarista = s.role == 'barista';
              final isManager = s.role == 'branch_manager';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EmarColors.oatDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isBarista ? EmarColors.moss.withValues(alpha: 0.2) : EmarColors.espresso.withValues(alpha: 0.2),
                      child: Icon(
                        isBarista ? Icons.coffee : (isManager ? Icons.manage_accounts : Icons.shield),
                        color: isBarista ? EmarColors.moss : EmarColors.espresso,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          if (s.email != null)
                            Text(s.email!, style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.6))),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isBarista ? EmarColors.moss : EmarColors.espresso,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(s.roleLabel, style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              if (branchName.isNotEmpty)
                                Text('📍 $branchName', style: TextStyle(fontSize: 10.5, color: EmarColors.espresso.withValues(alpha: 0.7))),
                            ],
                          ),
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
  // TAB 3: ŞUBE YÖNETİMİ (BRANCHES)
  // ==========================================
  Widget _buildBranchesTab(AppState app) {
    final branches = app.branches.where((b) {
      return b.name.toLowerCase().contains(_branchSearch.toLowerCase()) ||
          (b.address?.toLowerCase().contains(_branchSearch.toLowerCase()) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EmarColors.espresso,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Şube Ekle'),
        onPressed: () => _openAddBranchDialog(app),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Şube ara (isim veya adres)...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: EmarColors.oatDark,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (v) => setState(() => _branchSearch = v),
          ),
          const SizedBox(height: 14),

          ...branches.map((b) {
            final branchStaffCount = app.staff.staffList.where((s) => s.branchId == b.id).length;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: EmarColors.oatDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: b.isActive ? Colors.black.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Switch(
                        value: b.isActive,
                        activeThumbColor: EmarColors.moss,
                        onChanged: (v) async {
                          await app.updateBranch(b.id, isActive: v);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${b.name} ${v ? "aktif edildi." : "pasife alındı."}')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (b.address != null && b.address!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('📍 ${b.address}', style: TextStyle(fontSize: 11.5, color: EmarColors.espresso.withValues(alpha: 0.7))),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.isActive ? EmarColors.moss.withValues(alpha: 0.15) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          b.isActive ? 'Açık / Aktif' : 'Kapalı / Pasif',
                          style: TextStyle(
                            fontSize: 10,
                            color: b.isActive ? EmarColors.moss : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('👥 $branchStaffCount Personel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _openAddBranchDialog(app, editBranch: b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: EmarColors.paprika, size: 18),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Şubeyi Sil'),
                              content: Text('${b.name} şubesi silinecek. Onaylıyor musunuz?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: EmarColors.paprika),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Sil', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await app.deleteBranch(b.id);
                          }
                        },
                      ),
                    ],
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
  // TAB 4: MENÜ & ÜRÜNLER (MENU CATALOG)
  // ==========================================
  Widget _buildMenuTab(AppState app) {
    final products = app.menu.products.where((p) {
      final matchesCat = _selectedCategory == null || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_menuSearch.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EmarColors.espresso,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ürün Ekle'),
        onPressed: () => _openAddProductDialog(app),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
            onChanged: (v) => setState(() => _menuSearch = v),
          ),
          const SizedBox(height: 10),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('Tümü', style: TextStyle(fontSize: 11.5)),
                    selected: _selectedCategory == null,
                    selectedColor: EmarColors.espresso,
                    labelStyle: TextStyle(color: _selectedCategory == null ? Colors.white : EmarColors.espresso, fontWeight: FontWeight.w700),
                    onSelected: (_) => setState(() => _selectedCategory = null),
                  ),
                ),
                ...ProductCategory.values.map((cat) {
                  final selected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat.label, style: const TextStyle(fontSize: 11.5)),
                      selected: selected,
                      selectedColor: EmarColors.espresso,
                      labelStyle: TextStyle(color: selected ? Colors.white : EmarColors.espresso, fontWeight: FontWeight.w700),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          ...products.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EmarColors.oatDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Text(p.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text('${p.price.toStringAsFixed(0)}₺ · ${p.category.label}', style: const TextStyle(fontSize: 11.5, color: EmarColors.paprika, fontWeight: FontWeight.w600)),
                        if (p.isLoyaltyEligible)
                          const Text('⭐ Sadakat Geçerli', style: TextStyle(fontSize: 10, color: EmarColors.moss, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _openAddProductDialog(app, editProduct: p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: EmarColors.paprika, size: 18),
                    onPressed: () => _deleteProduct(app, p),
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
  // TAB 5: AYARLAR & KAMPANYALAR (SETTINGS)
  // ==========================================
  Widget _buildSettingsTab(AppState app) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // System Settings Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: EmarColors.oatDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, size: 20, color: EmarColors.espresso),
                  SizedBox(width: 8),
                  Text('Sistem & Sadakat Parametreleri', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              if (_isLoadingSettings)
                const Center(child: CircularProgressIndicator())
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bedava Kahve Eşiği (Sipariş Adedi):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    DropdownButton<int>(
                      value: _loyaltyThreshold,
                      items: [3, 5, 7, 10].map((v) => DropdownMenuItem(value: v, child: Text('$v Sipariş'))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _loyaltyThreshold = v);
                      },
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('KDV / Vergi Oranı (%):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    DropdownButton<double>(
                      value: _taxRate,
                      items: [1.0, 8.0, 10.0, 18.0, 20.0].map((v) => DropdownMenuItem(value: v, child: Text('%${v.toStringAsFixed(0)}'))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _taxRate = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: EmarColors.espresso),
                    onPressed: _isSavingSettings ? null : () => _saveSettings(app),
                    child: _isSavingSettings
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Ayarları Kaydet'),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Campaigns Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Aktif Kampanyalar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Yeni Kampanya'),
              onPressed: () => _openAddCampaignDialog(app),
            ),
          ],
        ),
        const SizedBox(height: 6),

        ...app.campaignList.map((c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EmarColors.oatDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(c.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: EmarColors.paprika,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(c.badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text(c.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: EmarColors.paprika),
                onPressed: () => app.removeCampaign(c),
              ),
            ],
          ),
        )),
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
              Text(title, style: TextStyle(fontSize: 11, color: EmarColors.espresso.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
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

class _OrderRowTile extends StatelessWidget {
  final OrderRecord order;
  const _OrderRowTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.manualStatus == OrderStatus.completed
        ? EmarColors.moss
        : (order.manualStatus == OrderStatus.preparing ? Colors.orange : EmarColors.paprika);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: EmarColors.oatDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sipariş #${order.id.length >= 6 ? order.id.substring(0, 6) : order.id} · ${order.branch}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                Text(order.itemsSummary, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: EmarColors.espresso.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Text('${order.total.toStringAsFixed(0)}₺', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}
