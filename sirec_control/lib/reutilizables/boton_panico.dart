import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sirec_control/servicios/servicio_grabacion.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../audios_page.dart';

class BotonPanico extends StatefulWidget {
  final String familiaId;

  const BotonPanico({super.key, required this.familiaId});

  @override
  State<BotonPanico> createState() => _BotonPanicoState();
}

class _BotonPanicoState extends State<BotonPanico> {

  final ServicioGrabacion _grabacion = ServicioGrabacion();

  // --- Variables de estado de la emergencia ---
  bool _isPanicActive = false;
  bool _isProcessing = false;

  // --- Temporizadores para rastreo activo y pasivo ---
  Timer? _panicTimer;   // Rastreo activo: cada 10 segundos
  Timer? _passiveTimer; // Rastreo pasivo: cada minuto
  String? _panicDocumentId; 
  Position? _ultimaPosicionRuta;
  DateTime? _ultimoTimestampRuta;

  @override
  void initState() {
    super.initState();
    // Inicializar rastreo y servicios de fondo al cargar el widget.
    _startPassiveTracking();
    _initBackgroundService();

    final user = FirebaseAuth.instance.currentUser;
    FlutterBackgroundService().invoke('setPanic', {
      'familiaId': widget.familiaId,
      'uid': user?.uid,
      'panic': _isPanicActive,
      'panicDocId': _panicDocumentId,
    });
  }

  @override
  void dispose() {
    // Limpieza de temporizadores para prevenir fugas de memoria.
    _panicTimer?.cancel();
    _passiveTimer?.cancel();
    super.dispose();
  }

