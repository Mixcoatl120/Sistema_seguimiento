import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sirec_control/home.dart';

class MiFamiliaPage extends StatefulWidget {
  const MiFamiliaPage({super.key});

  @override
  State<MiFamiliaPage> createState() => _MiFamiliaPageState();
}

class _MiFamiliaPageState extends State<MiFamiliaPage> {
  final TextEditingController nombreFamiliaController = TextEditingController();

  // Genera un código único de 8 caracteres
  String generarCodigo(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // Crea la familia en Firestore
  Future<void> crearFamilia(String nombreFamilia) async {
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;
    final nombreUsuario = user.displayName ?? 'Usuario';
    
    final codigo = generarCodigo(8);
    final fechaCreacion = DateTime.now();
    final fechaExpiracionPrueba = fechaCreacion.add(const Duration(days: 15));

    await FirebaseFirestore.instance.collection('familias').add({
      'nombre': nombreFamilia,
      'codigo': codigo,
      'miembros': [
        {
          'uid': uid,
          'nombre': nombreUsuario,
          'rol': 'padre',
          'fechaIngreso': fechaCreacion.toIso8601String()
        }
      ],
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'pruebaActiva': true,
      'fechaExpiracionPrueba': fechaExpiracionPrueba.toIso8601String()
    });
  }

  // Muestra diálogo para elegir prueba o plan
  void mostrarDialogoPlan(String nombreFamilia) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¡Familia creada!'),
          content: const Text('Puedes iniciar una prueba gratuita de 15 días o comprar un plan.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
                crearFamilia(nombreFamilia); // Inicia prueba gratuita
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prueba gratuita iniciada'))
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
              child: const Text('Prueba de 15 días'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Aquí iría tu lógica para comprar un plan
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Función de compra aún no implementada'))
                );
              },
              child: const Text('Comprar Plan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Familia')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: nombreFamiliaController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la familia',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final nombreFamilia = nombreFamiliaController.text.trim();
                if (nombreFamilia.isNotEmpty) {
                  mostrarDialogoPlan(nombreFamilia);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debes escribir un nombre'))
                  );
                }
              },
              child: const Text('Crear Familia'),
            ),
          ],
        ),
      ),
    );
  }
}