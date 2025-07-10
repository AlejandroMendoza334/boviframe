import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'package:boviframe/screens/providers/auth_provider.dart' as my_auth;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataIntoProvider(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .get();
      if (doc.exists) {
        final data = doc.data()!;
        final settingsProv = Provider.of<SettingsProvider>(
          context,
          listen: false,
        );
        settingsProv.setUserData(
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          company: data['company'] ?? '',
        );
      }
    } catch (_) {}
  }

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid);
        final exists = await userDoc.get();

        if (!exists.exists) {
          await userDoc.set({
            'name': user.displayName ?? '',
            'email': user.email,
            'company': '',
            'profesion': 'Google',
            'ubicacion': '',
          });
        }

        await _loadUserDataIntoProvider(user.uid);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main_menu');
      }
    } catch (e) {
      _showAlert(
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Error con Google',
        message: 'No se pudo iniciar sesión: $e',
      );
    }
  }

  Future<void> _loginWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success && result.accessToken != null) {
        final credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final user = userCredential.user;

        if (user != null) {
          final userDoc = FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid);
          final exists = await userDoc.get();

          if (!exists.exists) {
            await userDoc.set({
              'name': user.displayName ?? '',
              'email': user.email,
              'company': '',
              'profesion': 'Facebook',
              'ubicacion': '',
            });
          }

          await _loadUserDataIntoProvider(user.uid);
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/main_menu');
        }
      } else {
        _showAlert(
          icon: Icons.warning,
          color: Colors.orange,
          title: 'Inicio cancelado',
          message: 'Inicio de sesión con Facebook cancelado.',
        );
      }
    } catch (e) {
      _showAlert(
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Error con Facebook',
        message: 'No se pudo iniciar sesión: $e',
      );
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showAlert(
        icon: Icons.info_outline,
        color: Colors.orange,
        title: 'Campos vacíos',
        message: 'Por favor ingresa tu email y contraseña.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<my_auth.AuthProvider>(
        context,
        listen: false,
      );
      final errorMessage = await authProvider.login(email, password);

      if (errorMessage != null) {
        setState(() => _isLoading = false);
        _showAlert(
          icon: Icons.error_outline,
          color: Colors.red,
          title: 'Error de inicio',
          message: errorMessage,
        );
        return;
      }

      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        await firebaseUser.reload();
        if (!firebaseUser.emailVerified) {
          await FirebaseAuth.instance.signOut();
          setState(() => _isLoading = false);
          _showAlert(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            title: 'Verificación pendiente',
            message:
                'Tu cuenta aún no ha sido verificada. Revisa tu correo y verifica tu email antes de iniciar sesión.',
          );
          return;
        }

        await _loadUserDataIntoProvider(firebaseUser.uid);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main_menu');
      }
    } catch (e) {
      _showAlert(
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Error inesperado',
        message: 'No pudimos completar el inicio de sesión. Detalle: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAlert({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            title: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(message, style: const TextStyle(fontSize: 16)),
            actions: [
              TextButton.icon(
                icon: Icon(Icons.check_circle_outline, color: color),
                label: Text('Cerrar', style: TextStyle(color: color)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/icons/fondo6.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 80),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 115),
                SizedBox(
                  width: 250,
                  child: Image.asset('assets/icons/logoapp3.png'),
                ),
                const SizedBox(height: 25),

                // EMAIL
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // CONTRASEÑA
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ENLACES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed:
                          () => Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        'Registrarse',
                        style: TextStyle(
                          color: Colors.blue, // CAMBIO: azul fuerte
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () =>
                              Navigator.pushNamed(context, '/forgot_password'),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          color: Colors.blue, // CAMBIO: azul fuerte
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // BOTÓN INICIAR SESIÓN
                ElevatedButton(
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 30),
                const Text(
                  'O inicia sesión con',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                // BOTÓN GOOGLE
                ElevatedButton.icon(
                  onPressed: _loginWithGoogle,
                  icon: Image.asset('assets/img/google.png', height: 24),
                  label: const Text('Iniciar Sesión con Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // BOTÓN FACEBOOK
                ElevatedButton.icon(
                  onPressed: _loginWithFacebook,
                  icon: Image.asset('assets/img/facebook.png', height: 24),
                  label: const Text('Iniciar Sesión con Facebook'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
