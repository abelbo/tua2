import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_profile.dart';
import 'social_profile_screen.dart';
import 'role_selection_screen.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialTarget;
  final String? focusProfileId;

  const MapScreen({super.key, this.initialTarget, this.focusProfileId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  
  List<UserProfile> _todosLosPerfiles = [];
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {}; // Para pintar el radio de acción visual
  
  String categoriaSeleccionada = 'Todo';
  double radioKm = 1.0; // Radar de acción principal de la app
  
  String? _miFotoUrl;
  UserProfile? _miPerfilCompleto;
  LatLng _currentCenterLocation = const LatLng(3.5394, -76.3036); // Posición base inicial

  final TextEditingController _searchController = TextEditingController();
  String _textoBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarMiPerfilLogueado();
    _cargarMarcadoresDesdeFirestore();
    _irAUbicacionActual(esInicio: true);
    
    _searchController.addListener(() {
      setState(() {
        _textoBusqueda = _searchController.text.toLowerCase().trim();
        _actualizarMarcadoresYRadio();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarMiPerfilLogueado() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('profiles').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _miPerfilCompleto = UserProfile.fromMap(doc.data()!);
          _miFotoUrl = _miPerfilCompleto?.fotoUrl;
        });
      }
    }
  }

  double _calcularDistanciaKm(double startLat, double startLng, double endLat, double endLng) {
    const double earthRadius = 6371.0;
    double dLat = _degToRad(endLat - startLat);
    double dLon = _degToRad(endLng - startLng);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(startLat)) * cos(_degToRad(endLat)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double degree) => degree * pi / 180.0;

  Future<void> _cargarMarcadoresDesdeFirestore() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('profiles').get();
      List<UserProfile> perfilesCargados = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        UserProfile profile = UserProfile.fromMap(data);
        perfilesCargados.add(profile);
      }

      setState(() {
        _todosLosPerfiles = perfilesCargados;
      });

      _actualizarMarcadoresYRadio();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfiles: $e')),
        );
      }
    }
  }

  Future<void> _irAUbicacionActual({bool esInicio = false}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!esInicio && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, activa los servicios de ubicación.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!esInicio && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación denegados.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    
    LatLng currentLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentCenterLocation = currentLatLng;
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: currentLatLng, zoom: 14.5),
      ),
    );

    _actualizarMarcadoresYRadio();
  }

  void _actualizarMarcadoresYRadio() {
    Set<Marker> tempMarkers = {};
    LatLng centroReferencia = widget.initialTarget ?? _currentCenterLocation;

    // 1. Dibuja el círculo visual del radio en el mapa
    Set<Circle> tempCircles = {
      Circle(
        circleId: const CircleId('radio_accion'),
        center: centroReferencia,
        radius: radioKm * 1000.0, // Convertir km a metros
        fillColor: const Color(0xFFE53935).withValues(alpha: 0.1),
        strokeColor: const Color(0xFFE53935),
        strokeWidth: 2,
      ),
    };

    // 2. Filtra perfiles por distancia, categoría y texto
    for (var profile in _todosLosPerfiles) {
      String nombre = profile.nombre.toLowerCase();
      String especialidad = profile.especialidad.toLowerCase();
      String tipoPerfil = profile.tipoPerfil.toLowerCase();
      String descripcion = profile.descripcion.toLowerCase();
      String barrio = profile.barrio.toLowerCase();

      double lat = profile.latLng.latitude;
      double lng = profile.latLng.longitude;

      double distanciaCalculada = _calcularDistanciaKm(
        centroReferencia.latitude, centroReferencia.longitude, lat, lng,
      );
      bool pasaFiltroRadio = distanciaCalculada <= radioKm;

      bool pasaFiltroCategoria = true;
      if (categoriaSeleccionada == 'Soy TUA2') {
        pasaFiltroCategoria = tipoPerfil.contains('freelance') || tipoPerfil.contains('tua2') || tipoPerfil.contains('profesional');
      } else if (categoriaSeleccionada == 'Negocios') {
        pasaFiltroCategoria = tipoPerfil.contains('pyme') || tipoPerfil.contains('negocio') || tipoPerfil.contains('comercio');
      } else if (categoriaSeleccionada == 'Venden') {
        pasaFiltroCategoria = tipoPerfil.contains('marketplace') || tipoPerfil.contains('producto') || tipoPerfil.contains('vendo');
      }

      bool pasaBusquedaTexto = true;
      if (_textoBusqueda.isNotEmpty) {
        pasaBusquedaTexto = nombre.contains(_textoBusqueda) ||
                            especialidad.contains(_textoBusqueda) ||
                            descripcion.contains(_textoBusqueda) ||
                            barrio.contains(_textoBusqueda) ||
                            profile.palabrasClave.any((p) => p.toLowerCase().contains(_textoBusqueda));
      }

      if (pasaFiltroRadio && pasaFiltroCategoria && pasaBusquedaTexto) {
        bool esFoco = widget.focusProfileId != null && widget.focusProfileId == profile.id;

        tempMarkers.add(
          Marker(
            markerId: MarkerId(profile.id),
            position: profile.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              esFoco ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: profile.nombre,
              snippet: '${profile.tipoPerfil.toUpperCase()} • ${profile.especialidad}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SocialProfileScreen(profile: profile, isOwner: false),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    setState(() {
      _markers.clear();
      _markers.addAll(tempMarkers);
      _circles.clear();
      _circles.addAll(tempCircles);
    });
  }

  void _mostrarModalAlarma() {
    final TextEditingController descripcionAlarmaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
            SizedBox(width: 8),
            Text('Generar Alarma', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Describe la situación o lo que necesitas reportar en tu zona:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descripcionAlarmaController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ej. Necesito ayuda con...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFFE53935), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              String descripcion = descripcionAlarmaController.text.trim();
              if (descripcion.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor escribe una descripción para la alarma.')),
                );
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('¡Alarma enviada con éxito a la comunidad!')),
              );
            },
            child: const Text('Enviar Alarma', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng targetPosition = widget.initialTarget ?? _currentCenterLocation;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: targetPosition, zoom: 14.5),
            markers: _markers,
            circles: _circles, // <-- Aquí se pinta el radio de acción en el mapa
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),

          Positioned(
            right: 16,
            bottom: 90,
            child: FloatingActionButton(
              heroTag: 'btnGpsMap',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 4,
              mini: true,
              onPressed: () => _irAUbicacionActual(esInicio: false),
              child: const Icon(Icons.my_location, color: Color(0xFFE53935)),
            ),
          ),

          // --- PANEL SUPERIOR ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ✅ Logo oficial de TUA2 insertado
