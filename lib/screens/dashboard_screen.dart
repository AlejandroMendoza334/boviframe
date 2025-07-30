// lib/screens/dashboard_screen.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> evaluaciones = [];
  int totalAnimales = 0;
  int totalSesiones = 0;
  Map<String, double> promedios = {};
  List<Map<String, dynamic>> topAnimales = [];
  List<Map<String, dynamic>> bottomAnimales = [];

  @override
  void initState() {
    super.initState();
    _cargarEvaluaciones();
  }

  Future<void> _cargarEvaluaciones() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final sesionesSnapshot =
        await FirebaseFirestore.instance
            .collection('sesiones')
            .where('userId', isEqualTo: uid) // Solo sesiones del usuario
            .orderBy('timestamp', descending: true)
            .get();

    final todosDatos = <Map<String, dynamic>>[];
    for (final ses in sesionesSnapshot.docs) {
      final evals =
          await ses.reference
              .collection('evaluaciones_animales')
              .where(
                'usuarioId',
                isEqualTo: uid,
              ) 
              .get();

      for (final e in evals.docs) {
        todosDatos.add({...e.data(), 'sessionId': ses.id});
      }
    }

    // 1) Calcular promedios de EPMURAS
    const letras = ['E', 'P', 'M', 'U', 'R', 'A', 'S'];
    final nuevosProm = {for (var l in letras) l: 0.0};
    for (var l in letras) {
      final suma = todosDatos.fold<double>(0.0, (sum, animal) {
        final v = animal['epmuras']?[l];
        return sum +
            (v is num
                ? v.toDouble()
                : double.tryParse(v?.toString() ?? '') ?? 0.0);
      });
      nuevosProm[l] = todosDatos.isEmpty ? 0.0 : suma / todosDatos.length;
    }

    // 2) Calcular “índice” y ordenar
    final listaIndice =
        todosDatos.map((animal) {
            final e = double.tryParse('${animal['epmuras']?['E']}') ?? 0;
            final p = double.tryParse('${animal['epmuras']?['P']}') ?? 0;
            final m = double.tryParse('${animal['epmuras']?['M']}') ?? 0;
            return {
              ...animal,
              'indice': e + p + m,
              'numero': animal['numero'] ?? '-',
              'image_base64': animal['image_base64'],
            };
          }).toList()
          ..sort(
            (a, b) => (b['indice'] as double).compareTo(a['indice'] as double),
          );

    if (!mounted) return;
    setState(() {
      evaluaciones = listaIndice;
      totalAnimales = todosDatos.length;
      totalSesiones = sesionesSnapshot.docs.length;
      promedios = nuevosProm;
      topAnimales = listaIndice.take(3).toList();
      bottomAnimales = listaIndice.reversed.take(3).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        // Cambiamos Column por ListView para permitir scroll
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildMetricCard(
                    title: 'Animales Evaluados',
                    value: '$totalAnimales',
                    color: const Color(0xFF2EC4B6),
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    title: 'Total Sesiones',
                    value: '$totalSesiones',
                    color: const Color(0xFF4A90E2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Promedios EPMURAS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(height: 200, child: _buildBarChart()),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Top 3 Mejores Animales',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            ...topAnimales.map(_buildAnimalCard),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Top 3 Peores Animales',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            ...bottomAnimales.map(_buildAnimalCard),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    color: Colors.blue[800],
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Dashboard General',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: SizedBox(
        height: 100,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> a) {
    Uint8List? foto;
    final base = a['image_base64'] as String?;
    if (base != null && base.isNotEmpty) {
      foto = base64Decode(base);
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          backgroundImage: foto != null ? MemoryImage(foto) : null,
        ),
        title: Text(
          a['numero']?.toString() ?? '-',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Índice: ${(a['indice'] as double).toStringAsFixed(1)}'),
        onTap:
            () => Navigator.pushNamed(context, '/animal_detail', arguments: a),
      ),
    );
  }

  BarChart _buildBarChart() {
    const letras = ['E', 'P', 'M', 'U', 'R', 'A', 'S'];
    final valores = letras.map((l) => promedios[l] ?? 0.0).toList();
    final maxY = ((valores.isEmpty ? 0.0 : valores.reduce(max)) + 2).toDouble();
    final interval = (maxY / 4).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine:
              (v) => FlLine(
                color: Colors.grey.shade600,
                strokeWidth: 1.5,
                dashArray: [4, 4],
              ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= letras.length) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    letras[idx],
                    style: const TextStyle(
                      color: Color(0xFF3AC8F0),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final txt =
                    value == maxY
                        ? value.toStringAsFixed(1)
                        : value.toStringAsFixed(0);
                return Text(
                  txt,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 0,
            getTooltipItem:
                (_, __, rod, ___) => BarTooltipItem(
                  rod.toY.toStringAsFixed(1),
                  const TextStyle(
                    color: Color(0xFF3AC8F0),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),

        barGroups: List.generate(valores.length, (i) {
          return BarChartGroupData(
            x: i,
            showingTooltipIndicators: [0],
            barRods: [
              BarChartRodData(
                toY: valores[i],
                width: 12,
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF3AC8F0), Color(0xFF0CA7E1)],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
