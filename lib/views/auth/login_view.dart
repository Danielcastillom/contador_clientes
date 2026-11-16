import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../accountant/accountant_dashboard.dart';
import '../client/client_portal_view.dart';

class LoginView extends StatefulWidget {
  LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user;
      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        user = userCredential.user;
      } catch (e) {
        // Manejar error de keychain en macOS permitiendo continuar si el usuario ya está autenticado en memoria
        if (e.toString().contains('keychain-error') && FirebaseAuth.instance.currentUser != null) {
          user = FirebaseAuth.instance.currentUser;
        } else {
          rethrow;
        }
      }

      if (user == null) return;

      String email = user.email ?? '';

      // Validación de administrador multi-nivel
      bool isAccountant = email == 'castillo8505@gmail.com';

      if (!isAccountant) {
        // 1. Verificar por UID en la colección users
        try {
          var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            if (data?['role'] == 'accountant') {
              isAccountant = true;
            }
          }
        } catch (e) {
          print('Error al verificar users/{uid}: $e');
        }

        // 2. Verificar en accountant_profile
        if (!isAccountant) {
          try {
            var accountantDoc = await FirebaseFirestore.instance.collection('accountant_profile').doc(user.uid).get();
            if (accountantDoc.exists) {
              isAccountant = true;
            } else {
              var accountantQuery = await FirebaseFirestore.instance
                  .collection('accountant_profile')
                  .where('email', isEqualTo: email)
                  .get();
              if (accountantQuery.docs.isNotEmpty) {
                isAccountant = true;
              }
            }
          } catch (e) {
            print('Error al verificar accountant_profile: $e');
          }
        }

        // 3. Verificar en config/admins (Array de emails)
        if (!isAccountant) {
          try {
            var adminConfigDoc = await FirebaseFirestore.instance.collection('config').doc('admins').get();
            if (adminConfigDoc.exists) {
              List<dynamic> adminEmails = adminConfigDoc.data()?['emails'] ?? [];
              for (var adminEmail in adminEmails) {
                if (adminEmail.toString().trim().toLowerCase() == email.trim().toLowerCase()) {
                  isAccountant = true;
                  break;
                }
              }
            }
          } catch (e) {
            print('Error al verificar config/admins: $e');
          }
        }
      }

      if (!context.mounted) return;

      if (isAccountant) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccountantDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ClientPortalView()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String userFriendlyMessage = 'Error de inicio de sesión (${e.code}): ${e.message}';
      if (e.code == 'unknown-error') {
        userFriendlyMessage =
            'Error de conexión con Firebase Auth (unknown-error).\n'
            '1. Verifica la fecha y hora de la computadora (debe estar ajustada automáticamente).\n'
            '2. Revisa la conexión a internet o desactiva temporalmente el antivirus/VPN.';
      } else if (e.code == 'invalid-credential' || e.code == 'wrong-password' || e.code == 'user-not-found') {
        userFriendlyMessage = 'Correo electrónico o contraseña incorrectos.';
      } else if (e.code == 'network-request-failed') {
        userFriendlyMessage = 'Error de red. Verifica tu conexión a internet.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyMessage),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.indigo.shade100, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Image.asset(
                          'assets/masexacto.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.account_balance, size: 60, color: Colors.indigo);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Más Exacto',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Asesores Integrales',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigoAccent,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Inicia sesión para continuar',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) => value!.isEmpty ? 'Ingresa tu correo' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) => value!.isEmpty ? 'Ingresa tu contraseña' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