SizedBox(
  height: 55, // Ajusta la altura según prefieras
  child: Image.asset(
    'assets/images/logo.png', // Reemplaza con la ruta exacta de tu logo en assets
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) {
      // Si por algo la imagen falla al cargar, muestra el texto como respaldo elegante
      return const Text(
        'TUA2',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: Color(0xFF111111),
          letterSpacing: -0.5,
        ),
      );
    },
  ),
),
                      Row(
                        children: [
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, color: Colors.black87, size: 26),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No hay notificaciones nuevas')),
                                  );
                                },
                              ),
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              if (_miPerfilCompleto != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SocialProfileScreen(profile: _miPerfilCompleto!, isOwner: true),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                                );
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                image: _miFotoUrl != null && _miFotoUrl!.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(_miFotoUrl!), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: _miFotoUrl == null || _miFotoUrl!.isEmpty
                                  ? const Icon(Icons.person, color: Colors.black54, size: 22)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Barra de Búsqueda
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '¿Qué necesitas o qué barrio buscas?',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15, fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search, color: Colors.black54),
                        suffixIcon: _textoBusqueda.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Botones de Categoría
                  Row(
                    children: [
                      Expanded(child: _buildCategoriaChip('Todo')),
                      const SizedBox(width: 6),
                      Expanded(child: _buildCategoriaChip('Soy TUA2')),
                      const SizedBox(width: 6),
                      Expanded(child: _buildCategoriaChip('Negocios')),
                      const SizedBox(width: 6),
                      Expanded(child: _buildCategoriaChip('Venden')),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- BARRA DEL RADAR DE ACCIÓN ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radar, color: Color(0xFFE53935), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Radio: ${radioKm.toStringAsFixed(0)} km',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                        Expanded(
                          child: Slider(
                            value: radioKm,
                            min: 1.0,
                            max: 20.0,
                            divisions: 19,
                            activeColor: const Color(0xFFE53935),
                            inactiveColor: Colors.grey.shade300,
                            onChanged: (double value) {
                              setState(() {
                                radioKm = value;
                                _actualizarMarcadoresYRadio();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BARRA INFERIOR ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    onPressed: _mostrarModalAlarma,
                    icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
                    label: const Text(
                      'Alarma',
                      style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 22),
                          SizedBox(width: 6),
                          Text(
                            'Registrar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaChip(String label) {
    bool seleccionado = categoriaSeleccionada == label;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: seleccionado ? const Color(0xFFE53935) : Colors.white,
        foregroundColor: seleccionado ? Colors.white : Colors.black87,
        elevation: 2,
        shadowColor: Colors.black26,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () {
        setState(() {
          categoriaSeleccionada = label;
          _actualizarMarcadoresYRadio();
        });
      },
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}