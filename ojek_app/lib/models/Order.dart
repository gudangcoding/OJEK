class OrderModel {
  final int id;
  final int customerId;
  final int? driverId;
  final double latPickup;
  final double lonPickup;
  final String pickupAddress;
  final double latDropoff;
  final double lonDropoff;
  final String dropoffAddress;
  final double totalPrice;
  final double distance;
  final String status;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.driverId,
    required this.latPickup,
    required this.lonPickup,
    required this.pickupAddress,
    required this.latDropoff,
    required this.lonDropoff,
    required this.dropoffAddress,
    required this.totalPrice,
    required this.distance,
    required this.status,
  });

  factory OrderModel.fromJson(Map<String, dynamic> j) {
    return OrderModel(
      id: j['id'] as int,
      customerId: j['customer_id'] as int,
      driverId: j['driver_id'] as int?,
      latPickup: (j['lat_pickup'] as num).toDouble(),
      lonPickup: (j['lon_pickup'] as num).toDouble(),
      pickupAddress: j['pickup_address'] as String,
      latDropoff: (j['lat_dropoff'] as num).toDouble(),
      lonDropoff: (j['lon_dropoff'] as num).toDouble(),
      dropoffAddress: j['dropoff_address'] as String,
      totalPrice: (j['total_price'] as num).toDouble(),
      distance: (j['distance'] as num).toDouble(),
      status: j['status'] as String,
    );
  }
}