import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sirec_control/Componentes/menu_barra.dart';
import 'package:sirec_control/familia/add_familia.dart';
import 'package:sirec_control/familia/crear_familia.dart';
import 'package:sirec_control/familia/info_familia.dart';

class Familia extends StatefulWidget {
  const Familia({super.key});

  @override
  State<Familia> createState() => _FamiliaState();
}

class _FamiliaState extends State<Familia> {
  String? _idFamilia;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _verificarEstadoFamilia();
  }

  Future<void> _verificarEstadoFamilia() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _idFamilia = doc.data()?['idfamilia'];
          _cargando = false;
        });
      }
    }
  }

  // Lista de opciones del menú
  final List<Map<String, dynamic>> opciones = [
    {
      'titulo': 'Miembros',
      'icono': Icons.family_restroom,
      'ruta': const InfoFamilia(), 
      'requiereFamilia': true,
    },
    {
      'titulo': 'Crear familia',
      'icono': Icons.add,
      'ruta': const MiFamiliaPage(),
      'bloquearSiTiene': true,
    },
    {
      'titulo': 'Unirse a una familia',
      'icono': Icons.group_add_rounded,
      'ruta': const JoinFamilyPage(),
      'bloquearSiTiene': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool tieneFamilia = _idFamilia != null && _idFamilia!.isNotEmpty;

    return Scaffold(
      appBar: customAppBar("Familia", actions: []),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: opciones.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // dos columnas
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1, // forma cuadrada
          ),
          itemBuilder: (context, index) {
            final opcion = opciones[index];
            final bool estaBloqueado = (opcion['bloquearSiTiene'] == true && tieneFamilia) ||
                                     (opcion['requiereFamilia'] == true && !tieneFamilia);

            return GestureDetector(
              onTap: () {
                if (estaBloqueado) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tieneFamilia 
                        ? "Ya perteneces a una familia." 
                        : "Primero debes unirte o crear una familia."),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => opcion['ruta']),
                  ).then((_) => _verificarEstadoFamilia());
                }
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                color: estaBloqueado ? Colors.grey.shade200 : Colors.blue.shade50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opcion['icono'],
                      size: 48,
                      color: estaBloqueado ? Colors.grey : Colors.blue.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      opcion['titulo'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: estaBloqueado ? Colors.grey : Colors.black87,
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
