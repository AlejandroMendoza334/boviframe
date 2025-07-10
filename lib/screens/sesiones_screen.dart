// lib/screens/sesiones_screen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:boviframe/screens/animal_detail_screen.dart';

class SesionesScreen extends StatelessWidget {
  final String finca;

  /// Cada elemento tiene: 'session_id', 'numero_sesion' y opcionalmente 'image_base64'
  final List<Map<String, dynamic>> sesiones;

  const SesionesScreen({
    Key? key,
    required this.finca,
    required this.sesiones,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sesiones de $finca', style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: sesiones.length,
        itemBuilder: (ctx, i) {
          final ses = sesiones[i];
          final numeroSes = ses['numero_sesion'] as String? ?? '';
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

              // Aquí mostramos la miniatura decodificada o un placeholder:
              leading: () {
                final b64 = ses['image_base64'] as String?;
                if (b64 != null && b64.isNotEmpty) {
                  try {
                    final bytes = base64Decode(b64);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        bytes,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    );
                  } catch (_) {
                    // decode falló, cae al placeholder
                  }
                }
                return const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                );
              }(),

              title: Text('Sesión $numeroSes', style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _mostrarEvaluaciones(context, ses['session_id'] as String, numeroSes),
            ),
          );
        },
      ),
    );
  }

  Future<void> _mostrarEvaluaciones(
    BuildContext context,
    String sessionId,
    String numeroSesion,
  ) async {
    final qs = await FirebaseFirestore.instance
        .collection('sesiones')
        .doc(sessionId)
        .collection('evaluaciones_animales')
        .orderBy('timestamp', descending: true)
        .get();

    final evals = qs.docs.map((d) {
      final m = d.data();
      return {
        'numero'       : m['numero'] ?? '',
        'registro'     : m['registro'] ?? '',
        'sexo'         : m['sexo'] ?? '',
        'estado'       : m['estado'] ?? '',
        'fecha_nac'    : m['fecha_nac'] ?? '',
        'fecha_dest'   : m['fecha_dest'] ?? '',
        'peso_nac'     : m['peso_nac'] ?? '',
        'peso_dest'    : m['peso_dest'] ?? '',
        'peso_ajus'    : m['peso_ajus'] ?? '',
        'edad_dias'    : m['edad_dias'] ?? '',
        'epmuras'      : Map<String, dynamic>.from(m['epmuras'] ?? {}),
        'image_base64' : m['image_base64'],
      };
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Evaluaciones $numeroSesion', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: evals.isEmpty
              ? const Text('No hay evaluaciones en esta sesión.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: evals.length,
                  itemBuilder: (_, j) {
                    final e = evals[j];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                        // Miniatura igual que arriba:
                        leading: () {
                          final b64 = e['image_base64'] as String?;
                          if (b64 != null && b64.isNotEmpty) {
                            try {
                              final bytes = base64Decode(b64);
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover),
                              );
                            } catch (_) {}
                          }
                          return const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(Icons.image, color: Colors.grey),
                          );
                        }(),

                        title: Text('Animal N° ${e['numero']}'),
                        subtitle: Text('RGN ${e['registro']}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnimalDetailScreen(animalData: e),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
