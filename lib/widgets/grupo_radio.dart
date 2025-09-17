import 'package:flutter/material.dart';

class GrupoRadio<T> extends StatelessWidget {
 
  final String title;

  final T groupValue;


  final ValueChanged<T?> onChanged;


  final Map<T, String> options;

  const GrupoRadio({
    super.key,
    required this.title,
    required this.groupValue,
    required this.onChanged,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),

        ...options.entries.map((entry) {
          return RadioListTile<T>(
            title: Text(entry.value),
            value: entry.key,
            groupValue: groupValue,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }
}

