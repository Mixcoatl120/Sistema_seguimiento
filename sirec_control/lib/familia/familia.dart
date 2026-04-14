import 'package:flutter/material.dart';
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
  // Lista de opciones del menú
  final List<Map<String, dynamic>> opciones = [
    {
      'titulo': 'Miembros',
      'icono': Icons.family_restroom,
      'ruta': const InfoFamilia(), 
    },
    {
      'titulo': 'crear familia',
      'icono': Icons.add,
      'ruta': const MiFamiliaPage(),
    },
    {
      'titulo': 'Unirse a una familia',
      'icono': Icons.group_add_rounded,
      'ruta': const JoinFamilyPage(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Familia", actions: []),
      body: Padding(
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
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => opcion['ruta']),
                );
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                color: Colors.blue.shade50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opcion['icono'],
                      size: 48,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      opcion['titulo'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
