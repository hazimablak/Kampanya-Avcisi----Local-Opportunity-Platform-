import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kampanya_app/services/api_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final storage = GetStorage();
  bool isLoading = false;
  final secureStorage = const FlutterSecureStorage();

  // YENİ ÖZELLİKLERİN STATE DEĞİŞKENLERİ
  bool _obscurePassword = true; // Şifre gizli mi açık mı?
  bool _rememberMe = false;     // Beni hatırla seçili mi?

  @override
  void initState() {
    super.initState();
    // BENI HATIRLA KONTROLÜ: Uygulama açılınca hafızaya bak
    if (storage.read('rememberMe') == true) {
      _rememberMe = true;
      phoneController.text = storage.read('savedPhone') ?? '';
      passwordController.text = storage.read('savedPassword') ?? '';
    }
  }

  void _merchantLogin() async {
    if (phoneController.text.isEmpty || passwordController.text.isEmpty) {
      Get.snackbar('Hata', 'Telefon ve şifre zorunludur!', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/api/login',
        data: {
          'phone': phoneController.text,
          'password': passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        // BAŞARILI GİRİŞ YAZISI
        Get.snackbar('Başarılı', 'Giriş onaylandı! Hoş geldiniz.', backgroundColor: Colors.green, colorText: Colors.white);

        // BENİ HATIRLA İŞLEMİ
        if (_rememberMe) {
          storage.write('rememberMe', true);
          storage.write('savedPhone', phoneController.text);
          storage.write('savedPassword', passwordController.text); // Güvenlik için local storage'da tutulur
        } else {
          // Seçili değilse hafızayı temizle
          storage.remove('rememberMe');
          storage.remove('savedPhone');
          storage.remove('savedPassword');
        }

        await secureStorage.write(key: 'accessToken', value: response.data['accessToken']);
        await secureStorage.write(key: 'refreshToken', value: response.data['refreshToken']);
        
        storage.write('isMerchant', true); 
        storage.write('merchantPhone', phoneController.text);
        storage.write('isAdmin', response.data['isAdmin']);

        // Ana sayfaya geçiş
        Future.delayed(const Duration(seconds: 1), () {
          Get.offAll(() => const HomeScreen());
        });
      }
    } on DioException catch (e) {
      // HATA ANINDA TEXTBOX'LARI TEMİZLE
      phoneController.clear();
      passwordController.clear();

      if (e.response?.statusCode == 401) {
        Get.snackbar('Hata', 'Numara veya şifre hatalı!', backgroundColor: Colors.redAccent, colorText: Colors.white);
      } else if (e.response?.statusCode == 429) {
        Get.snackbar('🛡️ Engellendi', e.response?.data['message'] ?? 'Çok fazla deneme yaptınız.', backgroundColor: Colors.orange, colorText: Colors.white);
      } else {
        Get.snackbar('Hata', 'Bağlantı kurulamadı!', backgroundColor: Colors.redAccent, colorText: Colors.white);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _guestLogin() {
    storage.write('isMerchant', false);
    storage.write('userName', 'Misafir');
    Get.offAll(() => const HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.local_offer, size: 80, color: Color(0xFFFF7A00)),
              const SizedBox(height: 16),
              const Text(
                'Kampanya Avcısı',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _guestLogin,
                icon: const Icon(Icons.explore, color: Colors.white, size: 28),
                label: const Text('Kayıt Olmadan Keşfet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 30),
              const Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('VEYA ESNAF GİRİŞİ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                  Expanded(child: Divider(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),

              // Telefon (Enter basınca şifreye zıplasın)
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next, 
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası',
                  prefixIcon: const Icon(Icons.store, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Şifre (Göz ikonu ve Enter ile Giriş özelliği eklendi)
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _merchantLogin(), // ENTER TUŞUNA BASINCA ÇALIŞIR!
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  // GÖZ İKONU KATMANI
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              // BENİ HATIRLA & ŞİFREMİ UNUTTUM SATIRI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        activeColor: const Color(0xFFFF7A00),
                        value: _rememberMe,
                        onChanged: (value) => setState(() => _rememberMe = value ?? false),
                      ),
                      const Text('Beni Hatırla', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Get.snackbar('Şifre Yenileme', 'Şifre sıfırlama kodu SMS olarak gönderildi (Simüle edildi).', 
                          backgroundColor: Colors.blue, colorText: Colors.white);
                    },
                    child: const Text('Şifremi Unuttum', style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 55,
                child: OutlinedButton(
                  onPressed: isLoading ? null : _merchantLogin,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Color(0xFFFF7A00))
                      : const Text('İşletme Sahibi Girişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF7A00))),
                ),
              ),
              TextButton(
                onPressed: () => Get.to(() => const RegisterScreen()),
                child: const Text('İşletmeniz yok mu? Hemen Kayıt Olun', style: TextStyle(color: Color(0xFFFF7A00))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}