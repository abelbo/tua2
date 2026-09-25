import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tua2_app/screen/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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

// Pantalla de carga inicial conceptual con logo y lema que salta al Mapa
class SplashScreenTua2 extends StatefulWidget {
  const SplashScreenTua2({super.key});

  @override
  State<SplashScreenTua2> createState() => _SplashScreenTua2State();
}

class _SplashScreenTua2State extends State<SplashScreenTua2> {
  @override
  void initState() {
    super.initState();
    // Transición automática al mapa principal tras 2 segundos
    Future.delayed(const Duration(seconds: 2), () {
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logotipo circular
              Container(
                width: 120,
                height: 120,
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
                      return const Icon(Icons.hub, color: Color(0xFFE53935), size: 60);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Nombre de la App
              const Text(
                'TUA2',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Frase conceptual
              const Text(
                '«Hoy tú, mañana yo»',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE53935),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              const Text(
                'Economía de proximidad y confianza vecinal',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              const CircularProgressIndicator(
                color: Color(0xFFE53935),
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}