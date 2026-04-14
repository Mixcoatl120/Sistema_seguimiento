import 'package:flutter/material.dart';

class InputsPersonalizados extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isPassword;

  const InputsPersonalizados({
    super.key,
    required this.label,
    required this.controller,
    this.isPassword = false,
  });

  @override
  State<InputsPersonalizados> createState() => _ShadowTextFieldState();
}

class _ShadowTextFieldState extends State<InputsPersonalizados> {
  bool _obscureText = true; // Oculto por defecto

  @override
  void initState() {
    super.initState();
    if (!widget.isPassword) _obscureText = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscureText,
        decoration: InputDecoration(
          labelText: widget.label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.blue[900],
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}



