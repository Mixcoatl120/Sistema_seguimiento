// --- Pantalla para gestionar y reproducir grabaciones de emergencia ---
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sirec_control/Componentes/menu_barra.dart';

class AudiosPage extends StatefulWidget {
  const AudiosPage({super.key});

  @override
  State<AudiosPage> createState() => _AudiosPageState();
}

class _AudiosPageState extends State<AudiosPage> {
  List<File> _files = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _cargarArchivos();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Escanear la carpeta interna en busca de audios y fotos ---
  Future<void> _cargarArchivos() async {
    final directory = await getApplicationDocumentsDirectory();
    final entities = await directory.list().toList();
    
    final files = entities
        .whereType<File>()
        .where((file) => file.path.endsWith('.m4a') || file.path.endsWith('.jpg'))
        .toList();

    // Ordenar por fecha de creación (más reciente primero)
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {
      _files = files;
    });
  }

  // --- Control de reproducción ---
  Future<void> _reproducir(String path) async {
    if (_playingPath == path) {
      await _audioPlayer.stop();
      setState(() => _playingPath = null);
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _playingPath = path);
    }
    
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar("Multimedia de Emergencia"),
      body: _files.isEmpty
          ? const Center(child: Text("No se encontraron archivos multimedia."))
          : ListView.builder(
              itemCount: _files.length,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final file = _files[index];
                final fileName = file.path.split('/').last;
                final isAudio = fileName.endsWith('.m4a');
                final isPlaying = _playingPath == file.path;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: isAudio 
                      ? Icon(
                          isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: Colors.blue[900],
                          size: 40,
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(file, width: 40, height: 40, fit: BoxFit.cover),
                        ),
                    title: Text(fileName, style: const TextStyle(fontSize: 14)),
                    subtitle: Text("Fecha: ${file.lastModifiedSync().toString().split('.')[0]}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        await file.delete();
                        _cargarArchivos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Archivo eliminado")),
                        );
                      },
                    ),
                    onTap: () {
                      if (isAudio) {
                        _reproducir(file.path);
                      } else {
                        _mostrarFoto(file);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  void _mostrarFoto(File file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(file),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))
          ],
        ),
      ),
    );
  }
}
