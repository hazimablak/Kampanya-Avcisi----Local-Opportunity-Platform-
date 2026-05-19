import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:kampanya_app/config.dart';
import 'package:kampanya_app/screens/login_screen.dart';
import 'package:flutter/material.dart';

class ApiClient {
  static final Dio dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  
  static const secureStorage = FlutterSecureStorage();

  // Ajanı başlatan fonksiyon
  static void setup() {
    dio.interceptors.add(InterceptorsWrapper(
      
      // 1. HER İSTEKTEN ÖNCE ÇALIŞAN KISIM (Kapıdan çıkarken)
      onRequest: (options, handler) async {
        final token = await secureStorage.read(key: 'accessToken');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token'; // Bileti yakana tak
        }
        return handler.next(options);
      },

      // 2. HATA ALINCA ÇALIŞAN KISIM (Görevli seni çevirirse)
      onError: (DioException e, handler) async {
        // Eğer hata 401 (Biletin Süresi Bitti) veya 403 ise araya gir!
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          final refreshToken = await secureStorage.read(key: 'refreshToken');
          
          if (refreshToken != null) {
            try {
              // Görevliye çaktırmadan VIP kartı verip yeni bilet iste
              final refreshResponse = await Dio().post(
                '${AppConfig.baseUrl}/api/refresh',
                data: {'refreshToken': refreshToken},
              );
              
              // Yeni yaka kartını al ve kasaya koy
              final newAccessToken = refreshResponse.data['accessToken'];
              await secureStorage.write(key: 'accessToken', value: newAccessToken);
              
              // Esnafın yarım kalan isteğine yeni bileti tak ve işlemi tekrarla!
              e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final retryResponse = await dio.fetch(e.requestOptions);
              
              return handler.resolve(retryResponse); // İşlem başarılı, yola devam!
              
            } catch (refreshError) {
              // Eğer VIP kartın da süresi bitmişse her şeyi sil ve dışarı at!
              await secureStorage.deleteAll();
              
              // İSİM YERİNE DOĞRUDAN SAYFAYA YÖNLENDİRİYORUZ!
              Get.offAll(() => const LoginScreen()); 
              
              Get.snackbar('Oturum Kapandı', 'Lütfen tekrar giriş yapın.', backgroundColor: Colors.orange, colorText: Colors.white);
            }
          }
        }
        return handler.next(e);
      },
    ));
  }
}