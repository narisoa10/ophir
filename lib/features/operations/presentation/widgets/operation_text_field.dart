import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OperationTextField extends StatelessWidget {
  const OperationTextField({
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.keyboardType,
    this.inputFormatters,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: labelText, hintText: hintText),
    );
  }
}
