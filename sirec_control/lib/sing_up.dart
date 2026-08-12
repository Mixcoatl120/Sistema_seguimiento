import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verificar_email.dart';

import 'Componentes/menu_barra.dart';
import 'package:sirec_control/Componentes/cajas_texto.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _signUp() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();
  final confirmPassword = _confirmPasswordController.text.trim();

  if (password.length < 8) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("La contraseña debe tener al menos 8 caracteres")),
    );
    return;
  }

  if (password != confirmPassword) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Las contraseñas no coinciden")),
    );
    return;
  }

  setState(() { _isLoading = true; });

  try {
    UserCredential userCred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 🔹 Enviar email de verificación
    await userCred.user!.sendEmailVerification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Registro exitoso! Revisa tu email para confirmar tu cuenta."
        ),
      ),
    );

    // 🔹 Navegar a pantalla de verificación de email
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => EmailVerificationScreen(user: userCred.user!)),
    );

  } on FirebaseAuthException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.message}")),
    );
  } finally {
    setState(() { _isLoading = false; });
  }
}


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Inicio de sesión"),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 120),
            InputsPersonalizados(
              label: "Email", 
              controller: _emailController),
            SizedBox(height: 20),
            InputsPersonalizados(
              label: "Contraseña", 
              controller: _passwordController,
              isPassword: true,),
            SizedBox(height: 20),

            InputsPersonalizados(
              label: "Confirmar Contraseña", 
              controller: _confirmPasswordController,
              isPassword: true),
            SizedBox(height: 30),

            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signUp,
                    child: const Text('Registrarse'),
                  ),
          ],
        ),
      ),
    );
  }
}

