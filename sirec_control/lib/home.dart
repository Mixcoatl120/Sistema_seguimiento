// --- Archivo principal de navegación y control de permisos ---
import 'package:flutter/material.dart';

// --- Importaciones de Firebase ---
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Importaciones del proyecto ---
import 'package:sirec_control/familia/familia.dart';
import 'package:sirec_control/usuario/perfil.dart';
import 'package:sirec_control/opciones.dart';
import 'mapa/mapa.dart';
import 'login_page.dart';
import 'reutilizables/boton_panico.dart';
import 'audios_page.dart';
import 'Componentes/menu_barra.dart';

// --- Utilidades de sistema y persistencia ---
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? user;
  String? familiaId;
  String rol = '';
  bool cargando = true;

  bool ubicacionConcedida = false;
  bool microfonoConcedido = false;
  bool camaraConcedida = false;
  bool mostrandoDialogo = false; // evita abrir 2 dialogs
  static const String _prefsKeyPopup = "popup_permisos_mostrado";

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _inicio();
  }

  Future<void> _inicio() async {
    // Secuencia de inicialización: verificación de popup, permisos y carga de datos.
    await _verificarPopupYMostrarSiCorresponde();
    await _verificarPermisos();
    await _cargarFamilia();
  }

  // --- Gestión del diálogo informativo inicial ---
  Future<void> _verificarPopupYMostrarSiCorresponde() async {
    final prefs = await SharedPreferences.getInstance();
    final bool yaMostrado = prefs.getBool(_prefsKeyPopup) ?? false;

    // Si los permisos ya están otorgados, no es necesario mostrar el diálogo.
    final bool loc = await Permission.locationWhenInUse.isGranted ||
        await Permission.location.isGranted;
    final bool mic = await Permission.microphone.isGranted;
    final bool cam = await Permission.camera.isGranted;

    if (loc && mic && cam) {
      // Marcar como mostrado si ya se tienen los permisos.
      if (!yaMostrado) await prefs.setBool(_prefsKeyPopup, true);
      return;
    }

    // Mostrar diálogo informativo solo la primera vez.
    if (!yaMostrado && !mostrandoDialogo) {
      // Pequeño retardo para asegurar que el contexto de Flutter esté listo.
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      mostrandoDialogo = true;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: const Text("Permisos necesarios"),
            content: const Text(
              "Para que Sirec Control funcione correctamente necesitamos:\n\n"
              "• Acceso a la ubicación: Para mostar tu ubicación en el mapa\n"
              "• Acceso al micrófono: Grabar audio cuando actives el botón de pánico.\n\n"
              "• Acceso a la cámara: Tomar fotografías de evidencia en emergencias.\n\n"
              "Si decides no conceder estos permisos, la aplicación no funcionará correctamente.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  mostrandoDialogo = false;

                  // Evitar que el diálogo aparezca en futuros inicios.
                  await prefs.setBool(_prefsKeyPopup, true);

                  // Solicitar permisos al confirmar.
                  await _pedirPermisos();
                  await _verificarPermisos();

                  // Actualizar la interfaz para reflejar los cambios de permisos.
                  if (mounted) setState(() {});
                },
                child: const Text("Aceptar"),
              ),
            ],
          );
        },
      );
    }
  }

  // --- Solicitud de permisos al sistema operativo ---
  Future<void> _pedirPermisos() async {
  
  // 1. Permiso de ubicación en primer plano.
  final locResult = await Permission.locationWhenInUse.request();

  // 2. Intentar solicitar precisión alta si la ubicación básica fue concedida.
  if (locResult.isGranted) {
    if (await Permission.location.isDenied) {
      await Permission.location.request(); // FINE LOCATION
    }
  }

  // 3. Permiso de micrófono para grabación en emergencias.
  await Permission.microphone.request();

  // 4. Permiso de cámara para fotos en emergencias.
  await Permission.camera.request();

  // 4. Permiso de notificaciones para Android 13+.
  if (await Permission.notification.isDenied ||
      await Permission.notification.isLimited ||
      await Permission.notification.isRestricted) {
    await Permission.notification.request();
  }

  // Tiempo de espera para que el sistema procese las respuestas.
  await Future.delayed(const Duration(milliseconds: 200));
}

  // --- Comprobación del estado actual de los permisos ---
  Future<void> _verificarPermisos() async {
    final statusLocWhenInUse = await Permission.locationWhenInUse.status;
    final statusLocFine = await Permission.location.status;
    final statusMic = await Permission.microphone.status;
    final statusCam = await Permission.camera.status;

    // Consideramos ubicación válida si es general o precisa.
    final bool locOk = statusLocWhenInUse.isGranted ||
        statusLocWhenInUse.isLimited ||
        statusLocFine.isGranted;

    setState(() {
      ubicacionConcedida = locOk;
      microfonoConcedido = statusMic.isGranted;
      camaraConcedida = statusCam.isGranted;
    });
  }

  // --- Recuperación de datos de usuario y familia desde Firestore ---
  Future<void> _cargarFamilia() async {
    if (user == null) {
      setState(() {
        familiaId = null;
        rol = '';
        cargando = false;
      });
      return;
    }

    try {
      final familiasSnapshot =
          await FirebaseFirestore.instance.collection('familias').get();

      for (var doc in familiasSnapshot.docs) {
        final miembros = List<Map<String, dynamic>>.from(doc['miembros']);
        final miembro =
            miembros.firstWhere((m) => m['uid'] == user!.uid, orElse: () => {});

        if (miembro.isNotEmpty) {
          setState(() {
            familiaId = doc.id;
            rol = (miembro['rol'] ?? '').toString().trim().toLowerCase();
            cargando = false;
          });
          return;
        }
      }

      setState(() {
        familiaId = null;
        rol = '';
        cargando = false;
      });
    } catch (e) {
      debugPrint("Error al cargar familia: $e");
      setState(() {
        familiaId = null;
        rol = '';
        cargando = false;
      });
    }
  }

  // --- Interfaz: Pantalla de bloqueo por falta de ubicación ---
  Widget _pantallaSinUbicacion() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            "La aplicación necesita permisos de ubicación para funcionar.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              await _pedirPermisos();
              await _verificarPermisos();
              if (mounted) setState(() {});
            },
            child: const Text("Conceder permisos"),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await openAppSettings();
            },
            child: const Text("Abrir ajustes"),
          ),
        ],
      ),
    );
  }

  // --- Interfaz: Aviso de micrófono no disponible ---
  Widget _bannerMicrofono() {
    return Container(
      width: double.infinity,
      color: Colors.orangeAccent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.mic_off, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Micrófono desactivado. No se grabará audio en emergencias.",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OpcionesPage()),
              ).then((_) => _verificarPermisos());
            },
            child: const Text("ACTIVAR", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
          )
        ],
      ),
    );
  }

  // --- Interfaz: Aviso de cámara no disponible ---
  Widget _bannerCamara() {
    return Container(
      width: double.infinity,
      color: Colors.redAccent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.camera_enhance_outlined, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Cámara desactivada. No podrás capturar fotos de emergencia.",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OpcionesPage()),
              ).then((_) => _verificarPermisos());
            },
            child: const Text("ACTIVAR", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
          )
        ],
      ),
    );
  }

  // --- Gestión de cierre de sesión ---
  void _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // --- Interfaz: Menú lateral de navegación ---
  Widget _drawerMenu() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[900]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/icon/sirec_black.png", height: 80, width: 80),
                const SizedBox(height: 20),
                Text(
                  'Bienvenido, ${user?.email ?? 'Usuario'}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Perfil'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PerfilPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('Familia'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const Familia()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_music),
            title: const Text('Archivos de Emergencia'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AudiosPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Opciones'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OpcionesPage()),
              ).then((_) => _verificarPermisos()); // Refrescar al volver
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  // --- Renderizado condicional del contenido principal ---
  Widget _contenidoPrincipal() {
    if (!ubicacionConcedida) {
      return _pantallaSinUbicacion();
    }

    if (familiaId == null) {
      return const Center(
        child: Text(
          'No perteneces a ninguna familia. Crea o únete a una desde el menú.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    Widget content = MapaPage(familiaId: familiaId!);

    // Si faltan permisos opcionales pero útiles, se muestran los banners informativos.
    if (!microfonoConcedido || !camaraConcedida) {
      return Column(
        children: [
          if (!microfonoConcedido) _bannerMicrofono(),
          if (!camaraConcedida) _bannerCamara(),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Inicio", actions: []),
      drawer: ubicacionConcedida ? _drawerMenu() : null,
      body: SafeArea(
        child: cargando
            ? const Center(child: CircularProgressIndicator())
            : _contenidoPrincipal(),
      ),
    );
  }
}
