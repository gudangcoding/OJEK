import 'dart:async';
import 'package:flutter/material.dart';

class OrderModal extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final int initialSeconds;
  final Future<void> Function() onAccept;
  final VoidCallback onCancel;
  final Map<String, dynamic>? customerInfo;
  final double? driverDistanceKm;
  final double? estimatedPickupMinutes;
  final VoidCallback? onViewPickup;
  final VoidCallback? onViewDropoff;

  const OrderModal({
    super.key,
    required this.orderData,
    this.initialSeconds = 15,
    required this.onAccept,
    required this.onCancel,
    this.customerInfo,
    this.driverDistanceKm,
    this.estimatedPickupMinutes,
    this.onViewPickup,
    this.onViewDropoff,
  });

  @override
  State<OrderModal> createState() => _OrderModalState();
}

class _OrderModalState extends State<OrderModal> {
  late int secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    secondsLeft = widget.initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        secondsLeft -= 1;
      });
      if (secondsLeft <= 0) {
        _timer?.cancel();
        if (mounted) {
          // Anggap timeout sebagai cancel agar state modal di DriverPage ikut tertutup
          try {
            widget.onCancel();
          } catch (_) {}
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.orderData['id'];
    final price = widget.orderData['total_price'];
    final dist = widget.orderData['distance'];
    final pickupAddr = widget.orderData['pickup_address'];
    final dropoffAddr = widget.orderData['dropoff_address'];
    final custName = widget.customerInfo?['name'];
    final custRating = widget.customerInfo?['rating'];
    final custDist = widget.customerInfo?['distance_km'];
    final custPhone = widget.customerInfo?['phone'];
    final avatarUrl = widget.customerInfo?['avatar_url'];
    final vehiclePlate = widget.customerInfo?['vehicle_plate'];
    final vehicleModel = widget.customerInfo?['vehicle_model'];
    final driverDistKm = widget.driverDistanceKm;
    final etaMin = widget.estimatedPickupMinutes;
    return AlertDialog(
      title: const Text('Order baru masuk'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        (avatarUrl is String && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl)
                        : null,
                    child:
                        (avatarUrl == null ||
                            (avatarUrl is String && avatarUrl.isEmpty))
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$id',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (custName != null) Text('Customer: $custName'),
                        if (custPhone != null &&
                            custPhone.toString().isNotEmpty)
                          Text('Telp: $custPhone'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (custRating != null)
                Text('Rating: ${custRating.toStringAsFixed(1)}'),
              if (custDist != null)
                Text('Jarak ke customer: ${custDist.toStringAsFixed(2)} km'),
              if (driverDistKm != null)
                Text(
                  'Jarak Anda ke pickup: ${driverDistKm.toStringAsFixed(2)} km',
                ),
              if (etaMin != null)
                Text(
                  'Perkiraan waktu ke pickup: ${etaMin.toStringAsFixed(0)} menit',
                ),
              if (vehiclePlate != null || vehicleModel != null)
                Text(
                  'Kendaraan: '
                  '${vehicleModel ?? '-'} '
                  '${vehiclePlate == null ? '' : '($vehiclePlate)'}',
                ),
              const SizedBox(height: 8),
              if (pickupAddr != null) Text('Pickup: $pickupAddr'),
              if (dropoffAddr != null) Text('Dropoff: $dropoffAddr'),
              if (dist != null) Text('Jarak rute: $dist km'),
              if (price != null) Text('Harga: Rp $price'),
              const SizedBox(height: 8),
              Text('Auto close dalam $secondsLeft detik'),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onViewPickup != null)
          TextButton(
            onPressed: widget.onViewPickup,
            child: const Text('Lihat Pickup'),
          ),
        if (widget.onViewDropoff != null)
          TextButton(
            onPressed: widget.onViewDropoff,
            child: const Text('Lihat Dropoff'),
          ),
        TextButton(
          onPressed: () {
            _timer?.cancel();
            widget.onCancel();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            _timer?.cancel();
            await widget.onAccept();
            // Modal akan ditutup oleh handler event 'accepted' di halaman driver
          },
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
