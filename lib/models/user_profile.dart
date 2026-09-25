import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserProfile {
  final String id;
  final String tipoPerfil;
  final String nombre;
  final int edad;
  final String telefono;
  final String direccion;
  final String barrio;
  final String cedulaNit;
  final String especialidad;
  final String descripcion;
  final String? fotoUrl; // Agregado como opcional para evitar errores en vistas previas
  final LatLng latLng;
  final List<String> palabrasClave;

  UserProfile({
    required this.id,
    this.tipoPerfil = 'freelance',
    required this.nombre,
    this.edad = 0,
    required this.telefono,
    this.direccion = '',
    this.barrio = '',
    this.cedulaNit = '',
    this.especialidad = '',
    this.descripcion = '',
    this.fotoUrl,
    LatLng? latLng,
    List<String>? palabrasClave,
  })  : latLng = latLng ?? const LatLng(3.5394, -76.3036),
        palabrasClave = palabrasClave ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipoPerfil': tipoPerfil,
      'nombre': nombre,
      'edad': edad,
      'telefono': telefono,
      'direccion': direccion,
      'barrio': barrio,
      'cedulaNit': cedulaNit,
      'especialidad': especialidad,
      'descripcion': descripcion,
      'fotoUrl': fotoUrl,
      'latLng': {
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
      },
      'palabrasClave': palabrasClave,
    };
  }

  // Soporta tanto 1 argumento (map) como 2 argumentos (map, id) para compatibilidad total
  factory UserProfile.fromMap(Map<String, dynamic> map, [String? documentId]) {
    var latLngMap = map['latLng'] as Map<String, dynamic>? ?? {};
    double lat = latLngMap['latitude'] ?? 3.5394;
    double lng = latLngMap['longitude'] ?? -76.3036;

    return UserProfile(
      id: documentId ?? map['id'] ?? '',
      tipoPerfil: map['tipoPerfil'] ?? 'freelance',
      nombre: map['nombre'] ?? '',
      edad: map['edad'] ?? 0,
      telefono: map['telefono'] ?? '',
      direccion: map['direccion'] ?? '',
      barrio: map['barrio'] ?? '',
      cedulaNit: map['cedulaNit'] ?? '',
      especialidad: map['especialidad'] ?? '',
      descripcion: map['descripcion'] ?? '',
      fotoUrl: map['fotoUrl'],
      latLng: LatLng(lat, lng),
      palabrasClave: List<String>.from(map['palabrasClave'] ?? []),
    );
  }
}