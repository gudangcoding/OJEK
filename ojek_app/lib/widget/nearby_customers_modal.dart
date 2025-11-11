import 'package:flutter/material.dart';

class NearbyCustomersModal extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final void Function(Map<String, dynamic>) onSelect;

  const NearbyCustomersModal({
    super.key,
    required this.customers,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Ambil maksimal 5 terdekat (urut berdasarkan distance_km jika tersedia)
    final list = List<Map<String, dynamic>>.from(customers);
    list.sort(
      (a, b) => ((a['distance_km'] ?? 0) as num).compareTo(
        (b['distance_km'] ?? 0) as num,
      ),
    );
    final top5 = list.take(5).toList();

    return AlertDialog(
      title: const Text('Pelanggan Terdekat'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: top5.length,
          itemBuilder: (context, index) {
            final c = top5[index];
            final name = c['name'] ?? 'Tanpa Nama';
            final dist = c['distance_km'];
            final phone = c['phone'];
            final online = c['status_online'] == true;
            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Icon(
                  Icons.person_pin_circle,
                  color: online ? Colors.blue : Colors.grey,
                ),
                title: Text(name.toString()),
                subtitle: Text(
                  dist == null
                      ? 'Jarak: -'
                      : 'Jarak: ${((dist as num).toDouble()).toStringAsFixed(2)} km${phone != null && phone.toString().isNotEmpty ? '\nTelp: $phone' : ''}',
                ),
                trailing: ElevatedButton(
                  onPressed: () => onSelect(c),
                  child: const Text('Lihat'),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
