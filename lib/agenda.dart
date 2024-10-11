import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:animate_do/animate_do.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  _AgendaScreenState createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  List<dynamic> agendaItems = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchAgendaItems();
  }

  final baseUrl = 'https://praktikum-cpanel-unbin.com/solev/antum/agenda.php';

  Future<void> fetchAgendaItems() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?action=get'));
      if (response.statusCode == 200) {
        String cleanedResponse = response.body.replaceFirst('Koneksi berhasil!', '');
        final decodedData = json.decode(cleanedResponse);
        if (decodedData is List) {
          setState(() {
            agendaItems = decodedData;
            isLoading = false;
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
    }
  }

  Future<void> addAgendaItem(Map<String, dynamic> newItem) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=add'),
        body: json.encode(newItem),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData.containsKey('error')) {
          throw Exception(decodedData['error']);
        }
        await fetchAgendaItems();
      } else {
        throw Exception('Gagal menambahkan item: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal menambahkan item: $e';
      });
    }
  }

  Future<void> updateAgendaItem(String kdAgenda, Map<String, dynamic> updatedItem) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update&id=$kdAgenda'),
        body: json.encode(updatedItem),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData.containsKey('error')) {
          throw Exception(decodedData['error']);
        }
        await fetchAgendaItems();
      } else {
        throw Exception('Gagal memperbarui item: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal memperbarui item: $e';
      });
    }
  }

  Future<void> deleteAgendaItem(String kdAgenda) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl?action=delete&id=$kdAgenda'),
      );
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData.containsKey('error')) {
          throw Exception(decodedData['error']);
        }
        await fetchAgendaItems();
      } else {
        throw Exception('Gagal menghapus item: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal menghapus item: $e';
      });
    }
  }

  void showAddEditDialog({Map<String, dynamic>? item}) {
    final isEditing = item != null;
    final titleController = TextEditingController(text: item?['judul_agenda'] ?? '');
    final contentController = TextEditingController(text: item?['isi_agenda'] ?? '');
    final dateController = TextEditingController(text: item?['tgl_agenda'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Agenda' : 'Tambah Agenda'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Isi'),
                maxLines: 3,
              ),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'Tanggal'),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    dateController.text = pickedDate.toIso8601String().split('T')[0];
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newItem = {
                'judul_agenda': titleController.text,
                'isi_agenda': contentController.text,
                'tgl_agenda': dateController.text,
                'status_agenda': 'active',
                'kd_petugas': '1',
              };
              if (isEditing) {
                updateAgendaItem(item['kd_agenda'], newItem);
              } else {
                addAgendaItem(newItem);
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
              : agendaItems.isEmpty
                  ? const Center(child: Text('Tidak ada data'))
                  : ListView.builder(
                      itemCount: agendaItems.length,
                      itemBuilder: (context, index) {
                        return FadeInUp(
                          duration: Duration(milliseconds: 300 + (index * 100)),
                          child: AgendaItem(
                            item: agendaItems[index],
                            onEdit: () => showAddEditDialog(item: agendaItems[index]),
                            onDelete: () => deleteAgendaItem(agendaItems[index]['kd_agenda']),
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

class AgendaItem extends StatelessWidget {
  final dynamic item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDarkMode;

  const AgendaItem({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: ExpansionTile(
        title: Text(
          item['judul_agenda'] ?? 'Judul tidak tersedia',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDarkMode ? Colors.white : Theme.of(context).primaryColor,
          ),
        ),
        subtitle: Text(
          'Tanggal: ${item['tgl_agenda'] ?? 'Tanggal tidak tersedia'}',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: isDarkMode ? Colors.white70 : Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              item['isi_agenda'] ?? 'Konten tidak tersedia',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}