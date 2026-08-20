import re

with open('lib/screens/staff/barista_screen.dart', 'r') as f:
    content = f.read()

# _completedToday tanımını kaldır
content = re.sub(r'\s*int _completedToday = 3;\n', '\n', content)

# _advance içindeki artırma işlemini kaldır
advance_block = """  void _advance(OrderRecord o, AppState app) {
    if (o.manualStatus == OrderStatus.preparing) {
      _completedToday++;
    }
    app.advanceOrderStatus(o);
  }"""
new_advance_block = """  void _advance(OrderRecord o, AppState app) {
    app.advanceOrderStatus(o);
  }"""
content = content.replace(advance_block, new_advance_block)

# build metodunun içine hesaplamayı ekle ve stringi güncelle
build_signature = "  Widget build(BuildContext context) {"
build_replacement = """  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    
    // Gerçek API verisi üzerinden bugün tamamlananları hesapla
    final now = DateTime.now();
    final int completedToday = app.orders.activeBaristaOrders.where((o) {
      if (o.manualStatus != OrderStatus.completed) return false;
      final d = o.createdAt; // completed_at modeli frontend'de yoksa createdAt veya updated_at kullanırız. 
      // EmarKafe OrderRecord'da completedAt var mı bakalım (yoksa createdAt baz alınır, bugün oluşturulup tamamlananlar)
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
"""
content = content.replace("  Widget build(BuildContext context) {\n    final app = context.watch<AppState>();", build_replacement)

# Widget ağacındaki stringi güncelle
content = content.replace("Text('Bugün Tamamlanan: $_completedToday'", "Text('Bugün Tamamlanan: $completedToday'")

with open('lib/screens/staff/barista_screen.dart', 'w') as f:
    f.write(content)
