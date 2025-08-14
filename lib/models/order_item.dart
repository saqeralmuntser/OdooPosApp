import 'product.dart';

class OrderItem {
  final Product product;
  int quantity;
  double get total => product.price * quantity;

  OrderItem({
    required this.product,
    this.quantity = 1,
  });

  void incrementQuantity() {
    quantity++;
  }

  void decrementQuantity() {
    if (quantity > 1) {
      quantity--;
    }
  }

  void setQuantity(int newQuantity) {
    if (newQuantity >= 1) {
      quantity = newQuantity;
    }
  }

  OrderItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return OrderItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
