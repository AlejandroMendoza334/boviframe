import 'package:flutter/material.dart';
import '../../widgets/custom_app_scaffold.dart';

class NewSessionScreen extends StatelessWidget {
  final String? sessionId;

  const NewSessionScreen({Key? key, required this.sessionId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomAppScaffold(
      currentIndex: 2, // EPMURAS
      title: 'Nueva Sesión',
      showBackButton: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
        child: Column(
          children: [
            _buildSectionButton(
              context,
              label: 'Datos del Productor',
              onTap: () => Navigator.pushNamed(
                context,
                '/datos_productor',
                arguments: {'sessionId': sessionId},
              ),
              highlighted: true,
            ),
            const SizedBox(height: 16),
            _buildSectionButton(
              context,
              label: 'Evaluación del Animal',
              onTap: () => Navigator.pushNamed(
                context,
                '/animal_evaluation',
                arguments: {'sessionId': sessionId},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final Color bgColor = highlighted
        ? Colors.blue[50]! // Más claridad para botón destacado
        : Colors.blue[50]!;

    final Color textColor = Colors.blue[800]!;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
