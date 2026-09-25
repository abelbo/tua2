import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'social_profile_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // Tipo de perfil seleccionado por defecto
  String _tipoPerfilSeleccionado = 'Freelance / Servicio';

  // Controladores para los campos de la interfaz
  final _cedulaController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Función principal para registrar el usuario en Auth y guardar en Firestore
  Future<void> _registrarYGuardar() async {
    // Validaciones básicas
    if (_correoController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa Correo, Contraseña y Nombre.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Creamos el usuario en Firebase Authentication (Seguridad)
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _correoController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String userId = userCredential.user!.uid;

      // 2. Creamos el objeto del modelo UserProfile con todos los datos
      UserProfile nuevoPerfil = UserProfile(
        id: userId,
        nombre: _nombreController.text.trim(),
        especialidad: _tipoPerfilSeleccionado,
        descripcion: 'Cédula: ${_cedulaController.text.trim()}',
        edad: 0, 
        direccion: '', 
        telefono: '', 
        fotoUrl: '',
        tipoPerfil: _tipoPerfilSeleccionado,
        palabrasClave: [
          _nombreController.text.trim().toLowerCase(),
          _tipoPerfilSeleccionado.toLowerCase(),
        ],
      );

      // 3. GUARDAMOS EN FIRESTORE (Colección 'profiles') usando el UID exacto de Auth
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .set(nuevoPerfil.toMap());

      // 4. Redirigimos al perfil social si todo sale bien
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SocialProfileScreen(profile: nuevoPerfil),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el registro: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _usuarioController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Registro Seguro - TUA2',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona tu tipo de perfil',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                'Crea tus credenciales de seguridad y configura tu espacio en TUA2.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Selector de tipos de perfil (Tarjetas)
              Row(
                children: [
                  Expanded(child: _buildRoleCard('Freelance / Servicio', Icons.work, true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildRoleCard('Pyme / Local\n(Pronto)', Icons.store, false)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildRoleCard('Marketplace\n(Pronto)', Icons.shopping_bag, false)),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta informativa de seguridad
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tu cédula, correo y contraseña protegen tu cuenta. Podrás subir fotos de tus trabajos y mostrarte en el mapa.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Identificación y Credenciales (Privado)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),

              // Cédula y Usuario
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cedulaController,
                      label: 'N° de Cédula',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _usuarioController,
                      label: 'Usuario / Alias',
                      icon: Icons.alternate_email,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Correo
              _buildTextField(
                controller: _correoController,
                label: 'Correo Electrónico *',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              // Contraseña
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña o Clave *',
                  labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Información Profesional Pública',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),

              // Nombre Completo / Razón Social
              _buildTextField(
                controller: _nombreController,
                label: 'Nombre Completo / Razón Social *',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 30),

              // Botón de Registro / Guardar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrarYGuardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                            // ignore: deprecated_member_use
                            backgroundColor: Colors.transparent,
                          ),
                        )
                      : const Text(
                          'Completar Registro',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String title, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: isSelected
          ? () {
              setState(() {
                _tipoPerfilSeleccionado = title;
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black87, width: 1.5),
        ),
      ),
    );
  }
}