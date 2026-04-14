import 'dart:async';
//import 'dart:io';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ServicioGrabacion {
  static final ServicioGrabacion _instancia = ServicioGrabacion._interno();
  factory ServicioGrabacion() => _instancia;
  ServicioGrabacion._interno();

  final AudioRecorder _grabador = AudioRecorder();
  bool _grabando = false;

  bool get estaGrabando => _grabando;

  /// Genera una ruta segura para el audio
  Future<String> _crearRutaArchivo() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/panic_audio_$timestamp.m4a';
  }

  /// Solicita permiso e inicia la grabación
  Future<void> iniciar() async {
    final permisoMic = await Permission.microphone.request();
    if (!permisoMic.isGranted) {
      throw Exception('Permiso de micrófono denegado');
    }

    final ruta = await _crearRutaArchivo();

    if (await _grabador.hasPermission()) {
      await _grabador.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: ruta,
      );
      _grabando = true;
      debugPrint('🎤 Grabación iniciada en: $ruta');
    }
  }

  /// Detiene la grabación y devuelve la ruta del archivo
  Future<String?> detener() async {
    if (!_grabando) return null;

    final ruta = await _grabador.stop();
    _grabando = false;

    debugPrint('🎤 Grabación detenida: $ruta');
    return ruta;
  }

  /// Graba automáticamente por X segundos (modo emergencia)
  Future<String?> grabarEmergencia({int segundos = 20}) async {
    await iniciar();
    await Future.delayed(Duration(seconds: segundos));
    return await detener();
  }
}


