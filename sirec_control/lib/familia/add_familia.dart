import 'package:flutter/material.dart';

import 'package:sirec_control/Componentes/menu_barra.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinFamilyPage extends StatefulWidget {
  const JoinFamilyPage({super.key});

  @override
  JoinFamilyPageState createState() => JoinFamilyPageState();
}

class JoinFamilyPageState extends State<JoinFamilyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();

  Future<void> _joinFamily() async {
    if (_formKey.currentState!.validate()) {
      final code = _codeController.text.trim();
      try {
        // Buscar familia con el código ingresado
        final query = await FirebaseFirestore.instance
            .collection('familias')
            .where('codigo', isEqualTo: code)
            .limit(1)
            .get();
        if (!mounted) return;
        if (query.docs.isNotEmpty) {
          final familiaDoc = query.docs.first;
          final familiaRef = familiaDoc.reference;
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuario no autenticado.')),
            );
            return;
          }
          final nombreUsuario = user.displayName ?? user.email ?? 'Usuario';
          // Obtener miembros actuales (array de mapas)
          final data = familiaDoc.data();
          final miembros = data.containsKey('miembros') ? List<Map<String, dynamic>>.from(data['miembros']) : [];
          // Verificar si ya está en la familia
          final yaEsMiembro = miembros.any((m) => m['uid'] == user.uid);
          if (!yaEsMiembro) {
            miembros.add({
              'uid': user.uid,
              'nombre': nombreUsuario,
              'rol': 'miembro',
              'fechaIngreso': DateTime.now().toIso8601String(),
            });
            await familiaRef.update({'miembros': miembros});
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('¡Código válido! Te has unido a la familia.')),
          );
        } else {
          // Código inválido
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Código incorrecto o inexistente.')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al validar el código: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar('Unirse a una Familia'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ingresa el código de la familia:',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Código de Familia',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa un código';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _joinFamily,
                child: Text('Unirse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}