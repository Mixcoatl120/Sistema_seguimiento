import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';

/// Inicializa y arranca el servicio en segundo plano mínimo.
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'sirec_tracking_channel',
      initialNotificationTitle: 'Sirec - Seguimiento',
      initialNotificationContent: 'Servicio de seguimiento activo',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onStart,
      onBackground: _onIosBackground,
    ),
  );

  final isRunning = await service.isRunning();
  if (!isRunning) {
    try {
      await service.startService();
    } catch (e) {
      // Puede fallar en entornos de debug; se deja el log para diagnóstico.
      debugPrint('No se pudo arrancar el servicio de fondo: $e');
    }
  }
}

// Handler mínimo que corre en el isolate del servicio.
Future<void> _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init en service: $e');
  }

  

  // Mantener el servicio vivo y escuchar comandos si se envían
  service.on('setPanic').listen((event) {
    debugPrint('Service received setPanic: $event');
  });

  // Ejemplo de timer que permite ver que el isolate corre
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    debugPrint('Background service alive: ${DateTime.now()}');
  });
}

// Placeholder para iOS
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}
