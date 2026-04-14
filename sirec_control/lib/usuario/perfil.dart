import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sirec_control/Componentes/menu_barra.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Controladores para mostrar los valores en los TextFields
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();

  // Información de familia y suscripción
  String _nombreFamilia = '';
  String _codigoFamilia = '';
  String _rolFamilia = '';
  bool _subActiva = false;
  String _tipoPlan = '';
  DateTime? _expiracionSub;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  // Obtener datos del usuario
  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchUserDoc() async {
    final User? user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user', message: 'No hay usuario autenticado');
    return _firestore.collection('usuarios').doc(user.uid).get();
  }

  // Obtener familia y suscripción
  Future<void> _fetchFamiliaYSub() async {
  final uid = _auth.currentUser!.uid;

  // Traer todas las familias
  final familiasQuery = await _firestore.collection('familias').get();

  // Buscar la familia donde el usuario esté como miembro
  for (var doc in familiasQuery.docs) {
    final data = doc.data();
    final miembros = List.from(data['miembros'] ?? []);

    final miembro = miembros.firstWhere(
      (m) => m['uid'] == uid,
      orElse: () => null,
    );

    if (miembro != null) {
      _nombreFamilia = data['nombre'] ?? '';
      _codigoFamilia = data['codigo'] ?? '';
      _rolFamilia = miembro['rol'] ?? '';
      // Suscripción / prueba
      _subActiva = data['pruebaActiva'] ?? false;
      _expiracionSub = data['fechaExpiracionPrueba'] != null
          ? DateTime.tryParse(data['fechaExpiracionPrueba'])
          : null;
      break; // Si encontró la familia, ya no sigue buscando
    }
  }

  // También puedes traer info del plan si lo guardas en el documento del usuario
  final userDoc = await _firestore.collection('usuarios').doc(uid).get();
  final userData = userDoc.data();
  if (userData != null) {
    _tipoPlan = userData['plan'] ?? '';
  }
}


  void _populateControllers(Map<String, dynamic> data) {
    _nombreCtrl.text = data['nombre']?.toString() ?? '';
    _correoCtrl.text = data['correo']?.toString() ?? _auth.currentUser?.email ?? '';
    _telefonoCtrl.text = data['telefono']?.toString() ?? '';
    _direccionCtrl.text = data['direccion']?.toString() ?? '';
  }

  // Widget para mostrar información de familia y suscripción
  Widget _infoFamiliaYSub() {
  // Solo el padre o administrador puede ver la info familiar y suscripción
  if (_rolFamilia.toLowerCase() == 'padre' || _rolFamilia.toLowerCase() == 'administrador') {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_nombreFamilia.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Información de la Familia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Text('Nombre: $_nombreFamilia', style: const TextStyle(fontSize: 16)),
          Text('Código: $_codigoFamilia', style: const TextStyle(fontSize: 16)),
          Text('Rol: $_rolFamilia', style: const TextStyle(fontSize: 16)),
        ],
        const SizedBox(height: 20),
        const Text(
          'Suscripción',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        Text(
          _subActiva
              ? 'Activa ($_tipoPlan) ${_expiracionSub != null ? "- expira: ${_expiracionSub!.toLocal().toString().split(' ')[0]}" : ""}'
              : 'Inactiva',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  // Si es hijo, solo muestra un pequeño texto o nada
  return const SizedBox.shrink();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Perfil"),
      body: FutureBuilder(
        future: Future.wait([
          _fetchUserDoc(),
          _fetchFamiliaYSub(),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Datos de usuario
          final userDoc = snapshot.data![0] as DocumentSnapshot<Map<String, dynamic>>;
          final data = userDoc.data() ?? <String, dynamic>{};
          _populateControllers(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 44,
                  child: Text(
                    (_nombreCtrl.text.isNotEmpty) ? _nombreCtrl.text[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(height: 20),
                // TextFields
                TextFormField(controller: _nombreCtrl, enabled: false, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _correoCtrl, enabled: false, decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _telefonoCtrl, enabled: false, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _direccionCtrl, enabled: false, decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder())),
                // Información de familia y suscripción
                _infoFamiliaYSub(),
              ],
            ),
          );
        },
      ),
    );
  }
}


