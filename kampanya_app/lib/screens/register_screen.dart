import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:kampanya_app/config.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  void _register() async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty || passwordController.text.isEmpty) {
      Get.snackbar('Hata', 'Tüm alanları doldurun!', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Sonsuz beklemeyi önleyen 5 saniyelik sınır
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      
      final String backendUrl = AppConfig.baseUrl;

      final response = await dio.post(
        '$backendUrl/api/register',
        data: {
          'name': nameController.text,
          'phone': phoneController.text,
          'password': passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        Get.snackbar(
          'Başarılı', 
          'Kayıt başarıyla tamamlandı! Giriş yapabilirsiniz.', 
          backgroundColor: Colors.green, 
          colorText: Colors.white,
          duration: const Duration(seconds: 3)
        );

        // Textbox'ları temizle
        phoneController.clear();
        passwordController.clear();
        nameController.clear();

        // KESİN ÇÖZÜM: 2 saniye bekleyip Giriş Ekranına sıfırlayarak fırlatıyoruz
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const LoginScreen());
        });
      }
    } on DioException catch (e) {
      // Node.js'ten gelen X-Ray (Joi) hata mesajını paketin içinden çıkar!
      final String errorMessage = e.response?.data['message'] ?? e.response?.data['error'] ?? 'Kayıt başarısız oldu.';
      
      Get.snackbar('Hata', errorMessage, backgroundColor: Colors.orange, colorText: Colors.white, duration: const Duration(seconds: 4));
    } catch (e) {
      print("KAYIT HATASI DETAYI: $e");
      Get.snackbar('Hata', 'Bağlantı kurulamadı!', backgroundColor: Colors.red, colorText: Colors.white);
    } finally { 
      // Sayfa hala ekrandaysa yükleme animasyonunu durdur
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('İşletme Kayıt', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFFFF7A00)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'İşletme Adı', prefixIcon: Icon(Icons.store), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon Numarası', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre Belirle', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : _register,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A00)),
                child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Kayıt Ol', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}