import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

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
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    final data = userDoc.data();
    if (data == null || data['idfamilia'] == null) {
      print('⚠️ Usuario no tiene idFamilia asignado');
      return;
    }

    final familyId = data['idfamilia'];
    print('🟢 Usuario pertenece a la familia: $familyId');

    // 🔹 Suscribirse al documento de la familia
    familySubscription = FirebaseFirestore.instance
        .collection('familias')
        .doc(familyId)
        .snapshots()
        .listen((doc) {
      final familyData = doc.data();
      if (familyData == null) return;

      final miembros = familyData['miembros'] as List<dynamic>?;

      if (miembros == null) return;

      miembrosFamilia = miembros.map((m) => Map<String, dynamic>.from(m)).toList();

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

        if (rol == 'hijo' && lat != null && lon != null && miembroUid != user.uid) {
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
                  child: FloatingActionButton(
                    backgroundColor: Colors.blueGrey,
                    onPressed: _centrarEnUsuario,
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),
                Positioned(
  bottom: 90,
  right: 20,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      // Mostrar miembros con nombre
      if (mostrarFamilia)
        ...miembrosFamilia
    .where((m) {
      final rol = m["rol"]?.toString().toLowerCase() ?? "";
      final lat = m["latitud"];
      final lon = m["longitud"];
      final uid = m["uid"];

      // ❌ No mostrar padre ni administrador
      if (rol == "padre" || rol == "administrador") return false;

      // ❌ No mostrar usuario actual
      if (uid == FirebaseAuth.instance.currentUser?.uid) return false;

      // ❌ No mostrar miembros sin coordenadas
      if (lat == null || lon == null) return false;

      return true;
    })
    .map((m) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                m["nombre"] ?? "Sin nombre",
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            FloatingActionButton(
              heroTag: "fab_${m["uid"]}",
              mini: true,
              backgroundColor: Colors.blue[700],
              onPressed: () {
                _centrarEnMiembro(m);
                setState(() => mostrarFamilia = false);
              },
              child: const Icon(Icons.person),
            ),
          ],
        ),
      );
    }),


      // FAB PRINCIPAL (abrir/cerrar menú)
      FloatingActionButton(
        heroTag: "fab_principal",
        backgroundColor: Colors.red,
        onPressed: () {
          setState(() => mostrarFamilia = !mostrarFamilia);
        },
        child: Icon(
          mostrarFamilia ? Icons.close : Icons.group,
        ),
      ),
    ],
  ),
)


              ],
            ),
    );
  }
}
