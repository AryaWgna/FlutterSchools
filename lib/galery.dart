// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<dynamic> galleryItems = [];
  bool isLoading = true;
  String errorMessage = '';
 
  @override
  void initState() {
    super.initState();
    fetchGalleryItems();
  }

  final baseUrl = 'https://praktikum-cpanel-unbin.com/solev/antum/galery.php';
  final imageBaseUrl = 'https://praktikum-cpanel-unbin.com/solev/antum/images/';

  Future<void> fetchGalleryItems() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?action=get'));
      if (response.statusCode == 200) {
        String cleanedResponse = response.body.replaceFirst('Koneksi berhasil!', '');
        final decodedData = json.decode(cleanedResponse);
        if (decodedData is List) {
          setState(() {
            galleryItems = decodedData.map((item) {
              if (item['images'] != null && item['images'].isNotEmpty) {
                // Hapus 'images/' dari path jika sudah ada di imageBaseUrl
                String imagePath = item['images'].startsWith('images/') 
                    ? item['images'].substring(7) 
                    : item['images'];
                item['imageUrl'] = Uri.encodeFull('$imageBaseUrl$imagePath');
              } else {
                // Gunakan gambar placeholder jika tidak ada gambar
                item['imageUrl'] = 'https://picsum.photos/seed/${item['kd_galery']}/300/200';
              }
              return item;
            }).toList();
            isLoading = false;
            errorMessage = '';
          });
        } else if (decodedData is Map && decodedData.containsKey('error')) {
          throw Exception(decodedData['error']);
        } else {
          throw Exception('Format data tidak sesuai');
        }
      } else {
        throw Exception('Respons server tidak valid: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal memuat data: $e';
      });
      _showErrorSnackBar(errorMessage);
    }
  }

  Future<void> addGalleryItem(Map<String, dynamic> newItem, File? imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl?action=add'));
      request.fields['judul_galery'] = newItem['judul_galery'];
      request.fields['tgl_post_galery'] = newItem['tgl_post_galery'];
      request.fields['status_galery'] = newItem['status_galery'];
      request.fields['kd_petugas'] = newItem['kd_petugas'];
      
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String cleanedResponse = response.body.replaceFirst('Koneksi berhasil!', '');
        final decodedData = json.decode(cleanedResponse);
        if (decodedData.containsKey('error')) {
          throw Exception(decodedData['error']);
        }
        await fetchGalleryItems();
        _showSuccessSnackBar('Item berhasil ditambahkan');
      } else {
        throw Exception('Gagal menambahkan item: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal menambahkan item: $e');
    }
  }

  Future<void> updateGalleryItem(String kdGalery, Map<String, dynamic> updatedItem, File? imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl?action=update&id=$kdGalery'));
      request.fields['judul_galery'] = updatedItem['judul_galery'];
      request.fields['tgl_post_galery'] = updatedItem['tgl_post_galery'];
      request.fields['status_galery'] = updatedItem['status_galery'];
      request.fields['kd_petugas'] = updatedItem['kd_petugas'];
      
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String cleanedResponse = response.body.replaceFirst('Koneksi berhasil!', '');
        final decodedData = json.decode(cleanedResponse);
        if (decodedData.containsKey('error')) {
          throw Exception(decodedData['error']);
        }
        await fetchGalleryItems();
        _showSuccessSnackBar('Item berhasil diperbarui');
      } else {
        throw Exception('Gagal memperbarui item: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memperbarui item: $e');
    }
  }

  Future<void> deleteGalleryItem(String kdGalery) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=delete&id=$kdGalery'),
      );
      if (response.statusCode == 200) {
        String cleanedResponse = response.body.replaceFirst('Koneksi berhasil!', '');
        final decodedData = json.decode(cleanedResponse);
        if (decodedData.containsKey('error')) {
          throw Exception(decodedData['error']);
        }
        await fetchGalleryItems();
        _showSuccessSnackBar('Item berhasil dihapus');
      } else {
        throw Exception('Gagal menghapus item: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Gagal menghapus item: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> showAddEditDialog({Map<String, dynamic>? item}) async {
    final isEditing = item != null;
    final titleController = TextEditingController(text: item?['judul_galery'] ?? '');
    File? imageFile;

    final ImagePicker picker = ImagePicker();

    Future<void> pickImage() async {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          imageFile = File(pickedFile.path);
        });
      }
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Galeri' : 'Tambah Galeri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: pickImage,
              child: const Text('Pilih Gambar'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newItem = {
                'judul_galery': titleController.text,
                'tgl_post_galery': DateTime.now().toIso8601String(),
                'status_galery': 'active',
                'kd_petugas': '1',
              };
              if (isEditing) {
                await updateGalleryItem(item['kd_galery'], newItem, imageFile);
              } else {
                await addGalleryItem(newItem, imageFile);
              }
              Navigator.pop(context);
            },
            child: Text(isEditing ? 'Simpan' : 'Tambah'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: galleryItems.length,
                  itemBuilder: (context, index) {
                    return FadeInUp(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      child: GalleryItem(
                        item: galleryItems[index],
                        onEdit: () => showAddEditDialog(item: galleryItems[index]),
                        onDelete: () => deleteGalleryItem(galleryItems[index]['kd_galery']),
                        isDarkMode: isDarkMode,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddEditDialog(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class GalleryItem extends StatelessWidget {
  final dynamic item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDarkMode;

  const GalleryItem({Key? key, required this.item, required this.onEdit, required this.onDelete, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final judulGalery = item['judul_galery'] as String? ?? 'Galeri';
    final imageUrl = item['imageUrl'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image: $error');
                return Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(child: Text('Gambar tidak tersedia')),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judulGalery,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tanggal: ${item['tgl_post_galery'] ?? 'Tanggal tidak tersedia'}',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: isDarkMode ? Colors.white70 : Theme.of(context).primaryColor),
                onPressed: onEdit,
              ),
              IconButton(
                icon: Icon(Icons.delete, color: isDarkMode ? Colors.white70 : Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}