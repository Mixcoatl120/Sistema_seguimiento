import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sirec_control/Componentes/menu_barra.dart';
import 'datos_usuario.dart';
class EmailVerificationScreen extends StatefulWidget {
  final User user;
  const EmailVerificationScreen({required this.user, super.key});

  @override
  EmailVerificationScreenState createState() => EmailVerificationScreenState();
}

class EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final bool _isVerified = false;
  bool _isLoading = false;

  // Revisar si el email ya fue verificado
  Future<void> checkEmailVerified() async {
  setState(() { _isLoading = true; });

  await widget.user.reload(); // refresca datos en Firebase
  User? updatedUser = FirebaseAuth.instance.currentUser; // usuario actualizado

  if (!mounted) return;

  if (updatedUser != null && updatedUser.emailVerified) {
    // Navegar a la pantalla de perfil
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDataScreen(uid: updatedUser.uid),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Por favor confirma tu email primero.")),
    );
  }

  setState(() { _isLoading = false; });
}


  // Reenviar email de verificación
  Future<void> resendVerificationEmail() async {
    try {
      await widget.user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email de verificación reenviado.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al reenviar el email: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Verifica tu Email"),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Hemos enviado un email a ${widget.user.email}.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: checkEmailVerified,
                    child: const Text("Ya confirmé mi email"),
                  ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: resendVerificationEmail,
              child: const Text("Reenviar email de verificación"),
            ),
          ],
        ),
      ),
    );
  }
}

