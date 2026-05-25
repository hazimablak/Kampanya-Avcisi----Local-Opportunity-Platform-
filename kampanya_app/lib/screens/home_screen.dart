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
  
  List<dynamic> allDistrictsRaw = []; 
  List<String> cities = ['Tümü']; 
  List<String> currentDistricts = ['Tümü']; 

  @override
  void initState() {
    super.initState();
    isMerchant = storage.read('isMerchant') ?? false;
    userName = storage.read('userName') ?? 'Misafir';
    _loadCityData(); 
    _fetchCampaigns();
  }

  Future<void> _loadCityData() async {
    try {
      final String response = await rootBundle.loadString('assets/ilceler.json');
      final List<dynamic> data = json.decode(response);
      
      setState(() {
        allDistrictsRaw = data;
        Set<String> uniqueCities = data.map((item) => item['sehir_adi'].toString()).toSet();
        List<String> sortedCities = uniqueCities.toList()..sort();
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
        Get.back(); 
        try {
          final response = await ApiClient.dio.delete('/api/campaigns/$campaignId');
          if (response.statusCode == 200) {
            Get.snackbar('Başarılı', 'Kampanya silindi.', backgroundColor: Colors.green, colorText: Colors.white);
            _fetchCampaigns(); 
          }
        } on DioException catch (e) {
          String errMsg = e.response?.data?['message'] ?? 'Silinemedi.';
          Get.snackbar('Güvenlik Duvarı 🛡️', errMsg, backgroundColor: Colors.redAccent, colorText: Colors.white);
        }
      }
    );
  }

  void _logout() async {
    await secureStorage.deleteAll();
    storage.write('isMerchant', false);
    storage.remove('merchantPhone');
    storage.remove('isAdmin'); 
    Get.offAll(() => const LoginScreen());
    
    Get.snackbar('Çıkış Başarılı', 'Güvenli bir şekilde çıkış yaptınız.', backgroundColor: Colors.blueGrey, colorText: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
            IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout)
          else
            IconButton(icon: const Icon(Icons.login, color: Colors.white), onPressed: () => Get.offAll(() => const LoginScreen()))
        ],
      ),
      body: Column(
        children: [
          // ESKİ VE KULLANIŞLI DROPDOWN FİLTRELEME ÇUBUĞU
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true, // TAŞMAYI ÖNLEYEN SİHİRLİ KOD 1
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(),
                        ),
                        value: selectedCategory,
                        items: categories.map((c) => DropdownMenuItem(
                          value: c, 
                          child: Text(c, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis) // ÜÇ NOKTA KOYAN KOD
                        )).toList(),
                        onChanged: (val) {
                          setState(() => selectedCategory = val);
                          _fetchCampaigns(); 
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true, // TAŞMAYI ÖNLEYEN SİHİRLİ KOD 1
                        decoration: const InputDecoration(
                          labelText: 'Şehir',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(),
                        ),
                        value: selectedCity,
                        items: cities.map((c) => DropdownMenuItem(
                          value: c, 
                          child: Text(c, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis) // ÜÇ NOKTA KOYAN KOD
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedCity = val;
                            selectedDistrict = 'Tümü'; 
                            
                            if (val == 'Tümü' || val == null) {
                              currentDistricts = ['Tümü'];
                            } else {
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
                // İLÇE FİLTRESİ
                if (selectedCity != null && selectedCity != 'Tümü')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true, // TAŞMAYI ÖNLEYEN SİHİRLİ KOD
                      decoration: const InputDecoration(
                        labelText: 'İlçe',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedDistrict,
                      items: currentDistricts.map((c) => DropdownMenuItem(
                        value: c, 
                        child: Text(c, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)
                      )).toList(),
                      onChanged: (val) {
                        setState(() => selectedDistrict = val);
                        _fetchCampaigns(); 
                      },
                    ),
                  ),
              ],
            ),
          ),

          // MODERN KAMPANYA LİSTESİ (KARTLAR)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A00)))
                : campaigns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('Bu kriterlere uygun kampanya bulunamadı 😔', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        )
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 100),
                        itemCount: campaigns.length,
                        itemBuilder: (context, index) {
                          final camp = campaigns[index];
                          
                          String myPhone = storage.read('merchantPhone') ?? '';
                          bool isMyCampaign = isMerchant && myPhone.isNotEmpty && camp['merchant_phone'] == myPhone;

                          IconData catIcon = Icons.local_offer;
                          Color catColor = const Color(0xFFFF7A00);
                          switch(camp['category']) {
                            case 'Kahveci': catIcon = Icons.local_cafe; catColor = Colors.brown; break;
                            case 'Yemek': catIcon = Icons.restaurant; catColor = Colors.redAccent; break;
                            case 'Giyim': catIcon = Icons.checkroom; catColor = Colors.purple; break;
                            case 'Market': catIcon = Icons.shopping_basket; catColor = Colors.green; break;
                            case 'Hizmet': catIcon = Icons.build; catColor = Colors.blueGrey; break;
                          }

                          String timeRemaining = '';
                          Color timeColor = Colors.grey;
                          if(camp['end_date'] != null) {
                            try {
                              DateTime endDate = DateTime.parse(camp['end_date']);
                              int days = endDate.difference(DateTime.now()).inDays;
                              if (days < 0) { timeRemaining = 'Süresi Doldu'; timeColor = Colors.red; }
                              else if (days == 0) { timeRemaining = 'Son Gün!'; timeColor = Colors.orange; }
                              else { timeRemaining = 'Son $days Gün'; timeColor = Colors.green; }
                            } catch(e) {}
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05), 
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                )
                              ]
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0, top: 0, bottom: 0,
                                    child: Container(width: 6, color: catColor),
                                  ),
                                  
                                  Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                                  child: Icon(catIcon, color: catColor, size: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(camp['category'] ?? 'Genel', style: TextStyle(color: catColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                              ],
                                            ),
                                            if (timeRemaining.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(color: timeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                                child: Text(timeRemaining, style: TextStyle(color: timeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                              ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(camp['title'] ?? 'Başlıksız', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
                                            ),
                                            if (isMyCampaign)
                                              InkWell(
                                                onTap: () => _deleteCampaign(camp['id']),
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                                                  child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(camp['description'] ?? '', style: const TextStyle(color: Color(0xFF6B7280), height: 1.4, fontSize: 14)),
                                        
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12.0),
                                          child: Divider(color: Color(0xFFF3F4F6), thickness: 1.5),
                                        ),
                                        
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF9CA3AF)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('${camp['city']} / ${camp['district']}', style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 2),
                                                  Text(camp['address'] ?? '', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
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
              onPressed: () { Get.to(() => const AddCampaignScreen()); },
              backgroundColor: const Color(0xFFFF7A00),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Kampanya Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}