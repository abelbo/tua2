import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'map_screen.dart' as map;
import 'edit_profile_screen.dart';

class SocialProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final bool isOwner; // Define si es el dueño o un buscador

  const SocialProfileScreen({
    super.key, 
    required this.profile, 
    this.isOwner = false,
  });

  @override
  State<SocialProfileScreen> createState() => _SocialProfileScreenState();
}

class _SocialProfileScreenState extends State<SocialProfileScreen> {
  bool _isUploadingPhoto = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.profile.fotoUrl;
  }

  Future<void> _cambiarFotoPerfil() async {
    if (!widget.isOwner) return;

    final ImagePicker picker = ImagePicker();
    
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFE53935)),
                title: const Text('Galería de fotos'),
                onTap: () async {
                  final pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (!context.mounted) return;
                  Navigator.pop(context, pickedImage);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFE53935)),
                title: const Text('Tomar una foto'),
                onTap: () async {
                  final pickedImage = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (!context.mounted) return;
                  Navigator.pop(context, pickedImage);
                },
              ),
            ],
          ),
        );
      },
    );

    if (image == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      File file = File(image.path);
      String filePath = 'profile_images/${widget.profile.id}.jpg';

      Reference ref = FirebaseStorage.instance.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(widget.profile.id)
          .update({'fotoUrl': downloadUrl});

      setState(() {
        _photoUrl = downloadUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto de perfil actualizada con éxito!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la foto: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String handle = '@${widget.profile.nombre.toLowerCase().replaceAll(' ', '')}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          handle,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.black87),
            tooltip: 'Ver en el mapa',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => map.MapScreen(
                    initialTarget: widget.profile.latLng,
                    focusProfileId: widget.profile.id,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: widget.isOwner && !_isUploadingPhoto ? _cambiarFotoPerfil : null,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFFE53935),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                              ? NetworkImage(_photoUrl!) as ImageProvider
                              : const AssetImage('assets/images/logo.png'),
                        ),
                      ),
                      if (widget.isOwner)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _isUploadingPhoto
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.nombre,
                        style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${widget.profile.tipoPerfil.toUpperCase()} • ${widget.profile.especialidad}',
                          style: const TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.profile.descripcion,
                        style: const TextStyle(color: Colors.black87, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- BOTÓN EDITAR PERFIL (SOLO DUEÑO) ---
            if (widget.isOwner) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE53935)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  
                  onPressed: () {
                     Navigator.push(
                      context,
                     MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                         profileId: widget.profile.id,
                      ),
                    ),
                  );
                },
                  child: const Text('Editar mi Vitrina', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos de Contacto y Ubicación',
                    style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 16),
                  _buildInfoRow(Icons.cake_outlined, 'Edad: ${widget.profile.edad} años'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.location_on_outlined, 'Domicilio: ${widget.profile.direccion}'),
                  const SizedBox(height: 12),
                  
                  if (!widget.isOwner) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => map.MapScreen(
                                initialTarget: widget.profile.latLng,
                                focusProfileId: widget.profile.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map, color: Colors.white, size: 16),
                        label: const Text('Ver ubicación en el Mapa', style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Abriendo chat de WhatsApp...')),
                        );
                      },
                      icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                      label: const Text('Contactar por WhatsApp (Mensaje TUA2)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Galería de Trabajos',
                  style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (widget.isOwner)
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Función de galería en desarrollo')),
                      );
                    },
                    icon: const Icon(Icons.add_a_photo, size: 15, color: Color(0xFFE53935)),
                    label: const Text('Subir foto', style: TextStyle(color: Color(0xFFE53935), fontSize: 13)),
                  ),
              ],
            ),

            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildGalleryItem('assets/images/logo.png'),
                  _buildGalleryItem('assets/images/logo.png'),
                  _buildGalleryItem('assets/images/logo.png'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reseñas y Opiniones',
                  style: TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Ver todas', style: TextStyle(color: Color(0xFFE53935), fontSize: 13)),
                ),
              ],
            ),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 18, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white, size: 18)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Excelente trabajo profesional', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Muy recomendado, cumplió con los tiempos y detalles.', style: TextStyle(color: Colors.black54, fontSize: 11)),
                      ],
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.star, color: Colors.amber, size: 15),
                      Text(' 5.0', style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFE53935), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black87, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryItem(String imagePath) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade200,
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}