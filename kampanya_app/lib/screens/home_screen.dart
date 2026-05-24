import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart'; // İŞTE EKSİK OLAN HAYAT KURTARICI KOD BURADA!
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
  String? selectedCity;
  String? selectedCategory;

  // Örnek Kategori ve Şehir Listeleri
  final List<String> categories = ['Tümü', 'Kahveci', 'Yemek', 'Hizmet', 'Giyim', 'Market'];
  final List<String> cities = ['Tümü', 'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Siirt']; // Siirt'i buraya da ekledim :)

  @override
  void initState() {
    super.initState();
    isMerchant = storage.read('isMerchant') ?? false;
    userName = storage.read('userName') ?? 'Misafir';
    _fetchCampaigns();
  }

  Future<void> _fetchCampaigns() async {
    setState(() => isLoading = true);
    try {
      Map<String, dynamic> queryParams = {};
      if (selectedCity != null && selectedCity != 'Tümü') queryParams['city'] = selectedCity;
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
      print("KAMPANYA ÇEKME HATASI: $e");
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
          // Ajanı (ApiClient) göreve yolla
          final response = await ApiClient.dio.delete('/api/campaigns/$campaignId');
          if (response.statusCode == 200) {
            Get.snackbar('Başarılı', 'Kampanya silindi.', backgroundColor: Colors.green, colorText: Colors.white);
            _fetchCampaigns(); // Listeyi güncelle
          }
        } on DioException catch (e) {
          // EĞER BAŞKASININ KAMPANYASINI SİLMEYE ÇALIŞIRSA BACKEND BURAYA HATA FIRLATIR!
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
          // FİLTRELEME ÇUBUĞU
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Şehir Seç',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(),
                    ),
                    value: selectedCity,
                    items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      setState(() => selectedCity = val);
                      _fetchCampaigns(); 
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Kategori Seç',
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(),
                    ),
                    value: selectedCategory,
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      setState(() => selectedCategory = val);
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
                          
                          // KİMLİK KONTROLLERİNİ BURAYA (ARAYÜZ ÇİZİLMEDEN ÖNCEYE) ALDIK!
                          String myPhone = storage.read('merchantPhone') ?? '';
                          String adminPhone = '5303611650'; // Kendi numaranı buraya yaz
                          bool isAdmin = myPhone == adminPhone;
                          bool isMyCampaign = camp['merchant_phone'] == myPhone;

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
                                      // SADECE ADMİN VEYA KAMPANYA SAHİBİ ÇÖP KUTUSUNU GÖRÜR
                                      if (isAdmin || isMyCampaign)
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
      
      // ESNAF İÇİN "KAMPANYA EKLE" BUTONU
      floatingActionButton: isMerchant
          ? FloatingActionButton.extended(
              onPressed: () {
                // Get.offAll YERİNE Get.to KULLANIYORUZ Kİ GERİ TUŞU ÇALIŞSIN!
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