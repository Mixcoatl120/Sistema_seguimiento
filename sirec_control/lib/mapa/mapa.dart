import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sirec_control/reutilizables/boton_panico.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../audios_page.dart';
import 'dart:async';

class MapaPage extends StatefulWidget {
  final String familiaId;
  const MapaPage({super.key, required this.familiaId});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final MapController mapController = MapController();
  //variables 
  LatLng? userLocation; //locacion del usuario
  Stream<Position>? positionStream; //stream de posicion
  List<Marker> childMarkers = []; //marcadores de los hijos
  StreamSubscription<DocumentSnapshot>? familySubscription; // suscripcion a la familia
  bool mostrarFamilia = false; //mostrar panel de control
  List<Map<String, dynamic>> miembrosFamilia = []; //miembros de la familia
  Map<String, List<LatLng>> rutasFamilia = {};
  Map<String, StreamSubscription<QuerySnapshot>> rutasSubscriptions = {};
  bool _mapReady = false;


  final String mapboxAccessToken =
      'pk.eyJ1IjoiY29ycGhtIiwiYSI6ImNtZ3BndTd5dDF5ZXMybG9rMzJ3ZDB2MDMifQ._klqp-DG_d-6aX-lF1GYWg';
  final String mapStyle = 'mapbox/streets-v12';

  @override
  void initState() {
    super.initState();
    _verificarPermisoUbicacionYaOtorgado();
    _subscribeFamily();
  }

