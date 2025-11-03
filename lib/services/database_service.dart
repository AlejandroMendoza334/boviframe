import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  // Firestore (tu implementación actual)
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;
  
  // Realtime Database (nueva implementación)
  final rtdb.DatabaseReference _rtdb = rtdb.FirebaseDatabase.instance.ref();

  /// Verifica si hay conexión real a internet
  static Future<bool> hasRealInternetConnection() async {
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

  /// Guarda un animal en local (Hive) cuando no hay internet
  static Future<void> _saveAnimalOffline(Map<String, dynamic> animalData) async {
    try {
      if (!Hive.isBoxOpen('offline_animals')) {
        await Hive.openBox('offline_animals');
      }

      final box = Hive.box('offline_animals');
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      
      final offlineData = {
        'animalData': animalData,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'uploaded': false,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      await box.put(offlineData['id'], offlineData);
      debugPrint('✅ Animal guardado offline: ${offlineData['id']}');
    } catch (e) {
      debugPrint('❌ Error al guardar offline: $e');
    }
  }

  /// Sincroniza animales guardados offline cuando hay internet
  static Future<void> syncOfflineAnimals() async {
    final hasInternet = await hasRealInternetConnection();
    if (!hasInternet) return;

    try {
      if (!Hive.isBoxOpen('offline_animals')) {
        await Hive.openBox('offline_animals');
      }

      final box = Hive.box('offline_animals');
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final entries = box.toMap().cast<dynamic, Map>();
      
      for (final entry in entries.entries) {
        final data = entry.value;
        
        if (data['uploaded'] == false && data['userId'] == userId) {
          try {
            final animalData = Map<String, dynamic>.from(data['animalData']);
            
            // Guardar en Firestore
            await firestore.FirebaseFirestore.instance
                .collection('animals')
                .add(animalData);

            // Marcar como subido
            data['uploaded'] = true;
            await box.put(entry.key, data);
            
            debugPrint('✅ Animal sincronizado: ${data['id']}');
          } catch (e) {
            debugPrint('❌ Error al sincronizar animal ${data['id']}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error en sincronización offline: $e');
    }
  }

  // ========== Métodos para Firestore ==========
  Future<String?> saveAnimal(Map<String, dynamic> animalData) async {
    try {
      // Verificar conexión a internet
      final hasInternet = await hasRealInternetConnection();
      
      if (hasInternet) {
        // Intentar guardar en Firestore
        try {
          await _firestore.collection('animals').add(animalData);
          debugPrint('✅ Animal guardado en Firestore');
          return null;
        } on firestore.FirebaseException catch (e) {
          debugPrint('⚠️ Error de Firestore, guardando offline: ${e.code}');
          // Si falla pero hay internet, puede ser error temporal
          await _saveAnimalOffline(animalData);
          return 'Guardado offline. Se sincronizará cuando sea posible.';
        }
      } else {
        // No hay internet, guardar offline
        debugPrint('📱 Sin internet, guardando offline');
        await _saveAnimalOffline(animalData);
        return 'Guardado offline. Se sincronizará cuando haya internet.';
      }
    } catch (e) {
      debugPrint('❌ Error al guardar animal: $e');
      // En caso de error, intentar guardar offline
      try {
        await _saveAnimalOffline(animalData);
        return 'Guardado offline. Se sincronizará cuando haya internet.';
      } catch (offlineError) {
        return 'Error al guardar: $e';
      }
    }
  }

  Stream<firestore.QuerySnapshot> getAnimals({String? upId, int limit = 10}) {
    firestore.Query query = _firestore.collection('animals').limit(limit);
    if (upId != null) query = query.where('up_id', isEqualTo: upId);
    return query.snapshots();
  }

  Future<void> deleteAnimal(String animalId) async {
    await _firestore.collection('animals').doc(animalId).delete();
  }

  // ========== Métodos para Realtime Database ==========
  Future<String?> saveEvaluationRTDB(Map<String, dynamic> evaluationData) async {
    try {
      await _rtdb.child('evaluaciones').push().set(evaluationData);
      return null;
    } catch (e) {
      debugPrint('Error al guardar en RTDB: $e');
      return e.toString();
    }
  }

  Stream<rtdb.DatabaseEvent> getEvaluationsRTDB() {
    return _rtdb.child('evaluaciones').onValue;
  }

  Future<void> deleteEvaluationRTDB(String evaluationId) async {
    await _rtdb.child('evaluaciones/$evaluationId').remove();
  }

  // ========== Métodos combinados ==========
  Future<String?> saveAnimalWithEvaluation({
    required Map<String, dynamic> animalData,
    required Map<String, dynamic> evaluationData,
  }) async {
    try {
      // Primero guarda en Firestore
      final docRef = await _firestore.collection('animals').add(animalData);
      
      // Luego guarda en RTDB con referencia al ID de Firestore
      await _rtdb.child('evaluaciones/${docRef.id}').set({
        ...evaluationData,
        'animal_id': docRef.id,
        'created_at': rtdb.ServerValue.timestamp,
      });
      
      return null;
    } catch (e) {
      debugPrint('Error en operación combinada: $e');
      return e.toString();
    }
  }

  static Future<void> uploadOfflineEvaluations(String userId) async {
    // Sincronizar animales offline
    await syncOfflineAnimals();
  }
}