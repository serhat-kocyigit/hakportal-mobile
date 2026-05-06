# HakPortal Mobile ⚖️

HakPortal Mobile, modern hukuk süreçlerini dijitalleştiren, müvekkil ve avukatlar arasındaki iletişimi kolaylaştıran, AI destekli kapsamlı bir hukuk portalı uygulamasıdır. Flutter ile geliştirilmiş olan bu uygulama, hızlı, güvenli ve kullanıcı dostu bir deneyim sunar.

## 🚀 Temel Özellikler

### 👤 Kullanıcı (Müvekkil) Paneli
- **Dava Yönetimi:** Aktif ve tamamlanmış davaların takibi.
- **Talep Oluşturma:** Yeni hukuki yardım talepleri oluşturma ve avukatlarla eşleşme.
- **Profil Yönetimi:** Kişisel bilgilerin ve tercihlerin güncellenmesi.
- **Değerlendirme Sistemi:** Tamamlanan davalar için avukatları puanlama ve yorum yapma.

### ⚖️ Avukat Paneli
- **Gelen Talepler:** Müvekkillerden gelen yeni dava taleplerini görüntüleme ve kabul/reddetme.
- **Aktif Davalar:** Üstlenilen davaların süreç yönetimi ve raporlama.
- **Mesajlaşma:** Müvekkillerle doğrudan ve güvenli iletişim.
- **Durum Güncelleme:** Davaların aşamalarını (Ödeme Bekleniyor, Tahsilat Onayı vb.) yönetme.

### 🤖 AI Destekli Hukuk Asistanı
- **Akıllı Sohbet:** Hukuki sorular için yapay zeka destekli rehberlik.
- **Dava Analizi:** Olası dava risklerini ve süreçlerini analiz eden entegre AI motoru.

### 🛠️ Teknik Özellikler
- **Dark Mode Desteği:** Premium ve göz yormayan karanlık tema tasarımı.
- **Güvenli Depolama:** Token tabanlı kimlik doğrulama (`flutter_secure_storage`).
- **Gelişmiş Navigasyon:** `go_router` ile esnek ve yönetilebilir sayfa geçişleri.
- **API Entegrasyonu:** `dio` ile performanslı backend iletişimi ve interceptor desteği.

## 🛠️ Teknoloji Yığını

- **Framework:** [Flutter](https://flutter.dev/) (v3.8.1+)
- **Dil:** Dart
- **State Management:** Provider
- **Networking:** Dio
- **Navigation:** GoRouter
- **Fontlar:** Google Fonts (Inter/Outfit)
- **Veri Saklama:** Flutter Secure Storage & Shared Preferences

## 📋 Gereksinimler

Uygulamayı yerel ortamınızda çalıştırmak için aşağıdaki araçların kurulu olması gerekir:

- **Flutter SDK:** ^3.8.1
- **Dart SDK:** Uygulama ile uyumlu versiyon
- **Android Studio / VS Code:** Önerilen IDE'ler
- **Android SDK:** API Level 24 (Android 7.0) ve üzeri
- **CocoaPods:** (Sadece iOS geliştirme için)
- **Backend:** [HakPortal Backend](https://github.com/serhat-kocyigit/dan-man-avukat) projesinin 3000 portunda çalışıyor olması gerekir.

## ⚙️ Kurulum ve Çalıştırma

1.  **Projeyi Klonlayın:**
    ```bash
    git clone https://github.com/serhat-kocyigit/hakportal-mobile.git
    cd hakportal-mobile
    ```

2.  **Bağımlılıkları Yükleyin:**
    ```bash
    flutter pub get
    ```

3.  **Backend Bağlantısını Yapılandırın:**
    `lib/services/api_service.dart` dosyasına gidin ve `_realDeviceIp` değişkenini backend sunucunuzun (bilgisayarınızın yerel IP'si) adresiyle güncelleyin:
    ```dart
    static const String _realDeviceIp = '10.196.120.110'; // Kendi IP'nizle değiştirin
    ```

4.  **Uygulamayı Başlatın:**
    ```bash
    # Emülatör veya fiziksel cihaz bağlıyken
    flutter run
    ```

## 📂 Proje Yapısı

```text
lib/
├── core/           # Tema, Router ve Genel Ayarlar
├── models/         # Veri Modelleri (User, Case, Message vb.)
├── providers/      # State Management (Auth, vb.)
├── screens/        # UI Sayfaları (Login, Panel, Chat vb.)
├── services/       # API ve Dış Servis Entegrasyonları
└── widgets/        # Tekrar Kullanılabilir UI Bileşenleri
```

## 🤝 Katkıda Bulunma

1. Bu depoyu çatallayın (Fork).
2. Yeni bir özellik dalı oluşturun (`git checkout -b feature/yeniOzellik`).
3. Değişikliklerinizi commit edin (`git commit -m 'Yeni özellik eklendi'`).
4. Dalınıza push yapın (`git push origin feature/yeniOzellik`).
5. Bir Pull Request açın.

---
⭐ Bu projeyi beğendiyseniz yıldız vermeyi unutmayın!
