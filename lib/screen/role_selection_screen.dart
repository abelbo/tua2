import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'social_profile_screen.dart';
import '../models/user_profile.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class RoleSelectionScreen extends StatefulWidget {
  final String? initialRole;

  const RoleSelectionScreen({
    super.key,
    this.initialRole,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late String _selectedRole;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  // Controladores de Autenticación y Datos
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  final TextEditingController _contactoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _barrioController = TextEditingController();
  final TextEditingController _cedulaNitController = TextEditingController(); 
  final TextEditingController _especialidadDetalleController = TextEditingController();
  final TextEditingController _experienciaController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  final List<String> _areasList = [
    'Arte',
    'Construcción',
    'Cocina',
    'Mobiliario',
    'Deporte',
    'Tecnología',
    'Entretenimiento',
    'Diseño',
    'Transporte',
    'Otros',
  ];
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'freelance';
    _selectedArea = _areasList.first;
  }

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    _edadController.dispose();
    _contactoController.dispose();
    _direccionController.dispose();
    _barrioController.dispose();
    _cedulaNitController.dispose();
    _especialidadDetalleController.dispose();
    _experienciaController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  // Función de geocodificación mediante la instancia del plugin geocoding
  Future<LatLng?> _obtenerCoordenadasAutomaticas(String direccion, String barrio) async {
    try {
      String query = '$direccion, $barrio, Palmira, Valle del Cauca, Colombia';
      final geoService = geocoding.Geocoding();
      List<geocoding.Location> locations = await geoService.locationFromAddress(query);
      
      if (locations.isNotEmpty) {
        geocoding.Location location = locations.first;
        return LatLng(location.latitude, location.longitude);
      }
    } catch (e) {
      debugPrint('Error en geocodificación: $e');
    }
    return null;
  }

  Future<void> _guardarPerfilEnFirebase() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa los campos requeridos correctamente.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? user;
      
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _correoController.text.trim(),
          password: _passwordController.text.trim(),
        ).timeout(const Duration(seconds: 10));
        user = userCredential.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          UserCredential userCredential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
            email: _correoController.text.trim(),
            password: _passwordController.text.trim(),
          ).timeout(const Duration(seconds: 10));
          user = userCredential.user;
        } else {
          rethrow;
        }
      }

      if (user == null) throw Exception('No se pudo autenticar al usuario.');

      final userId = user.uid;
      int edadInt = int.tryParse(_edadController.text.trim()) ?? 0;

      LatLng coordenadasFinales = const LatLng(3.5394, -76.3036);
      LatLng? coordsCalculadas = await _obtenerCoordenadasAutomaticas(
        _direccionController.text.trim(),
        _barrioController.text.trim(),
      );

      if (coordsCalculadas != null) {
        coordenadasFinales = coordsCalculadas;
      }

      String especialidadStr = '';
      String descripcionStr = '';

      if (_selectedRole == 'freelance') {
        especialidadStr = _selectedArea ?? 'Especialista';
        descripcionStr = 'Especialista en: ${_especialidadDetalleController.text.trim()} | Experiencia: ${_experienciaController.text.trim()}';
      } else if (_selectedRole == 'pyme') {
        especialidadStr = 'Negocio / Pyme';
        descripcionStr = _descripcionController.text.trim();
      } else {
        especialidadStr = 'Marketplace';
        descripcionStr = '${_descripcionController.text.trim()} - Precio: ${_precioController.text.trim()}';
      }

      final nuevoPerfil = UserProfile(
        id: userId,
        tipoPerfil: _selectedRole,
        nombre: _nombreController.text.trim(),
        edad: edadInt,
        telefono: _contactoController.text.trim(),
        direccion: _direccionController.text.trim(),
        barrio: _barrioController.text.trim(),
        cedulaNit: _cedulaNitController.text.trim(), 
        especialidad: especialidadStr,
        descripcion: descripcionStr,
        latLng: coordenadasFinales,
        palabrasClave: [
          _nombreController.text.trim().toLowerCase(),
          _selectedRole.toLowerCase(),
          _barrioController.text.trim().toLowerCase(),
          if (_selectedArea != null) _selectedArea!.toLowerCase(),
          _especialidadDetalleController.text.trim().toLowerCase(),
        ],
      );

      Map<String, dynamic> profileData = nuevoPerfil.toMap();
      profileData['latLng'] = {
        'latitude': coordenadasFinales.latitude,
        'longitude': coordenadasFinales.longitude,
      };

      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .set(profileData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SocialProfileScreen(profile: nuevoPerfil, isOwner: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el registro: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'Registro Seguro - TUA2',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona tu tipo de publicación',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Elige cómo quieres visibilizarte en el radar de tu zona.',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildRoleCard('freelance', 'Soy TUA2', Icons.work),
                  const SizedBox(width: 8),
                  _buildRoleCard('pyme', 'Negocio / Pyme', Icons.store),
                  const SizedBox(width: 8),
                  _buildRoleCard('marketplace', 'Venden', Icons.shopping_bag),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Color(0xFFE53935), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getRequisitosTexto(),
                        style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Credenciales de Acceso',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _correoController,
                label: 'Correo Electrónico *',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                validatorMsg: 'Ingresa un correo válido',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Contraseña *',
                icon: Icons.lock_outline,
                obscureText: true,
                validatorMsg: 'Ingresa una contraseña segura',
              ),
              const SizedBox(height: 24),

              const Text(
                'Información del Perfil y Ubicación',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _nombreController,
                label: _selectedRole == 'freelance'
                    ? 'Nombre Completo *'
                    : (_selectedRole == 'pyme' ? 'Nombre del Negocio *' : '¿Qué artículo o producto vendes? *'),
                icon: _selectedRole == 'freelance' ? Icons.person : (_selectedRole == 'pyme' ? Icons.store : Icons.shopping_bag),
                validatorMsg: 'Este campo es obligatorio',
              ),
              const SizedBox(height: 16),

              if (_selectedRole == 'freelance' || _selectedRole == 'pyme') ...[
                _buildTextField(
                  controller: _cedulaNitController,
                  label: _selectedRole == 'freelance' ? 'Número de Cédula (Confidencial) *' : 'Número de NIT (Confidencial) *',
                  icon: Icons.lock_person,
                  keyboardType: TextInputType.number,
                  validatorMsg: _selectedRole == 'freelance' ? 'Ingresa tu cédula' : 'Ingresa tu NIT',
                ),
                const SizedBox(height: 8),
                const Text(
                  '🔒 Este dato se almacena de forma segura exclusivamente para validación interna.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 16),
              ],

              if (_selectedRole == 'freelance') ...[
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        controller: _edadController,
                        label: 'Edad *',
                        icon: Icons.cake,
                        keyboardType: TextInputType.number,
                        validatorMsg: 'Requerido',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _contactoController,
                        label: 'WhatsApp *',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validatorMsg: 'Ingresa un teléfono',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                _buildTextField(
                  controller: _contactoController,
                  label: 'WhatsApp de Contacto *',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validatorMsg: 'Ingresa un número de contacto',
                ),
                const SizedBox(height: 16),
              ],

              _buildTextField(
                controller: _direccionController,
                label: 'Dirección exacta (Ej: Calle 25 # 33-91) *',
                icon: Icons.location_on,
                validatorMsg: 'Ingresa la dirección',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _barrioController,
                label: 'Barrio o Sector (Ej: El Prado) *',
                icon: Icons.map,
                validatorMsg: 'Ingresa el barrio',
              ),
              const SizedBox(height: 16),

              if (_selectedRole == 'freelance') ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedArea,
                  dropdownColor: const Color(0xFF161B22),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Área de especialidad *',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                    ),
                    prefixIcon: const Icon(Icons.category, color: Colors.white54),
                  ),
                  items: _areasList.map((String area) {
                    return DropdownMenuItem<String>(
                      value: area,
                      child: Text(area, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedArea = newValue;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _especialidadDetalleController,
                  label: 'Especialista en *',
                  hint: 'Ej: Carpintería, Pintura, Mantenimiento...',
                  icon: Icons.star,
                  validatorMsg: 'Especifica tu punto fuerte',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _experienciaController,
                  label: 'Años de Experiencia *',
                  hint: 'Ej: 5',
                  keyboardType: TextInputType.number,
                  icon: Icons.history_edu,
                  validatorMsg: 'Ingresa tus años de experiencia',
                ),
              ] else ...[
                _buildTextField(
                  controller: _descripcionController,
                  label: 'Descripción detallada *',
                  hint: 'Explica qué ofreces o detalles del producto...',
                  icon: Icons.description,
                  maxLines: 3,
                  validatorMsg: 'Ingresa una descripción',
                ),
                if (_selectedRole == 'marketplace') ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _precioController,
                    label: 'Precio de venta (\$)',
                    hint: 'Ej: 50000',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _guardarPerfilEnFirebase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Registrar y Entrar a TUA2',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRequisitosTexto() {
    switch (_selectedRole) {
      case 'freelance':
        return 'Soy TUA2 (Especialista): Registro seguro con validación de identidad interna y geolocalización en Palmira.';
      case 'pyme':
        return 'Negocio / Pyme: Visibiliza tu establecimiento comercial con NIT protegido y ubicación exacta.';
      case 'marketplace':
        return 'Venden: Publica tus artículos vecinales de forma directa, rápida y segura.';
      default:
        return 'Completa los datos para crear tu vitrina.';
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? validatorMsg,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        labelStyle: TextStyle(color: const Color(0xFFFFFFFF).withValues(alpha: 0.7)),
        filled: true,
        fillColor: const Color(0xFF161B22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        prefixIcon: Icon(icon, color: Colors.white54),
      ),
      validator: validatorMsg != null
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return validatorMsg;
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildRoleCard(String role, String label, IconData icon) {
    final bool isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = role;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE53935) : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFE53935) : Colors.white24,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}