  @override
  void dispose() {
    familySubscription?.cancel();
    for (var sub in rutasSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  //verificando permisos
  Future<void> _verificarPermisoUbicacionYaOtorgado() async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse) {
    _startTracking(); // solo iniciar si ya existen permisos
  }
}

 
  // Seguimiento de ubicación del usuario
  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return; // NO pedir permisos aquí
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    );

    positionStream!.listen((Position position) {
      final nuevaUbicacion = LatLng(position.latitude, position.longitude);

      setState(() {
        userLocation = nuevaUbicacion;
      });

// mover cámara solo la primera vez
      if (_mapReady) {
        mapController.move(nuevaUbicacion, 16);
      }
    });
  }


  /// Suscripción a la familia del usuario
  Future<void> _subscribeFamily() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.familiaId.isEmpty) return;

    print('🟢 Suscribiéndose a la familia: ${widget.familiaId}');

    // 🔹 Suscribirse al documento de la familia
    familySubscription = FirebaseFirestore.instance
        .collection('familias')
        .doc(widget.familiaId)
        .snapshots()
        .listen((doc) {
      final familyData = doc.data();
      if (familyData == null) return;

      final miembros = familyData['miembros'] as List<dynamic>?;

      if (miembros == null) return;
      
      if (!mounted) return;
      setState(() {
        miembrosFamilia = miembros.map((m) => Map<String, dynamic>.from(m)).toList();
      });

      for (var miembro in miembrosFamilia) {
        final uid = miembro['uid'];
        if (uid != null && !rutasSubscriptions.containsKey(uid)) {
          _escucharRutaDeMiembro(uid);
        }
      }

      List<Marker> nuevosMarcadores = [];

      for (var miembro in miembros) {
        final rol = miembro['rol']?.toString().trim().toLowerCase() ?? '';
        final miembroUid = miembro['uid']?.toString();
        final lat = miembro['latitud'];
        final lon = miembro['longitud'];

        if (lat != null && lon != null && miembroUid != user.uid) {
          try {
            final latNum = double.parse(lat.toString());
            final lonNum = double.parse(lon.toString());

            nuevosMarcadores.add(
              Marker(
                point: LatLng(latNum, lonNum),
                width: 45,
                height: 45,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.blueAccent,
                  size: 40,
                ),
              ),
            );
          } catch (e) {
            debugPrint('❌ Error al convertir coordenadas de hijo: $e');
          }
        }
      }

      setState(() {
        childMarkers = nuevosMarcadores;
      });
    });
  }

  void _centrarEnUsuario() { //centrar en la ubicacion del usuario
    if (userLocation != null) {
      mapController.move(userLocation!, 16);
    }
  }

  //funciones de familia

  void _escucharRutaDeMiembro(String uid) {
    final hoy = DateTime.now().toString().substring(0, 10);

    rutasSubscriptions[uid] = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('rutas')
        .doc(hoy)
        .collection('puntos')
        .orderBy('ts')
        .snapshots()
        .listen((snapshot) {

      List<LatLng> puntos = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'];
        final lon = data['lon'];

        if (lat != null && lon != null) {
          puntos.add(LatLng(
            (lat as num).toDouble(),
            (lon as num).toDouble(),
          ));
        }
      }

      setState(() {
        rutasFamilia[uid] = puntos;
      });
    });
  }

  void _centrarEnMiembro(Map<String, dynamic> miembro) {
    final lat = miembro['latitud'];
    final lon = miembro['longitud'];

    if (lat == null || lon == null) return;

    try {
      final latNum = double.parse(lat.toString());
      final lonNum = double.parse(lon.toString());

      mapController.move(LatLng(latNum, lonNum), 16);
    } catch (_) {}
  }

  Future<void> _tomarFoto() async {
    var status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Permiso Requerido"),
            content: const Text("El acceso a la cámara está desactivado. Actívalo en ajustes."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              TextButton(onPressed: () { Navigator.pop(ctx); openAppSettings(); }, child: const Text("Ir a Ajustes")),
            ],
          ),
        );
      }
      return;
    }
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/panic_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await image.saveTo(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto de emergencia guardada.')));
      }
    }
  }

  // Construccion de la interfaz 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: userLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(19.4326, -99.1332), // centro temporal CDMX
                    initialZoom: 5,
                    onMapReady: (){
                      _mapReady = true;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                      additionalOptions: {
                        'accessToken': mapboxAccessToken,
                        'id': mapStyle,
                      },
                    ),
                    PolylineLayer(
                      polylines: rutasFamilia.entries
                          .where((entry) => entry.value.length > 1) // 🔥 mínimo 2 puntos
                          .map((entry) {
                        return Polyline(
                          points: entry.value,
                          strokeWidth: 4,
                          color: Colors.green,
                        );
                      }).toList(),
                    ),
                    CircleLayer(
                      circles: [
                        // 🔴 Usuario actual
                        CircleMarker(
                          point: userLocation!,
                          radius: 10,
                          color: Colors.blue.withOpacity(0.6),
                          borderStrokeWidth: 4,
                          borderColor: Colors.white,
                        ),

                        // 🔵 Familiares
                        ...miembrosFamilia
                            .where((m) {
                          final rol = m["rol"]?.toString().toLowerCase() ?? "";
                          final lat = m["latitud"];
                          final lon = m["longitud"];
                          final uid = m["uid"];

                          if (rol == "padre" || rol == "administrador") return false;
                          if (uid == FirebaseAuth.instance.currentUser?.uid) return false;
                          if (lat == null || lon == null) return false;

                          return true;
                        })
                            .map((m) {
                          return CircleMarker(
                            point: LatLng(m["latitud"], m["longitud"]),
                            radius: 6,
                            color: Colors.primaries[
                            miembrosFamilia.indexOf(m) % Colors.primaries.length
                            ],
                            borderStrokeWidth: 2,
                            borderColor: Colors.white,
                          );
                        }).toList(),
                      ],
                    ),

                  ],
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Row(
                    children: [
                      FloatingActionButton(
                        heroTag: "fab_location",
                        backgroundColor: Colors.blueGrey,
                        onPressed: _centrarEnUsuario,
                        child: const Icon(Icons.my_location, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        heroTag: "fab_foto",
                        backgroundColor: Colors.white,
                        onPressed: _tomarFoto,
                        child: Icon(Icons.camera_alt, color: Colors.blue[900]),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: BotonPanico(familiaId: widget.familiaId),
                ),
                // Lógica de miembros y botón de grupo (Solo Padres/Tutores/Admin)
                Positioned(
                  bottom: 100,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (mostrarFamilia)
                        ...miembrosFamilia
                            .where((m) =>
                                m["uid"] != FirebaseAuth.instance.currentUser?.uid &&
                                m["latitud"] != null)
                            .map((m) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black26, blurRadius: 2)
                                          ],
                                        ),
                                        child: Text(
                                          m["nombre"]?.split(" ")[0] ?? "Usuario",
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FloatingActionButton(
                                        heroTag: "fab_mem_${m["uid"]}",
                                        mini: true,
                                        backgroundColor: Colors.blue[700],
                                        onPressed: () => _centrarEnMiembro(m),
                                        child: const Icon(Icons.person, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                )),
                      const SizedBox(height: 15),
                      // El botón de grupo solo es visible para Padre, Tutor o Administrador
                      if (_esUsuarioAutorizado())
                        FloatingActionButton(
                          heroTag: "fab_principal",
                          backgroundColor: mostrarFamilia ? Colors.grey : Colors.red[900],
                          onPressed: () => setState(() => mostrarFamilia = !mostrarFamilia),
                          child: Icon(mostrarFamilia ? Icons.close : Icons.group,
                              color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  bool _esUsuarioAutorizado() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final miDatos = miembrosFamilia.firstWhere(
      (m) => m['uid'] == currentUser.uid,
      orElse: () => {},
    );

    final rol = miDatos['rol']?.toString().toLowerCase() ?? '';
    return rol == 'padre' || rol == 'administrador' || rol == 'tutor';
  }
}
