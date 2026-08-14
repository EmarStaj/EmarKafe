
import 'package:emar_kafe/models/product.dart';

class CartItem {
  final String cartItemId; // Backend's cart_items ID, nullable for local-only items
  final Product product;
  final int quantity;
  final List<ProductOption> selectedOptions;

  CartItem({
    required this.cartItemId,
    required this.product,
    required this.quantity,
    this.selectedOptions = const [],
  });
  
  double get unitPrice {
    double total = product.price;
    for (final opt in selectedOptions) {
      total += opt.priceDelta;
    }
    return total < 0 ? 0 : total; // Negatif price_delta ihtimalinin UI tarafinda kontrolu
  }
  
  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({
    String? cartItemId,
    Product? product,
    int? quantity,
    List<ProductOption>? selectedOptions,
  }) {
    return CartItem(
      cartItemId: cartItemId ?? this.cartItemId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions ?? this.selectedOptions,
    );
  }
}
