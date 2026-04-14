// --- Pantalla de configuración y gestión de permisos ---
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sirec_control/Componentes/menu_barra.dart';

class OpcionesPage extends StatefulWidget {
  const OpcionesPage({super.key});

  @override
  State<OpcionesPage> createState() => _OpcionesPageState();
}

class _OpcionesPageState extends State<OpcionesPage> with WidgetsBindingObserver {
  
  // --- Mapa de estados de permisos ---
  Map<Permission, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- Refrescar estados al volver de los ajustes del sistema ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  // --- Verificación masiva de permisos ---
  Future<void> _checkAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};
    statuses[Permission.location] = await Permission.location.status;
    statuses[Permission.locationWhenInUse] = await Permission.locationWhenInUse.status;
    statuses[Permission.microphone] = await Permission.microphone.status;
    statuses[Permission.notification] = await Permission.notification.status;
    statuses[Permission.camera] = await Permission.camera.status;

    if (mounted) {
      setState(() {
        _statuses = statuses;
      });
    }
  }

  // --- Gestión de solicitud de permisos ---
  Future<void> _requestPermission(Permission permission) async {
    if (permission == Permission.location) {
      // Para ubicación precisa/siempre, primero solemos necesitar WhenInUse
      final statusWhenInUse = await Permission.locationWhenInUse.request();
      if (statusWhenInUse.isGranted) {
        await Permission.location.request();
      }
    }

    final status = await permission.request();
    
    // Si el usuario lo denegó permanentemente, sugerimos abrir ajustes
    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showSettingsDialog();
      }
    }
    _checkAllPermissions();
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permiso denegado"),
        content: const Text("Para activar este permiso es necesario hacerlo desde los ajustes del sistema."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Abrir Ajustes"),
          ),
        ],
      ),
    );
  }

  // --- Constructor de items de la lista ---
  Widget _buildPermissionTile(Permission permission, String label, IconData icon) {
    final status = _statuses[permission] ?? PermissionStatus.denied;
    
    bool isGranted = status.isGranted || status.isLimited;
    // Caso especial para ubicación: si cualquiera de los dos niveles está concedido
    if (permission == Permission.location) {
      isGranted = isGranted || (_statuses[Permission.locationWhenInUse]?.isGranted ?? false);
    }

    return ListTile(
      leading: Icon(icon, color: isGranted ? Colors.green : Colors.grey),
      title: Text(label),
      subtitle: Text(
        isGranted ? "Concedido" : "No concedido",
        style: TextStyle(color: isGranted ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
      ),
      trailing: isGranted 
        ? const Icon(Icons.check_circle, color: Colors.green)
        : ElevatedButton(
            onPressed: () => _requestPermission(permission),
            child: const Text("Activar"),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Opciones"),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Gestión de Permisos",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          const Divider(),
          _buildPermissionTile(Permission.location, "Ubicación", Icons.location_on),
          _buildPermissionTile(Permission.microphone, "Micrófono", Icons.mic),
          _buildPermissionTile(Permission.notification, "Notificaciones", Icons.notifications),
          _buildPermissionTile(Permission.camera, "Cámara", Icons.camera_alt),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Nota: Los permisos de ubicación, micrófono y cámara son críticos para el funcionamiento de las alertas de pánico y la recolección de evidencia.",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}