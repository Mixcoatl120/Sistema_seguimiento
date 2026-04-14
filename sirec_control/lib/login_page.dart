import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sing_up.dart';
import 'home.dart';

//witdgets

import 'Componentes/menu_barra.dart';
import 'package:sirec_control/Componentes/cajas_texto.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login exitoso ")),
      );
      // Aquí podrías navegar a la pantalla principal:
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Contraseña y/o correo incorrecto")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Inicio de sesión"),
      body: SingleChildScrollView(
        reverse: true, // hace que el scroll suba cuando el teclado aparece
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 80), // opcional: espacio arriba
            Image.asset(
              "assets/images/logo_sirec.png",
              height: 120,
            ),
            const SizedBox(height: 100),
            InputsPersonalizados(
              label: "Email",
              controller: _emailController,
            ),
            SizedBox(height: 20),
            InputsPersonalizados(
              label: "Contraseña",
              controller: _passwordController,
              isPassword: true, // activa el botón ver/ocultar
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text("Login"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignUpScreen()),
                );
              },
              child: const Text("¿No tienes cuenta? Regístrate"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
