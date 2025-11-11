import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/nominatim.dart';

class LocationInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final void Function(Map<String, dynamic>) onSelected;

  const LocationInput({
    Key? key,
    required this.controller,
    required this.label,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      // tampilan textfield
      builder: (context, textController, focusNode) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.location_on),
          ),
        );
      },

      // callback pencarian
      suggestionsCallback: (pattern) async {
        if (pattern.trim().isEmpty) return [];
        return await NominatimService.searchPlace(pattern);
      },

      // cara menampilkan hasil
      itemBuilder: (context, suggestion) {
        return ListTile(
          title: Text(
            suggestion['display_name'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },

      // ketika user memilih suggestion
      onSelected: (suggestion) {
        controller.text = suggestion['display_name'] ?? '';
        onSelected(suggestion);
      },

      // tampil jika tidak ada hasil
      emptyBuilder: (context) =>
          const Center(child: Text('Lokasi tidak ditemukan')),
    );
  }
}
