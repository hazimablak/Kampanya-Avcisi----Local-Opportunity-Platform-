import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'home_screen.dart';
import 'package:kampanya_app/services/api_client.dart';

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
  final addressController = TextEditingController();

  // Dropdown ve Tarih Değişkenleri
  String? selectedCategory;
  String? selectedCity;
  String? selectedDistrict; 
  DateTime? selectedDate;

  final List<String> categories = ['Kahveci', 'Yemek', 'Hizmet', 'Giyim', 'Market'];
  
  // YENİ FLAT JSON YAPISI İÇİN DEĞİŞKENLER
  List<dynamic> allDistrictsRaw = []; // Tüm JSON verisi buraya dolacak
  List<String> cities = [];           // Tekilleştirilmiş şehir isimleri
  List<String> currentDistricts = []; // Seçilen şehre ait ilçeler

  @override
  void initState() {
    super.initState();
    _loadCityData(); 
  }

  // FLAT JSON OKUMA VE ŞEHİRLERİ AYIKLAMA ZEKASI
  Future<void> _loadCityData() async {
    try {
      final String response = await rootBundle.loadString('assets/ilceler.json');
      final List<dynamic> data = json.decode(response);
      
      setState(() {
        allDistrictsRaw = data;
        
        // SÜPER ZEKİ DOKUNUŞ: Set kullanarak şehir isimlerini tekilleştiriyoruz
        Set<String> uniqueCities = data.map((item) => item['sehir_adi'].toString()).toSet();
        
        cities = uniqueCities.toList();
        cities.sort(); // Şehirleri alfabetik sıraya diz
      });
    } catch (e) {
      debugPrint("JSON Yükleme Hatası: $e");
      Get.snackbar('Hata', 'İlçe verisi okunamadı: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

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

  void _submitCampaign() async {
    if (!_formKey.currentState!.validate() || selectedCategory == null || selectedCity == null || selectedDistrict == null || selectedDate == null) {
      Get.snackbar('Eksik Bilgi', 'Lütfen tüm alanları (İlçe dahil) doldurun.', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/api/campaigns',
        data: {
          'title': titleController.text,
          'description': descriptionController.text,
          'category': selectedCategory,
          'city': selectedCity,
          'district': selectedDistrict, 
          'address': addressController.text,
          'end_date': selectedDate!.toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        Get.snackbar('Başarılı!', 'Kampanyanız yayına alındı 🚀', backgroundColor: Colors.green, colorText: Colors.white);
        Get.offAll(() => const HomeScreen()); 
      }
    } on DioException catch (e) {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.offAll(() => const HomeScreen()), 
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
                  // KATEGORİ
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true, // TAŞMAYI ÖNLEYEN SİHİRLİ KOD
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      value: selectedCategory,
                      items: categories.map((c) => DropdownMenuItem(
                        value: c, 
                        child: Text(c, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)
                      )).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // AKILLI İL KUTUSU
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true, // TAŞMAYI ÖNLEYEN SİHİRLİ KOD
                      decoration: const InputDecoration(labelText: 'İl', border: OutlineInputBorder()),
                      value: selectedCity,
                      items: cities.map((c) => DropdownMenuItem(
                        value: c, 
                        child: Text(c, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)
                      )).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          selectedCity = val;
                          selectedDistrict = null; 
                          
                          currentDistricts = allDistrictsRaw
                              .where((item) => item['sehir_adi'].toString() == val)
                              .map((item) => item['ilce_adi'].toString())
                              .toList();
                          
                          currentDistricts.sort(); 
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // AKILLI İLÇE KUTUSU (Tek ve kusursuz hali)
              DropdownButtonFormField<String>(
                isExpanded: true, // TAŞMAYI ÖNLEYEN SİHİRLİ KOD
                decoration: const InputDecoration(labelText: 'İlçe', border: OutlineInputBorder()),
                value: selectedDistrict,
                items: currentDistricts.map((d) => DropdownMenuItem(
                  value: d, 
                  child: Text(d, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)
                )).toList(),
                onChanged: (val) => setState(() => selectedDistrict = val),
                disabledHint: const Text('Önce İl Seçiniz'),
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