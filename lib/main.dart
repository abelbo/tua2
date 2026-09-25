import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tua2_app/screen/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Error al inicializar Firebase: $e');
  }
  runApp(const TUA2App());
}

class TUA2App extends StatelessWidget {
  const TUA2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TUA2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreenTua2(),
    );
  }
}

class SplashScreenTua2 extends StatefulWidget {
  const SplashScreenTua2({super.key});

  @override
  State<SplashScreenTua2> createState() => _SplashScreenTua2State();
}

class _SplashScreenTua2State extends State<SplashScreenTua2> {
  @override
  void initState() {
    super.initState();
    // Transición automática al mapa principal tras 3 segundos para que alcancen a leer el mensaje
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logotipo circular
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE53935), width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.hub, color: Color(0xFFE53935), size: 50),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Mensaje de Bienvenida
                const Text(
                  '¡Bienvenido a TUA2!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Frase conceptual destacada
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '«Hoy tú, mañana yo»',
                    style: TextStyle(
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE53935),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // Texto descriptivo de la app
                const Text(
                  'Conectando tu barrio. Economía de proximidad, confianza y apoyo vecinal en tiempo real.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                const CircularProgressIndicator(
                  color: Color(0xFFE53935),
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}