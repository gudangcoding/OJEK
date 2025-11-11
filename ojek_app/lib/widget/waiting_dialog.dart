import 'package:flutter/material.dart';

class WaitingDialog extends StatelessWidget {
  final VoidCallback? onCancel;
  final bool cancelEnabled;
  const WaitingDialog({super.key, this.onCancel, this.cancelEnabled = true});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: const Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 12),
          Expanded(child: Text('Menunggu respon driver...')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: cancelEnabled ? onCancel : null,
          child: Text(cancelEnabled ? 'Cancel' : 'Cancel (nonaktif)'),
        ),
      ],
    );
  }
}