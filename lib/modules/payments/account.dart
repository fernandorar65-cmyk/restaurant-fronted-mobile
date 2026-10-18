import 'dart:math';

import '../../core/utils/money.dart';
import '../orders/order_status_labels.dart';
import '../orders/types.dart';
import 'types.dart';

class ProductBalance {
  const ProductBalance({required this.product, required this.allocated, required this.pending});

  final OrderedProduct product;

  /// Pagado específicamente para este producto.
  final double allocated;
  final double pending;
}

class AccountSummary {
  const AccountSummary({required this.total, required this.paid, required this.remaining, required this.products});

  /// Total cobrable: excluye productos rechazados y cancelados.
  final double total;

  /// Suma de pagos en estado `paid` (los fallidos, cancelados o reembolsados no cuentan).
  final double paid;
  final double remaining;
  final List<ProductBalance> products;
}

bool countsAsPaid(Payment payment) => payment.status == 'paid';

AccountSummary computeAccount(List<OrderedProduct> products, List<Payment> payments) {
  final billable = products.where((product) => isBillableProduct(product.status)).toList();
  final paidPayments = payments.where(countsAsPaid).toList();
  final total = roundMoney(billable.fold<double>(0, (sum, product) => sum + product.subtotal));
  final paid = roundMoney(paidPayments.fold<double>(0, (sum, payment) => sum + payment.amount));

  final allocatedById = <String, double>{};

  for (final payment in paidPayments) {
    for (final allocation in payment.allocations) {
      allocatedById[allocation.orderedProductId] = (allocatedById[allocation.orderedProductId] ?? 0) + allocation.amount;
    }
  }

  return AccountSummary(
    total: total,
    paid: paid,
    remaining: roundMoney(max(total - paid, 0)),
    products: billable.map((product) {
      final allocated = roundMoney(allocatedById[product.id] ?? 0);
      return ProductBalance(product: product, allocated: allocated, pending: roundMoney(max(product.subtotal - allocated, 0)));
    }).toList(),
  );
}
