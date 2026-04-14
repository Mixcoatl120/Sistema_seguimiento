import 'package:flutter/material.dart';

// Navbar global, cambia aquí el estilo de la navbar que tiene la app
PreferredSizeWidget customAppBar(String title, {List<Widget>? actions}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(color: Colors.white),// color del texto del elemento
    ),
    centerTitle: false,
    backgroundColor: Colors.blue[900],// color del backgroud universal
    elevation: 4,
    iconTheme: const IconThemeData(color: Colors.white),// color de iconos de la navbar
    actions: actions, // <- Aquí acepta acciones opcionales
  );
}

