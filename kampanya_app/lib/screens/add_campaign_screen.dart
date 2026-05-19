import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import 'home_screen.dart';
import 'package:kampanya_app/services/api_client.dart'; // Ajanı çağırdık

class AddCampaignScreen extends StatefulWidget {
  const AddCampaignScreen({Key? key}) : super(key: key);

  @override
  State<AddCampaignScreen> createState() => _AddCampaignScreenState();
}

class _AddCampaignScreenState extends State<AddCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  // Text Controller'lar
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final districtController = TextEditingController();
  final addressController = TextEditingController();

  // Dropdown ve Tarih Değişkenleri
  String? selectedCategory;
  String? selectedCity;
  DateTime? selectedDate;

  final List<String> categories = ['Kahveci', 'Yemek', 'Hizmet', 'Giyim', 'Market'];
  final List<String> cities = ['İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Siirt'];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF7A00),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // GÜVENLİ KAYIT FONKSİYONU
  void _submitCampaign() async {
    if (!_formKey.currentState!.validate() || selectedCategory == null || selectedCity == null || selectedDate == null) {
      Get.snackbar('Eksik Bilgi', 'Lütfen tüm alanları doldurun.', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    setState(() => isLoading = true);

    try {
      // DİKKAT: Manuel Dio ve Token okuma bitti! 
      // Ajan (ApiClient.dio) bileti otomatik olarak kasadan alıp başlığa takacak.
      final response = await ApiClient.dio.post(
        '/api/campaigns',
        data: {
          'title': titleController.text,
          'description': descriptionController.text,
          'category': selectedCategory,
          'city': selectedCity,
          'district': districtController.text,
          'address': addressController.text,
          'end_date': selectedDate!.toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        Get.snackbar('Başarılı!', 'Kampanyanız yayına alındı 🚀', backgroundColor: Colors.green, colorText: Colors.white);
        Get.offAll(() => const HomeScreen()); // Listeyi yenilemek için Home'a dön
      }
    } on DioException catch (e) {
      // Ajan hatayı yakaladıysa detayını gösterelim
      String errMsg = e.response?.data?['error'] ?? 'Kampanya eklenemedi!';
      Get.snackbar('Hata', errMsg, backgroundColor: Colors.redAccent, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Hata', 'Beklenmedik bir hata oluştu.', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // KENDİ ELLERİMİZLE GERİ TUŞU EKLİYORUZ
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.offAll(() => const HomeScreen()), // Geri tuşu Home'a döndürür
        ),
        title: const Text('Yeni Kampanya Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFF7A00),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Kampanya Başlığı', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Başlık zorunludur' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Açıklama / Şartlar', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Açıklama zorunludur' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      value: selectedCategory,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Şehir', border: OutlineInputBorder()),
                      value: selectedCity,
                      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (val) => setState(() => selectedCity = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: districtController,
                decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'İlçe zorunludur' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Açık Adres', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Adres zorunludur' : null,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today, color: Color(0xFFFF7A00)),
                label: Text(
                  selectedDate == null 
                      ? 'Bitiş Tarihi Seçin' 
                      : 'Bitiş: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                  style: const TextStyle(color: Colors.black87),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitCampaign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Kampanyayı Yayınla 🚀', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}