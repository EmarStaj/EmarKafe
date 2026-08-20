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
  final _cardHolderCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

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

  void _addBalance() {
    final holder = _cardHolderCtrl.text.trim();
    final cardNum = _cardNumberCtrl.text.replaceAll(' ', '').trim();
    final expiry = _expiryCtrl.text.trim();
    final cvv = _cvvCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;

    if (holder.isEmpty) {
      _showWarning('Lütfen kart üzerindeki isim ve soyismi girin.');
      return;
    }

    if (cardNum.length != 16 || int.tryParse(cardNum) == null) {
      _showWarning('Lütfen 16 haneli geçerli bir kart numarası girin.');
      return;
    }

    if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').hasMatch(expiry)) {
      _showWarning('Lütfen geçerli bir Son Kullanma Tarihi (AA/YY) girin.');
      return;
    }

    if (cvv.length != 3 || int.tryParse(cvv) == null) {
      _showWarning('Lütfen 3 haneli CVV güvenlik kodunu girin.');
      return;
    }

    if (amount <= 0) {
      _showWarning('Lütfen geçerli bir yükleme tutarı girin.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: EmarColors.paprika),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      context.read<AppState>().addWalletBalance(amount);
      _amountCtrl.clear();
      _cardNumberCtrl.clear();
      _cardHolderCtrl.clear();
      _expiryCtrl.clear();
      _cvvCtrl.clear();

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${amount.toStringAsFixed(0)}₺ bakiye başarıyla yüklendi!'),
          backgroundColor: EmarColors.moss,
          duration: const Duration(seconds: 2),
        ),
      );
    });
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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

              TextField(
                controller: _cardHolderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kart Üzerindeki İsim',
                  hintText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _cardNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kart Numarası',
                  hintText: '16 Haneli Kart Numarası',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                maxLength: 16,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'SKT (AA/YY)',
                        hintText: '12/28',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      keyboardType: TextInputType.datetime,
                      maxLength: 5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yüklenecek Tutar (₺)',
                  hintText: '100',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Quick amount presets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [50, 100, 200, 500].map((val) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _amountCtrl.text = val.toString()),
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
                    onPressed: _addBalance,
                    child: const Text('Güvenli Ödeme Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
