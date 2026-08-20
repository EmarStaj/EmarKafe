import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/pressable_scale.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardHolderCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool _autoValidate = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: EmarColors.paprika,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addBalance() async {
    setState(() => _autoValidate = true);

    if (!_formKey.currentState!.validate()) {
      _showWarning('Lütfen tüm kart ve tutar alanlarını eksiksiz ve doğru doldurun.');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      _showWarning('Lütfen geçerli bir yükleme tutarı girin.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AppState>().addWalletBalance(amount);

      if (!mounted) return;

      _amountCtrl.clear();
      _cardNumberCtrl.clear();
      _cardHolderCtrl.clear();
      _expiryCtrl.clear();
      _cvvCtrl.clear();
      setState(() => _autoValidate = false);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${amount.toStringAsFixed(0)}₺ bakiye başarıyla yüklendi!'),
          backgroundColor: EmarColors.moss,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showWarning('Bakiye yükleme hatası: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = context.watch<AppState>().walletBalance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cüzdanım'),
        backgroundColor: EmarColors.oat,
      ),
      backgroundColor: EmarColors.oat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [EmarColors.espresso, EmarColors.moss],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('EMAR Kafe Cüzdan Bakiyesi', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('${balance.toStringAsFixed(2)}₺', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Bakiye Yükle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: EmarColors.espresso)),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _cardHolderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kart Üzerindeki İsim *',
                    hintText: 'Ad Soyad',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (val) {
                    final text = val?.trim() ?? '';
                    if (text.isEmpty) return 'Kart üzerindeki isim boş bırakılamaz';
                    if (text.length < 3) return 'Geçerli bir isim ve soyisim giriniz';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _cardNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kart Numarası *',
                    hintText: '16 Haneli Kart Numarası',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  validator: (val) {
                    final text = val?.replaceAll(' ', '').trim() ?? '';
                    if (text.isEmpty) return 'Kart numarası boş bırakılamaz';
                    if (text.length != 16 || int.tryParse(text) == null) {
                      return '16 haneli geçerli kart numarası giriniz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SKT (AA/YY) *',
                          hintText: '12/28',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        keyboardType: TextInputType.datetime,
                        maxLength: 5,
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (text.isEmpty) return 'SKT boş bırakılamaz';
                          if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').hasMatch(text)) {
                            return 'Geçerli format: AA/YY';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvCtrl,
                        decoration: const InputDecoration(
                          labelText: 'CVV *',
                          hintText: '123',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 3,
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (text.isEmpty) return 'CVV boş bırakılamaz';
                          if (text.length != 3 || int.tryParse(text) == null) {
                            return '3 haneli CVV giriniz';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Yüklenecek Tutar (₺) *',
                    hintText: '100',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    final num = double.tryParse(val?.trim() ?? '');
                    if (num == null || num <= 0) {
                      return 'Geçerli bir yükleme tutarı giriniz (min 1₺)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Quick amount presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [50, 100, 200, 500].map((val) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _amountCtrl.text = val.toString();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: EmarColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: EmarColors.espresso.withValues(alpha: 0.15)),
                        ),
                        child: Text('+$val₺', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                PressableScale(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: EmarColors.paprika),
                      onPressed: _isLoading ? null : _addBalance,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Güvenli Ödeme Yap',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
