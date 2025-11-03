import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class OfflineSessionService {
  /// Verifica conexión real a internet
  static Future<bool> _hasRealInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return false;

    try {
      final result = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Guarda una evaluación offline cuando no hay internet
  static Future<String> saveEvaluationOffline({
    required Map<String, dynamic> evaluationData,
    required String sessionId,
  }) async {
    try {
      if (!Hive.isBoxOpen('offline_evaluaciones')) {
        await Hive.openBox('offline_evaluaciones');
      }

      final box = Hive.box('offline_evaluaciones');
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      
      final offlineId = DateTime.now().millisecondsSinceEpoch.toString();
      final offlineData = {
        'evaluationData': evaluationData,
        'sessionId': sessionId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'uploaded': false,
        'id': offlineId,
      };

      await box.put(offlineId, offlineData);
      print('✅ Evaluación guardada offline: $offlineId');
      return offlineId;
    } catch (e) {
      print('❌ Error al guardar evaluación offline: $e');
      rethrow;
    }
  }

  /// 🔁 Sube evaluaciones offline guardadas en Hive
  static Future<void> uploadOfflineSessions(String userId) async {
    final hasInternet = await _hasRealInternetConnection();
    if (!hasInternet) return;

    try {
      if (!Hive.isBoxOpen('offline_evaluaciones')) {
        await Hive.openBox('offline_evaluaciones');
      }

      final box = Hive.box('offline_evaluaciones');
      final entries = box.toMap().cast<dynamic, Map>();

      for (final entry in entries.entries) {
        final data = entry.value;

        if (data['uploaded'] == false && data['userId'] == userId) {
          try {
            final evaluationData = Map<String, dynamic>.from(data['evaluationData']);
            final sessionId = data['sessionId'] as String;

            // Asegurar que la sesión existe
            await FirebaseFirestore.instance
                .collection('sesiones')
                .doc(sessionId)
                .set({
                  'userId': userId,
                  'timestamp': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

            // Subir evaluación a la subcolección correcta
            await FirebaseFirestore.instance
                .collection('sesiones')
                .doc(sessionId)
                .collection('evaluaciones_animales')
                .add(evaluationData);

            // Marcar como subido
            data['uploaded'] = true;
            await box.put(entry.key, data);

            print('✅ Evaluación sincronizada: ${data['id']}');
          } catch (e) {
            print('❌ Error al subir evaluación offline: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Error en sincronización offline: $e');
    }
  }

  static Future<void> uploadOfflineCreatedSessions(String userId) async {
    final hasInternet = await _hasRealInternetConnection();
    if (!hasInternet) return;

    if (!Hive.isBoxOpen('offline_sesiones')) {
      await Hive.openBox('offline_sesiones');
    }

    final box = Hive.box('offline_sesiones');
    final entries = box.toMap().cast<dynamic, Map>();

    for (final entry in entries.entries) {
      final key = entry.key;
      final data = entry.value;

      if (data['uploaded'] == false && data['userId'] == userId) {
        try {
          final nextSession =
              await FirebaseFirestore.instance
                  .collection('sesiones')
                  .where('userId', isEqualTo: userId)
                  .get();
          final numeroSesion = nextSession.docs.length + 1;

          final docRef = await FirebaseFirestore.instance
              .collection('sesiones')
              .add({
                'userId': userId,
                'estado': 'activa',
                'fecha_creacion': DateTime.parse(data['timestamp']),
                'numero_sesion': 'Sesión $numeroSesion',
                'numero_sesion_int': numeroSesion,
              });

          data['uploaded'] = true;
          await box.put(key, data);

          print('✅ Sesión sincronizada con ID Firestore: ${docRef.id}');
        } catch (e) {
          print('❌ Error al subir sesión offline: $e');
        }
      }
    }
  }
}