  // --- Lógica de seguimiento pasivo (cada 1 minuto) ---
  void _startPassiveTracking() {
    _passiveTimer?.cancel();
    _passiveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _actualizarUbicacionPasiva();
    });
  }

  // --- Detener seguimiento pasivo ---
  void _stopPassiveTracking() {
    _passiveTimer?.cancel();
  }

  // --- Configuración y arranque del servicio en segundo plano ---
  Future<void> _initBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,

        notificationChannelId: 'sirec_tracking_channel',
        initialNotificationTitle: 'Sirec está rastreando tu ubicación',
        initialNotificationContent: 'Tu ubicación se está registrando en segundo plano.',
        foregroundServiceNotificationId: 1001,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  // --- Controlador para ejecución en segundo plano en iOS ---
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }

  // --- Punto de entrada principal para el servicio aislado (Background isolate) ---
  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {

    WidgetsFlutterBinding.ensureInitialized();
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Sirec activo",
        content: "Servicio iniciado correctamente",
      );
    }

    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase init error: $e');
    }

    service.on('setPanic').listen((event) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final familiaId = event?['familiaId'] as String?;
        final uid = event?['uid'] as String?;
        final panic = event?['panic'] as bool? ?? false;
        final docId = event?['panicDocId'] as String?;

        if (familiaId != null) prefs.setString('familiaId', familiaId);
        if (uid != null) prefs.setString('uid', uid);
        prefs.setBool('panicActive', panic);
        if (docId != null) prefs.setString('panicDocId', docId);
      } catch (e) {
        print('setPanic handler error: $e');
      }
    });

    // Bucle principal del servicio: alterna entre rastreo activo de emergencia y pasivo rutinario.
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final panicActive = prefs.getBool('panicActive') ?? false;
        final familiaId = prefs.getString('familiaId');
        final uid = prefs.getString('uid');
        final panicDocId = prefs.getString('panicDocId');

        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        if (panicActive && panicDocId != null) {
          final punto = {
            'lat': position.latitude,
            'lon': position.longitude,
            'timestamp': Timestamp.now(),
          };
          await FirebaseFirestore.instance.collection('ubicaciones_panico').doc(panicDocId).update({
            'ruta': FieldValue.arrayUnion([punto])
          });
        } else if (familiaId != null && uid != null) {
          final lastPassive = prefs.getInt('lastPassiveTs') ?? 0;
          final nowTs = DateTime.now().millisecondsSinceEpoch;
          if (nowTs - lastPassive >= 60000) {
            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final famRef = FirebaseFirestore.instance.collection('familias').doc(familiaId);
              final snapshot = await transaction.get(famRef);
              if (!snapshot.exists) return;
              final List<dynamic> miembros = List.from(snapshot.data()?['miembros'] ?? []);
              final idx = miembros.indexWhere((m) => m['uid'] == uid);
              if (idx != -1) {
                miembros[idx]['latitud'] = position.latitude;
                miembros[idx]['longitud'] = position.longitude;
                transaction.update(famRef, {'miembros': miembros});
              }
            });
            prefs.setInt('lastPassiveTs', nowTs);
          }
        }
      } catch (e) {
        print('Background service periodic error: $e');
      }
    });
  }

  // --- Control central del modo pánico (activar/desactivar) ---
  void _togglePanicMode() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final bool willBeActive = !_isPanicActive;

    if (willBeActive) {
      
      // Inicio de protocolo de emergencia.
      _stopPassiveTracking();

      try {
            await _grabacion.iniciar();
          } catch (e) {
            print('Error al iniciar grabación: $e');
          }

      final bool success = await _iniciarSesionDePanico();
      if (success && mounted) {
        setState(() => _isPanicActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Alerta de pánico activada! Enviando ubicación.')),
        );

        _panicTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          _agregarUbicacionASesion();
        });
      }
    } else {
      
      // Finalización de protocolo de emergencia.
      final audioPath = await _grabacion.detener();
      if (audioPath != null) {
        print('Audio guardado en: $audioPath');
      }

      _panicTimer?.cancel();

      if (_panicDocumentId != null) {
        FirebaseFirestore.instance.collection('ubicaciones_panico').doc(_panicDocumentId).update({
          'estado': 'finalizado',
          'finTimestamp': FieldValue.serverTimestamp(),
        });
        final user = FirebaseAuth.instance.currentUser;
        FlutterBackgroundService().invoke('setPanic', {
          'familiaId': widget.familiaId,
          'uid': user?.uid,
          'panic': false,
          'panicDocId': '',
        });
      }

      if (mounted) {
        setState(() {
          _isPanicActive = false;
          _panicDocumentId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El modo pánico ha sido desactivado.')),
        );
      }
      
      _startPassiveTracking();
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  // --- Actualización de ubicación en tiempo real en Firestore ---
  Future<void> _actualizarUbicacionPasiva() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.familiaId.isEmpty) return;

    try {
      final position = await _determinarPosicion();
      final familiaRef = FirebaseFirestore.instance.collection('familias').doc(widget.familiaId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(familiaRef);
        if (!snapshot.exists) return;

        final List<dynamic> miembros = List.from(snapshot.data()?['miembros'] ?? []);
        final int index = miembros.indexWhere((m) => m['uid'] == user.uid);

        if (index != -1) {
          miembros[index]['latitud'] = position.latitude;
          miembros[index]['longitud'] = position.longitude;
          transaction.update(familiaRef, {'miembros': miembros});
        }
      });
      await _guardarRutaPasiva(position);
    } catch (e) {
      print("Error al actualizar ubicación pasiva: $e");
    }
  }

  // --- Creación de una nueva sesión de emergencia en la base de datos ---
  Future<bool> _iniciarSesionDePanico() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final position = await _determinarPosicion();
      final puntoUbicacion = {
        'lat': position.latitude,
        'lon': position.longitude,
        'timestamp': Timestamp.now(),
      };

      final docRef = await FirebaseFirestore.instance.collection('ubicaciones_panico').add({
        'uid': user.uid,
        'familiaId': widget.familiaId,
        'usuarioEmail': user.email ?? 'No disponible',
        'inicioTimestamp': FieldValue.serverTimestamp(),
        'estado': 'activo',
        'ruta': [puntoUbicacion],
      });

      _panicDocumentId = docRef.id;

      FlutterBackgroundService().invoke('setPanic', {
        'familiaId': widget.familiaId,
        'uid': user.uid,
        'panic': true,
        'panicDocId': _panicDocumentId,
      });
      return true;
    } catch (e) {
      print("Error al iniciar sesión de pánico: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al iniciar pánico: ${e.toString()}')));
      }
      return false;
    }
  }

  // --- Registro de puntos de GPS en la sesión de pánico activa ---
  Future<void> _agregarUbicacionASesion() async {
     if (_panicDocumentId == null) {
      print("Error: No hay una sesión de pánico activa para añadir ubicación.");
      return;
    }

    try {
      final position = await _determinarPosicion();
      final puntoUbicacion = {
        'lat': position.latitude,
        'lon': position.longitude,
        'timestamp': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('ubicaciones_panico').doc(_panicDocumentId).update({
        'ruta': FieldValue.arrayUnion([puntoUbicacion]),
      });

    } catch (e) {
      print("Error al agregar ubicación a la sesión: $e");
    }
  }

  // --- Obtener coordenadas actuales con validación de servicios ---
  Future<Position> _determinarPosicion() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están desactivados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      openAppSettings();
      return Future.error('Los permisos de ubicación están denegados permanentemente.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }



  Future<void> _guardarRutaPasiva(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔹 FILTRO 1: precisión
    if (position.accuracy > 30) {
      print("Punto descartado por mala precisión: ${position.accuracy}");
      return;
    }

    if (_ultimaPosicionRuta != null && _ultimoTimestampRuta != null) {

      double distancia = Geolocator.distanceBetween(
        _ultimaPosicionRuta!.latitude,
        _ultimaPosicionRuta!.longitude,
        position.latitude,
        position.longitude,
      );

      // Filtro de distancia: evitar registros si el usuario está estático.
      if (distancia < 10) {
        print("Punto descartado por distancia mínima: $distancia m");
        return;
      }

      int segundos = position.timestamp!
          .difference(_ultimoTimestampRuta!)
          .inSeconds;

      if (segundos > 0) {
        double velocidad = distancia / segundos;

        // Filtro de velocidad: descartar saltos de GPS irreales.
        if (velocidad > 40) {
          print("Punto descartado por velocidad imposible: $velocidad m/s");
          return;
        }
      }
    }

    _ultimaPosicionRuta = position;
    _ultimoTimestampRuta = position.timestamp;

    final hoy = DateTime.now().toString().substring(0, 10);

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('rutas')
        .doc(hoy)
        .collection('puntos')
        .add({
      'lat': position.latitude,
      'lon': position.longitude,
      'ts': FieldValue.serverTimestamp(),
    });

  }

// --- Interfaz visual del botón de pánico ---
@override
Widget build(BuildContext context) {
  final Color buttonColor = _isPanicActive ? Colors.orange : Colors.red;
  final String buttonText = _isPanicActive ? 'Detener' : 'Pánico';

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 250,
        height: 250,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isProcessing ? Colors.grey : buttonColor,
            shape: const CircleBorder(),
            elevation: 8,
          ),
          onPressed: _togglePanicMode,
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Center(
                  child: Text(
                    buttonText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
      const SizedBox(height: 60),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionItem(
            icon: Icons.camera_alt,
            label: "Foto",
            onPressed: _tomarFoto,
          ),
          _buildActionItem(
            icon: Icons.folder_shared,
            label: "Archivos",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudiosPage())),
          ),
        ],
      )
    ],
  );
}

Widget _buildActionItem({required IconData icon, required String label, required VoidCallback onPressed}) {
  return Column(
    children: [
      IconButton(
        icon: Icon(icon, size: 35, color: Colors.blue[900]),
        onPressed: onPressed,
      ),
      Text(label, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w600)),
    ],
  );
}

Future<void> _tomarFoto() async {
  // Verificar el estado actual del permiso de cámara
  var status = await Permission.camera.status;

  if (status.isPermanentlyDenied) {
    // Si el usuario marcó "No volver a preguntar", debemos enviarlo a Ajustes
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Permiso Requerido"),
          content: const Text("El acceso a la cámara está desactivado. Para capturar evidencia, por favor actívalo en los ajustes del sistema."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text("Ir a Ajustes"),
            ),
          ],
        ),
      );
    }
    return;
  }

  if (!status.isGranted) {
    // Solicitar el permiso (muestra el popup del sistema)
    status = await Permission.camera.request();
    if (!status.isGranted) return; // Si el usuario cancela el popup, no hacemos nada
  }

  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.camera);

  if (image != null) {
    final directory = await getApplicationDocumentsDirectory();
    final String path = '${directory.path}/panic_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await image.saveTo(path);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de emergencia guardada.')),
      );
    }
  }
}

}
