import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'map_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final String profileId; // ID único del perfil (UID del usuario)

  const EditProfileScreen({super.key, required this.profileId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _especialidadController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _barrioController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _nitController = TextEditingController();

  final List<String> _opcionesPerfil = ['Negocio', 'Soy TUA2', 'Vendo'];
  String _tipoPerfil = 'Negocio';

  File? _imagenSeleccionada;
  String _fotoUrlActual = '';
  bool _isLoadingData = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosExistentesDeFirebase();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _especialidadController.dispose();
    _descripcionController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _barrioController.dispose();
    _cedulaController.dispose();
    _nitController.dispose();
    super.dispose();
  }

  // 1. Cargar datos reales desde Firestore
  Future<void> _cargarDatosExistentesDeFirebase() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(widget.profileId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        
        String tipoBD = data['tipoPerfil'] ?? 'Negocio';
        String tipoPerfilValido = _opcionesPerfil.firstWhere(
          (opcion) => opcion.toLowerCase() == tipoBD.toLowerCase(),
          orElse: () => 'Negocio',
        );

        setState(() {
          _nombreController.text = data['nombre'] ?? '';
          _especialidadController.text = data['especialidad'] ?? '';
          _descripcionController.text = data['descripcion'] ?? '';
          _telefonoController.text = data['telefono'] ?? '';
          _direccionController.text = data['direccion'] ?? '';
          _barrioController.text = data['barrio'] ?? '';
          _cedulaController.text = data['cedula'] ?? '';
          _nitController.text = data['nit'] ?? '';
          _tipoPerfil = tipoPerfilValido;
          _fotoUrlActual = data['fotoUrl'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar datos de Firebase: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  // 2. Selector de imagen desde la galería local
  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _imagenSeleccionada = File(pickedFile.path);
      });
    }
  }

  // 3. Función para enviar mensaje directo por WhatsApp
  Future<void> _enviarMensajeWhatsApp(String telefono) async {
    final telefonoLimpio = telefono.replaceAll(RegExp(r'\s+|\D'), '');
    final String mensaje = Uri.encodeComponent("¡Hola! Vi tu perfil en TUA2 y me interesa conocer más sobre tus servicios.");
    final Uri url = Uri.parse("https://wa.me/57$telefonoLimpio?text=$mensaje");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp o el número es inválido')),
        );
      }
    }
  }

  // 4. Guardar perfil y actualizar Firebase incluyendo Cédula, NIT y la Foto de Perfil unificada
  Future<void> _guardarPerfilYSubirAlMapa() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String fotoUrlFinal = _fotoUrlActual;

      // Subida segura de imagen de perfil usando Firebase Storage
      if (_imagenSeleccionada != null) {
        String fileName = 'profiles_photos/${widget.profileId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = ref.putFile(_imagenSeleccionada!);
        TaskSnapshot snapshot = await uploadTask;
        fotoUrlFinal = await snapshot.ref.getDownloadURL();
      }

      double latitudPrueba = 3.5394;
      double longitudPrueba = -76.3036;

      await FirebaseFirestore.instance.collection('profiles').doc(widget.profileId).set({
        'id': widget.profileId,
        'nombre': _nombreController.text.trim(),
        'tipoPerfil': _tipoPerfil,
        'especialidad': _especialidadController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'barrio': _barrioController.text.trim(),
        'cedula': _cedulaController.text.trim(),
        'nit': _nitController.text.trim(),
        'fotoUrl': fotoUrlFinal, // <--- Aquí se guarda la foto de perfil en la vitrina unificada
        'latLng': {
          'latitude': latitudPrueba,
          'longitude': longitudPrueba,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Perfil y foto actualizados con éxito!'), backgroundColor: Colors.green),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MapScreen(
              initialTarget: LatLng(3.5394, -76.3036),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar en Firebase: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Actualizar Perfil',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            )
          : _isUploading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE53935)),
                      SizedBox(height: 16),
                      Text('Sincronizando con Firebase y el mapa...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // --- FOTO DE AVATAR (Diseño unificado de la vitrina) ---
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade200,
                                  border: Border.all(color: const Color(0xFFE53935), width: 3),
                                  image: _imagenSeleccionada != null
                                      ? DecorationImage(
                                          image: FileImage(_imagenSeleccionada!),
                                          fit: BoxFit.cover,
                                        )
                                      : (_fotoUrlActual.isNotEmpty
                                          ? DecorationImage(
                                              image: NetworkImage(_fotoUrlActual),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                                ),
                                child: (_imagenSeleccionada == null && _fotoUrlActual.isEmpty)
                                    ? const Icon(Icons.storefront, size: 50, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _seleccionarImagen,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE53935),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Toca la cámara para subir o cambiar tu foto',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 24),

                        // --- CAMPOS DE FORMULARIO ---
                        TextFormField(
                          controller: _nombreController,
                          decoration: InputDecoration(
                            labelText: 'Nombre del Negocio o TUA2',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? 'El nombre es obligatorio' : null,
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          initialValue: _opcionesPerfil.contains(_tipoPerfil) ? _tipoPerfil : 'Negocio',
                          decoration: InputDecoration(
                            labelText: 'Tipo de Perfil',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                            ),
                          ),
                          items: _opcionesPerfil.map((String categoria) {
                            return DropdownMenuItem<String>(
                              value: categoria,
                              child: Text(categoria == 'Negocio' 
                                  ? 'Negocio / Comercio' 
                                  : categoria == 'Soy TUA2' 
                                      ? 'Soy TUA2 (Profesional / Oficio)' 
                                      : 'Vendo Producto'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _tipoPerfil = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _especialidadController,
                          decoration: InputDecoration(
                            labelText: 'Especialidad (Ej: Choripanes / Plomería)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? 'La especialidad es obligatoria' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _barrioController,
                          decoration: InputDecoration(
                            labelText: 'Barrio o Sector (Ej: San José, La Emilia)',
                            prefixIcon: const Icon(Icons.location_city, color: Color(0xFFE53935)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? 'El barrio genera confianza vecinal' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _direccionController,
                          decoration: InputDecoration(
                            labelText: 'Dirección o Referencia exacta',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- CAMPOS: CÉDULA Y NIT ---
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cedulaController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Cédula',
                                  prefixIcon: const Icon(Icons.badge, color: Color(0xFFE53935)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _nitController,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: 'NIT (Opcional)',
                                  prefixIcon: const Icon(Icons.business_center, color: Color(0xFFE53935)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descripcionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Descripción / Promoción (Ej: El combo a la vueltica)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _telefonoController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Teléfono de contacto',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // --- BOTÓN PRINCIPAL DE GUARDAR ---
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 4,
                            ),
                            onPressed: _guardarPerfilYSubirAlMapa,
                            child: const Text(
                              'Actualizar Perfil en el Mapa',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // --- BOTÓN DE PRUEBA DE WHATSAPP ---
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: () {
                              if (_telefonoController.text.isNotEmpty) {
                                _enviarMensajeWhatsApp(_telefonoController.text);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor ingresa un teléfono primero')),
                                );
                              }
                            },
                            icon: const Icon(Icons.chat, color: Colors.green),
                            label: const Text(
                              'Probar Mensaje de WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}