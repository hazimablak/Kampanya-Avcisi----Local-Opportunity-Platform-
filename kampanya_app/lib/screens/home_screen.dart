import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart'; 
import 'package:kampanya_app/services/api_client.dart';
import 'package:kampanya_app/config.dart';
import 'login_screen.dart';
import 'add_campaign_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = GetStorage();
  final secureStorage = const FlutterSecureStorage(); 
  
  bool isMerchant = false;
  String userName = '';
  List<dynamic> campaigns = [];
  bool isLoading = true;

  // Filtre Değişkenleri
  String? selectedCity = 'Tümü';
  String? selectedDistrict = 'Tümü';
  String? selectedCategory = 'Tümü';

  final List<String> categories = ['Tümü', 'Kahveci', 'Yemek', 'Hizmet', 'Giyim', 'Market'];
  
  // JSON'dan Dolacak Filtre Listeleri
  List<dynamic> allDistrictsRaw = []; 
  List<String> cities = ['Tümü']; 
  List<String> currentDistricts = ['Tümü']; 

  @override
  void initState() {
    super.initState();
    isMerchant = storage.read('isMerchant') ?? false;
    userName = storage.read('userName') ?? 'Misafir';
    _loadCityData(); // JSON verilerini yükle
    _fetchCampaigns();
  }

  // FLAT JSON OKUMA VE ŞEHİRLERİ AYIKLAMA (Filtreleme İçin)
  Future<void> _loadCityData() async {
    try {
      final String response = await rootBundle.loadString('assets/ilceler.json');
      final List<dynamic> data = json.decode(response);
      
      setState(() {
        allDistrictsRaw = data;
        
        // Şehirleri tekilleştir ve sırala
        Set<String> uniqueCities = data.map((item) => item['sehir_adi'].toString()).toSet();
        List<String> sortedCities = uniqueCities.toList()..sort();
        
        // 'Tümü' seçeneğini en başa ekleyerek listeyi güncelle
        cities = ['Tümü', ...sortedCities];
      });
    } catch (e) {
      debugPrint("JSON Yükleme Hatası: $e");
    }
  }

  Future<void> _fetchCampaigns() async {
    setState(() => isLoading = true);
    try {
      Map<String, dynamic> queryParams = {};
      if (selectedCity != null && selectedCity != 'Tümü') queryParams['city'] = selectedCity;
      if (selectedDistrict != null && selectedDistrict != 'Tümü') queryParams['district'] = selectedDistrict;
      if (selectedCategory != null && selectedCategory != 'Tümü') queryParams['category'] = selectedCategory;

      final response = await ApiClient.dio.get(
        '${AppConfig.baseUrl}/api/campaigns', 
        queryParameters: queryParams
      );
      
      if (response.statusCode == 200) {
        setState(() {
          campaigns = response.data;
        });
      }
    } catch (e) {
      debugPrint("KAMPANYA ÇEKME HATASI: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // KAMPANYA SİLME FONKSİYONU
  void _deleteCampaign(int campaignId) async {
    Get.defaultDialog(
      title: 'Kampanyayı Sil',
      middleText: 'Bu kampanyayı silmek istediğinize emin misiniz?',
      textCancel: 'İptal',
      textConfirm: 'Evet, Sil',
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      cancelTextColor: Colors.black,
      onConfirm: () async {
        Get.back(); // Dialogu kapat
        try {
          final response = await ApiClient.dio.delete('/api/campaigns/$campaignId');
          if (response.statusCode == 200) {
            Get.snackbar('Başarılı', 'Kampanya silindi.', backgroundColor: Colors.green, colorText: Colors.white);
            _fetchCampaigns(); // Listeyi güncelle
          }
        } on DioException catch (e) {
          String errMsg = e.response?.data?['message'] ?? 'Silinemedi.';
          Get.snackbar('Güvenlik Duvarı 🛡️', errMsg, backgroundColor: Colors.redAccent, colorText: Colors.white);
        }
      }
    );
  }

  // GÜVENLİ ÇIKIŞ FONKSİYONU
  void _logout() async {
    await secureStorage.deleteAll();
    storage.write('isMerchant', false);
    storage.remove('merchantPhone');
    storage.remove('isAdmin'); // Admin yetkisini de hafızadan temizle
    Get.offAll(() => const LoginScreen());
    
    Get.snackbar('Çıkış Başarılı', 'Güvenli bir şekilde çıkış yaptınız.', 
        backgroundColor: Colors.blueGrey, colorText: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kampanya Avcısı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
            Text('Hoş geldin, $userName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFFFF7A00),
        elevation: 0,
        actions: [
          if (isMerchant)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
            )
          else
            IconButton(
              icon: const Icon(Icons.login, color: Colors.white),
              onPressed: () => Get.offAll(() => const LoginScreen()),
            )
        ],
      ),
      body: Column(
        children: [
          // GELİŞMİŞ FİLTRELEME ÇUBUĞU (Kategori, Şehir, İlçe)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(),
                        ),
                        value: selectedCategory,
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) {
                          setState(() => selectedCategory = val);
                          _fetchCampaigns(); 
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Şehir',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(),
                        ),
                        value: selectedCity,
                        items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedCity = val;
                            selectedDistrict = 'Tümü'; // Şehir değiştiğinde ilçeyi sıfırla
                            
                            if (val == 'Tümü' || val == null) {
                              currentDistricts = ['Tümü'];
                            } else {
                              // JSON'dan sadece o şehrin ilçelerini bul
                              List<String> dists = allDistrictsRaw
                                  .where((item) => item['sehir_adi'].toString() == val)
                                  .map((item) => item['ilce_adi'].toString())
                                  .toList();
                              dists.sort();
                              currentDistricts = ['Tümü', ...dists];
                            }
                            _fetchCampaigns(); 
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // İLÇE FİLTRESİ SADECE ŞEHİR SEÇİLİNCE GÖRÜNSÜN
                if (selectedCity != null && selectedCity != 'Tümü')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'İlçe',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedDistrict,
                      items: currentDistricts.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (val) {
                        setState(() => selectedDistrict = val);
                        _fetchCampaigns(); 
                      },
                    ),
                  ),
              ],
            ),
          ),

          // KAMPANYA LİSTESİ
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00)))
                : campaigns.isEmpty
                    ? const Center(child: Text('Bu kriterlere uygun kampanya bulunamadı 😔', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                        itemCount: campaigns.length,
                        itemBuilder: (context, index) {
                          final camp = campaigns[index];
                          
                          // GÜVENLİK GÜNCELLEMESİ: ADMİN YETKİSİ TAMAMEN KALDIRILDI!
                          String myPhone = storage.read('merchantPhone') ?? '';
                          
                          // Çöp kutusunu SADECE kampanya, sisteme giren esnafa aitse göster (Misafir kesinlikle göremez)
                          bool isMyCampaign = isMerchant && myPhone.isNotEmpty && camp['merchant_phone'] == myPhone;

                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        label: Text(camp['category'] ?? 'Genel', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        backgroundColor: const Color(0xFFFF7A00),
                                      ),
                                      Text('${camp['city']} / ${camp['district']}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // BAŞLIK VE SİL BUTONU SATIRI
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          camp['title'] ?? 'Başlıksız',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      // SİL BUTONU ARTIK SADECE "isMyCampaign" TRUE İSE GÖRÜNÜR
                                      if (isMyCampaign)
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: () => _deleteCampaign(camp['id']),
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 8),
                                  Text(
                                    camp['description'] ?? '',
                                    style: const TextStyle(color: Colors.black87),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(camp['address'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      
      floatingActionButton: isMerchant
          ? FloatingActionButton.extended(
              onPressed: () {
                Get.to(() => const AddCampaignScreen()); 
              },
              backgroundColor: const Color(0xFFFF7A00),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Kampanya Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}