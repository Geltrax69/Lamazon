import '../models/product.dart';
import 'catalog.dart';

enum OrderStatus { placed, packed, onTheWay, delivered, cancelled }

extension OrderStatusInfo on OrderStatus {
  String get title => switch (this) {
        OrderStatus.placed => 'Order placed',
        OrderStatus.packed => 'Packed',
        OrderStatus.onTheWay => 'On the way',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };
}

class OrderLine {
  final Product product;
  final int qty;
  const OrderLine(this.product, this.qty);
}

class Order {
  final String id;
  final DateTime placedAt;
  final OrderStatus status;
  final List<OrderLine> lines;
  final String address;

  const Order({
    required this.id,
    required this.placedAt,
    required this.status,
    required this.lines,
    required this.address,
  });

  double get total =>
      lines.fold<double>(0, (s, l) => s + l.product.price * l.qty) + 15;
  int get itemCount => lines.fold(0, (s, l) => s + l.qty);
}

Product _p(String name) => products.firstWhere((p) => p.name == name);

// ponytail: sample order history. Replace with an API when orders are real.
final sampleOrders = <Order>[
  Order(
    id: 'LMZ-10234',
    placedAt: DateTime.now().subtract(const Duration(minutes: 22)),
    status: OrderStatus.onTheWay,
    address: '12 Green Avenue, Model Town, Jalandhar',
    lines: [
      OrderLine(_p('Fresh Milk 1L'), 2),
      OrderLine(_p('Multigrain Bread'), 1),
      OrderLine(_p('Farm Eggs (12)'), 1),
    ],
  ),
  Order(
    id: 'LMZ-10218',
    placedAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
    status: OrderStatus.delivered,
    address: '12 Green Avenue, Model Town, Jalandhar',
    lines: [
      OrderLine(_p('Wireless Headphones'), 1),
    ],
  ),
  Order(
    id: 'LMZ-10197',
    placedAt: DateTime.now().subtract(const Duration(days: 6)),
    status: OrderStatus.delivered,
    address: '12 Green Avenue, Model Town, Jalandhar',
    lines: [
      OrderLine(_p('Farmhouse Pizza'), 1),
      OrderLine(_p('Cold Coffee & Brownie'), 2),
    ],
  ),
  Order(
    id: 'LMZ-10150',
    placedAt: DateTime.now().subtract(const Duration(days: 11)),
    status: OrderStatus.cancelled,
    address: '12 Green Avenue, Model Town, Jalandhar',
    lines: [
      OrderLine(_p('Classic Analog Watch'), 1),
    ],
  ),
];
