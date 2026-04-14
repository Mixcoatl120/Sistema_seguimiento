import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sirec_control/home.dart';
import 'login_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asegura la inicialización de Flutter
  await Firebase.initializeApp(); // Inicializa Firebase
  User? user = FirebaseAuth.instance.currentUser; // Obtiene el usuario actual
  runApp(MyApp(user: user));  // Ejecuta la aplicación con el usuario
}

class MyApp extends StatelessWidget {
  final User? user;   // Usuario actual (puede ser nulo)
  const MyApp({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sirec Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[300], // 👈 Fondo gris global
        
      ),
      home: user == null ? LoginPage() : HomePage(), // Decide la pantalla inicial según el estado de autenticación
    );
  }
}


