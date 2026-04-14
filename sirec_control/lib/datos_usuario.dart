import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home.dart';

import 'Componentes/menu_barra.dart';

class ProfileDataScreen extends StatefulWidget {
  final String uid; // UID del usuario
  const ProfileDataScreen({required this.uid, super.key});

  @override
  ProfileDataScreenState createState() => ProfileDataScreenState();
}

class ProfileDataScreenState extends State<ProfileDataScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _correoController = TextEditingController();

  bool _isLoading = false;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      // Si algún campo no pasa la validación, se muestran los errores
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor completa toda la información")),
      );
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final correo = _correoController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .set({
        'uid': widget.uid,    
        'nombre': name,
        'telefono': phone,
        'correo': correo,
        'role': "",

      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil guardado con éxito")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _correoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("datos de perfil"),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction, // valida mientras escribes
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "El nombre es obligatorio";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _correoController,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "El correo es obligatorio";
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return "Correo inválido";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "El teléfono es obligatorio";
                  }
                  if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                    return "Debe contener exactamente 10 dígitos";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Guardar perfil"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

