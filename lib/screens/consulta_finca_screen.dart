
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sesiones_screen.dart';

class ConsultaFincaScreen extends StatefulWidget {
  const ConsultaFincaScreen({Key? key}) : super(key: key);

  @override
  State<ConsultaFincaScreen> createState() => _ConsultaFincaScreenState();
}

class _ConsultaFincaScreenState extends State<ConsultaFincaScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allFincas = [];
  List<Map<String, dynamic>> _filteredFincas = [];

  bool _loading = true;
  String? _error;

  String _filtroUnidad = '';
  String _filtroUbicacion = '';
  String _filtroMunicipio = '';

  @override
  void initState() {
    super.initState();
    _loadFincas();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFincas() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Si tus reglas lo requieren:
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final snap =
          await FirebaseFirestore.instance
              .collectionGroup('datos_productor')
              .get();

      final temp = <Map<String, dynamic>>[];
      for (var doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final parent = doc.reference.parent.parent;
        if (parent == null) continue;
        final parentSnap = await parent.get();
        final numSes = (parentSnap.data()?['numero_sesion'] ?? '').toString();

        temp.add({
          'unidad_produccion': d['unidad_produccion'] ?? '',
          'ubicacion': d['ubicacion'] ?? '',
          'municipio': d['municipio'] ?? '',
          'session_id': parent.id,
          'numero_sesion': numSes,
        });
      }

      // Agrupo por unidad_produccion
      final mapa = <String, Map<String, dynamic>>{};
      for (var item in temp) {
        final finca = item['unidad_produccion'] as String;
        mapa.putIfAbsent(
          finca,
          () => {
            'unidad_produccion': finca,
            'ubicacion': item['ubicacion'],
            'municipio': item['municipio'],
            'sesiones': <Map<String, dynamic>>[],
          },
        );
        (mapa[finca]!['sesiones'] as List).add({
          'session_id': item['session_id'],
          'numero_sesion': item['numero_sesion'],
        });
      }

      _allFincas = mapa.values.toList();
      _filteredFincas = List.from(_allFincas);

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando fincas: $e';
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredFincas =
          _allFincas.where((f) {
            final unidad = (f['unidad_produccion'] as String).toLowerCase();
            final ubicacion = (f['ubicacion'] as String).toLowerCase();
            final municipio = (f['municipio'] as String).toLowerCase();

            final matchSearch = unidad.contains(q);
            final matchUnidad =
                _filtroUnidad.isEmpty ||
                unidad.contains(_filtroUnidad.toLowerCase());
            final matchUbic =
                _filtroUbicacion.isEmpty ||
                ubicacion.contains(_filtroUbicacion.toLowerCase());
            final matchMun =
                _filtroMunicipio.isEmpty ||
                municipio.contains(_filtroMunicipio.toLowerCase());

            return matchSearch && matchUnidad && matchUbic && matchMun;
          }).toList();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            bottom: mq.viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // “handle” decorativo
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const Text(
                'Filtros avanzados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextField(
                decoration: const InputDecoration(
                  labelText: 'Unidad de producción',
                ),
                onChanged: (v) => _filtroUnidad = v,
              ),
              const SizedBox(height: 12),

              TextField(
                decoration: const InputDecoration(labelText: 'Ubicación'),
                onChanged: (v) => _filtroUbicacion = v,
              ),
              const SizedBox(height: 12),

              TextField(
                decoration: const InputDecoration(labelText: 'Municipio'),
                onChanged: (v) => _filtroMunicipio = v,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Limpiar solo los filtros avanzados
                        setState(() {
                          _filtroUnidad = '';
                          _filtroUbicacion = '';
                          _filtroMunicipio = '';
                        });
                      },
                      child: const Text('LIMPIAR FILTROS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _applyFilters();
                      },
                      child: const Text('APLICAR'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        title: const Text(
          'Consultar Fincas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // ───────── Buscador ─────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Unidad de producción',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showFilterSheet,
                        icon: const Icon(Icons.filter_list),
                        label: const Text(
                          'FILTROS',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[500],
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.search),
                        label: const Text(
                          'BUSCAR',
                          style: TextStyle(color: Colors.white),
                        ),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[500],
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 12),
          ],

          // ───────── Lista ─────────
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredFincas.isEmpty
                    ? const Center(child: Text('No hay fincas.'))
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: _filteredFincas.length,
                      itemBuilder: (ctx, i) {
                        final finca = _filteredFincas[i];
                        final sessions = List<Map<String, dynamic>>.from(
                          finca['sesiones'] as List,
                        );
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Finca: ${finca['unidad_produccion']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Ubicación: ${finca['ubicacion']}'),
                                Text('Municipio: ${finca['municipio']}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Sesiones: ${sessions.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => SesionesScreen(
                                                finca:
                                                    finca['unidad_produccion'],
                                                sesiones: sessions,
                                              ),
                                        ),
                                      );
                                    },
                                    child: const Text('Ver sesiones'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
