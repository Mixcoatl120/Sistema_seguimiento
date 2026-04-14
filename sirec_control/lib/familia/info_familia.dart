import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sirec_control/Componentes/menu_barra.dart';

class InfoFamilia extends StatelessWidget {
  const InfoFamilia({super.key});

  Future<DocumentSnapshot?> _obtenerFamiliaDelUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // 🔹 Buscamos el usuario en la colección "usuarios"
    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return null;
    final idFamilia = userDoc.data()?['idfamilia'];

    if (idFamilia == null || idFamilia.isEmpty) return null;

    // 🔹 Retornamos el documento de la familia correspondiente
    return FirebaseFirestore.instance.collection('familias').doc(idFamilia).get();
  }

  Future<void> _expulsarMiembro(BuildContext context, String miembroUid, String idFamilia, List miembrosActuales) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expulsar miembro'),
        content: const Text('¿Estás seguro de que deseas eliminar a este miembro de la familia?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Expulsar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // 1. Remover de la lista de miembros de la familia
      final nuevosMiembros = miembrosActuales.where((m) => m['uid'] != miembroUid).toList();
      await FirebaseFirestore.instance.collection('familias').doc(idFamilia).update({
        'miembros': nuevosMiembros
      });

      // 2. Limpiar el idfamilia en el documento del usuario expulsado
      await FirebaseFirestore.instance.collection('usuarios').doc(miembroUid).update({
        'idfamilia': ''
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Miembro expulsado correctamente')));
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      debugPrint("Error al expulsar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: customAppBar('Información de tu Familia'),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _obtenerFamiliaDelUsuario(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'No se encontró información de familia.\nEs posible que ya no pertenezcas a ninguna.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final miembros = (data['miembros'] as List?) ?? [];

          // ✅ Puede editar si es padre o administrador
          final puedeEditar = miembros.any(
            (m) =>
                m['uid'] == user?.uid &&
                (m['rol'] == 'padre' || m['rol'] == 'administrador'),
          );

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ListTile(
                  title: Text(data['nombre'] ?? 'Sin nombre'),
                  subtitle: Text('Código familiar: ${data['codigo'] ?? 'N/A'}'),
                ),
              ),
              const SizedBox(height: 10),
              ...miembros.map<Widget>((m) {
                final miembro = m as Map<String, dynamic>;
                final esActual = miembro['uid'] == user?.uid;
                final rolActual = miembro['rol'] ?? 'miembro';

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(miembro['nombre'] ?? 'Sin nombre'),
                    subtitle: Text('Rol actual: $rolActual'),
                    trailing: (puedeEditar && !esActual) 
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final nuevoRol = await mostrarSelectorDeRol(context, rolActual);
                                if (nuevoRol == null || nuevoRol == rolActual) return;

                                final confirmar = await mostrarConfirmacion(
                                  context,
                                  miembro['nombre'] ?? 'miembro',
                                  rolActual,
                                  nuevoRol,
                                );

                                if (confirmar) {
                                  final nuevosMiembros = miembros
                                      .map((m) => Map<String, dynamic>.from(m))
                                      .toList();
                                  final idx = nuevosMiembros
                                      .indexWhere((mm) => mm['uid'] == miembro['uid']);

                                  if (idx != -1) {
                                    nuevosMiembros[idx]['rol'] = nuevoRol;
                                    await snapshot.data!.reference
                                        .update({'miembros': nuevosMiembros});

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Rol cambiado correctamente'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    (context as Element).markNeedsBuild();
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_remove, color: Colors.red),
                              onPressed: () => _expulsarMiembro(context, miembro['uid'], snapshot.data!.id, miembros),
                            ),
                          ],
                        )
                      : null,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  /// 🔹 Selector de nuevo rol
  Future<String?> mostrarSelectorDeRol(
      BuildContext context, String rolActual) async {
    String? seleccionado = rolActual;
    final roles = ['administrador', 'miembro', 'padre', 'hijo'];

    // Evita error si el rol no está en la lista
    if (!roles.contains(seleccionado)) {
      seleccionado = 'miembro';
    }

    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Seleccionar nuevo rol'),
            content: DropdownButton<String>(
              value: seleccionado,
              isExpanded: true,
              items: roles
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  seleccionado = v;
                });
              },
            ),
            actions: [
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context, null),
              ),
              ElevatedButton(
                child: const Text('Aceptar'),
                onPressed: () => Navigator.pop(context, seleccionado),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔹 Confirmación antes de aplicar cambio
  Future<bool> mostrarConfirmacion(
    BuildContext context,
    String nombre,
    String rolActual,
    String nuevoRol,
  ) async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar cambio'),
            content: Text(
              '¿Deseas cambiar el rol de "$nombre"\n'
              'de "$rolActual" a "$nuevoRol"?',
            ),
            actions: [
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                child: const Text('Confirmar'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        )) ??
        false;
  }
}
