import 'package:flutter/material.dart';

Future<void> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Aceptar',
            style: TextStyle(color: Color.fromARGB(255, 215, 221, 226)),
          ),
        ),
      ],
    ),
  );
}
