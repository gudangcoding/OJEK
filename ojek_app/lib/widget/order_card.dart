import 'package:flutter/material.dart';

class OrderCard extends StatelessWidget {
  final dynamic order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final Map<String, dynamic>? customerInfo;

  const OrderCard({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onReject,
    this.customerInfo,
  });

  @override
  Widget build(BuildContext context) {
    final custName = customerInfo?['name'];
    final custRating = customerInfo?['rating'];
    final custDist = customerInfo?['distance_km'];
    return Card(
      child: ListTile(
        title: Text('Order #${order.id} - ${order.distance} km'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (custName != null) Text('Customer: $custName'),
            if (custRating != null)
              Text('Rating: ${custRating.toStringAsFixed(1)}'),
            if (custDist != null)
              Text('Jarak ke customer: ${custDist.toStringAsFixed(2)} km'),
            Text('Harga Rp ${order.totalPrice}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onAccept,
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Accept',
            ),
            IconButton(
              onPressed: onReject,
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Reject',
            ),
          ],
        ),
      ),
    );
  }
}
