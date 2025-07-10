import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './providers/settings_provider.dart';
import 'package:boviframe/widgets/custom_bottom_nav_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _collegeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedProfession = 'Veterinario';
  final List<String> _professions = [
    'Veterinario',
    'Zootecnista',
    'Agrónomo',
    'Otro',
  ];

  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _collegeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        final nombre = data['nombre'] ?? '';
        final colegio = data['colegio'] ?? '';
        final ubicacion = data['ubicacion'] ?? '';
        final profesion = data['profesion'] ?? 'Veterinario';
        final email = _user?.email ?? '';

        setState(() {
          _nameController.text = nombre;
          _collegeController.text = colegio;
          _locationController.text = ubicacion;
          _selectedProfession = profesion;
        });

        context.read<SettingsProvider>().setUserData(
          name: nombre,
          email: email,
          company: ubicacion,
        );
      }
    } catch (e) {
      debugPrint('❌ Error al cargar datos: $e');
    }
  }

  Future<void> _saveSettings() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final newName = _nameController.text.trim();
    final newCole = _collegeController.text.trim();
    final newUbic = _locationController.text.trim();

    if (newName.isEmpty || newCole.isEmpty || newUbic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, completa todos los campos antes de guardar.',
          ),
        ),
      );
      return;
    }

    try {
      final newProf = _selectedProfession;
      final newEmail = _user?.email ?? '';

      await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).set({
        'nombre': newName,
        'colegio': newCole,
        'ubicacion': newUbic,
        'profesion': newProf,
      }, SetOptions(merge: true));

      context.read<SettingsProvider>().setUserData(
        name: newName,
        email: newEmail,
        company: newUbic,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada exitosamente')),
        );
      }
    } catch (e, st) {
      debugPrint('❌ Error al guardar configuración: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar configuración:\n$e')),
        );
      }
    }
  }

  Future<void> _showAboutDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/icons/logo1.png', width: 60, height: 60),
                const SizedBox(height: 16),
                const Text(
                  'Técnica EPMURAS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 28),
                _buildBenefitTile(Icons.timer_outlined, 'Optimización del tiempo',
                    'Reduce la duración de las consultas manteniendo la calidad.'),
                _buildBenefitTile(Icons.track_changes_outlined, 'Diagnósticos precisos',
                    'Aumenta la certeza en la identificación de patologías.'),
                _buildBenefitTile(Icons.groups_outlined, 'Mejora la comunicación',
                    'Facilita la explicación de casos complejos al cliente.'),
                _buildBenefitTile(Icons.checklist_rtl_outlined, 'Protocolos estandarizados',
                    'Ofrece una guía clara para un abordaje consistente.'),
                const SizedBox(height: 20),
                const Divider(),
                const Text('Creado por Medico Veterinario Gualdrón Williams',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Text('Versión: 1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _styledInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        title: const Text('Configuración', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: _styledInputDecoration('Nombre y Apellido'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedProfession,
                        items: _professions.map((p) {
                          return DropdownMenuItem(value: p, child: Text(p));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedProfession = v);
                        },
                        decoration: _styledInputDecoration('Profesión'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _collegeController,
                        decoration: _styledInputDecoration('Número de Colegio'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _locationController,
                        decoration: _styledInputDecoration('Ubicación, Estado, País'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _user?.email ?? '',
                        readOnly: true,
                        decoration: _styledInputDecoration('Email'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Cambios'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(Icons.info_outline, color: Colors.blue),
                          title: const Text('Acerca de BOVIFrame'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _showAboutDialog,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Cerrar sesión'),
                          onTap: () async {
                            if (!mounted) return;
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 4), // 👈 AQUÍ ESTÁ EL MENÚ
    );
  }
}
