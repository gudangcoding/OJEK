import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/nominatim.dart';

class LocationInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final void Function(Map<String, dynamic>) onSelected;
  final String? initialText;

  const LocationInput({
    super.key,
    required this.controller,
    required this.label,
    required this.onSelected,
    this.initialText,
  });

  @override
  State<LocationInput> createState() => _LocationInputState();
}

class _LocationInputState extends State<LocationInput> {
  // Inisialisasi awal agar tidak terjadi LateInitializationError saat onSelected dipanggil cepat
  TextEditingController _internalController = TextEditingController();
  FocusNode _internalFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      // tampilan textfield
      builder: (context, textController, focusNode) {
        // simpan referensi controller internal dari TypeAhead
        _internalController = textController;
        _internalFocusNode = focusNode;
        // Sinkronisasi nilai awal bila disediakan
        if (widget.initialText != null &&
            widget.initialText!.isNotEmpty &&
            textController.text != widget.initialText) {
          textController.text = widget.initialText!;
          widget.controller.text = widget.initialText!;
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
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
        try {
          // Perbarui teks input agar sesuai dengan pilihan (pakai controller internal TypeAhead)
          final name = (suggestion['display_name'] ?? '').toString();
          _internalController.text = name;
          // Sinkronkan juga ke controller eksternal agar listener di luar tetap terpicu
          widget.controller.text = name;
          // Tutup keyboard/overlay agar UX terasa selesai
          _internalFocusNode.unfocus();
          // Teruskan ke callback pemanggil
          widget.onSelected(suggestion);
        } catch (err) {
          // Lindungi dari error di callback agar tidak mematikan UI autocomplete
          debugPrint('LocationInput onSelected error: $err');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memproses lokasi terpilih')),
          );
        }
      },

      // tampil jika tidak ada hasil
      emptyBuilder: (context) =>
          const Center(child: Text('Lokasi tidak ditemukan')),
    );
  }

  @override
  void didUpdateWidget(covariant LocationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    try {
      // Perbarui teks bila initialText berubah
      final newText = widget.initialText ?? '';
      if (newText.isNotEmpty && newText != _internalController.text) {
        _internalController.text = newText;
        widget.controller.text = newText;
      }
    } catch (_) {}
  }
}
