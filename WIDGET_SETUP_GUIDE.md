# 📱 iOS Widget Kurulum Rehberi - Sürpriz Kart App

## Gereksinimler
- ✅ Mac (macOS 14+)
- ✅ Xcode 15+
- ✅ Apple Developer Account
- ✅ CocoaPods (`sudo gem install cocoapods`)

---

## ADIM 1: Projeyi İndir ve Native iOS Projesini Oluştur

```bash
# Projeyi GitHub'dan klonla veya indir
cd /path/to/project/frontend

# Native iOS projesini oluştur (Expo prebuild)
npx expo prebuild --platform ios

# CocoaPods bağımlılıklarını kur
cd ios
pod install
cd ..
```

Bu komut `ios/` klasörünü oluşturacak.

---

## ADIM 2: Xcode'da Projeyi Aç

```bash
open ios/frontend.xcworkspace
```

⚠️ `.xcodeproj` DEĞİL, `.xcworkspace` dosyasını açın!

---

## ADIM 3: Bundle Identifier Ayarla

1. Xcode'da sol panelde **frontend** projesine tıkla
2. **Signing & Capabilities** sekmesine git
3. **Bundle Identifier** ayarla: `com.yourcompany.surprisecard`
4. **Team** seçimini yap (Apple Developer hesabın)
5. **Automatically manage signing** seçili olsun

---

## ADIM 4: App Group Ekle

App Group, ana uygulama ile widget arasında veri paylaşımını sağlar.

1. **frontend** target seçili iken → **Signing & Capabilities**
2. **+ Capability** butonuna tıkla
3. **App Groups** ekle
4. **+** butonu ile yeni grup ekle: `group.com.surprisecard.shared`

---

## ADIM 5: Widget Extension Ekle

1. Xcode menüsünden: **File → New → Target**
2. **Widget Extension** seç → **Next**
3. Ayarlar:
   - **Product Name**: `SurpriseCardWidget`
   - **Team**: (Aynı developer hesabın)
   - **Bundle Identifier**: `com.yourcompany.surprisecard.SurpriseCardWidget`
   - **Include Live Activity**: ❌ (işareti kaldır)
   - **Include Configuration App Intent**: ❌ (işareti kaldır)
4. **Finish** → "Activate this scheme?" sorusuna **Activate** de

---

## ADIM 6: Widget Target'a App Group Ekle

1. Sol panelde yeni oluşan **SurpriseCardWidget** target'ı seç
2. **Signing & Capabilities** sekmesine git
3. **+ Capability** → **App Groups** ekle
4. ANA UYGULAMAYLA AYNI grubu seç: `group.com.surprisecard.shared`

---

## ADIM 7: Widget Swift Kodunu Kopyala

Xcode'un otomatik oluşturduğu `SurpriseCardWidget.swift` dosyasını **tamamen sil** ve projedeki `ios-widget/SurpriseCardWidget/SurpriseCardWidget.swift` dosyasının içeriğini yapıştır.

**Dosya konumu**: Projede `ios-widget/SurpriseCardWidget/SurpriseCardWidget.swift`

### Yapılacak:
1. Xcode'da **SurpriseCardWidget** klasörüne git
2. Mevcut `.swift` dosyalarını sil
3. Yeni bir Swift dosyası oluştur: `SurpriseCardWidget.swift`
4. `ios-widget/SurpriseCardWidget/SurpriseCardWidget.swift` içeriğini yapıştır

---

## ADIM 8: Native Bridge Dosyalarını Ekle

Ana uygulama (frontend) target'ına native bridge dosyalarını ekle:

### 8a. WidgetBridge.swift
1. `ios/frontend/` klasörüne sağ tıkla → **New File → Swift File**
2. İsim: `WidgetBridge.swift`
3. `ios-widget/NativeModules/WidgetBridge.swift` içeriğini yapıştır
4. Xcode **"Create Bridging Header?"** diye sorarsa → **Create Bridging Header** de

### 8b. WidgetBridge.m
1. `ios/frontend/` klasörüne sağ tıkla → **New File → Objective-C File**
2. İsim: `WidgetBridge.m`
3. `ios-widget/NativeModules/WidgetBridge.m` içeriğini yapıştır

### 8c. Bridging Header
Eğer otomatik oluşturulmadıysa, `ios/frontend/frontend-Bridging-Header.h` dosyasını oluştur:

```objc
//
// frontend-Bridging-Header.h
//

#import <React/RCTBridgeModule.h>
#import <React/RCTViewManager.h>
#import <React/RCTEventEmitter.h>
```

---

## ADIM 9: App Group ID'yi Doğrula

Her iki dosyada da App Group ID'nin aynı olduğundan emin ol:

**Widget'ta** (`SurpriseCardWidget.swift`, satır 30):
```swift
static let appGroupId = "group.com.surprisecard.shared"
```

**Native Bridge'de** (`WidgetBridge.swift`, satır 9):
```swift
static let appGroupId = "group.com.surprisecard.shared"
```

⚠️ Bu ID'ler Xcode'daki App Group capability'deki ID ile **birebir aynı** olmalı!

---

## ADIM 10: Build ve Test

### Simülatörde Test:
1. Xcode'da üstten **frontend** scheme seç
2. Simülatör seç (iPhone 15 Pro gibi)
3. **⌘R** ile çalıştır
4. Uygulama açıldıktan sonra:
   - Kayıt ol / Giriş yap
   - Eşleşme yap
   - Kart oluştur ve gönder
5. Ana ekrana dön
6. Ana ekrana uzun bas → Widget ekle → **Sürpriz Kart** widget'ını seç

### Gerçek Cihazda Test:
1. iPhone'unu USB ile bağla
2. Xcode'da cihazını seç
3. **⌘R** ile çalıştır
4. Widget'ı ana ekrana ekle

---

## ADIM 11 (Opsiyonel): Backend URL'i Güncelle

Eğer backend'i kendi sunucuna deploy edeceksen, `frontend/.env` dosyasındaki URL'i güncelle:

```env
EXPO_PUBLIC_BACKEND_URL=https://your-server.com
```

---

## 🔧 Sorun Giderme

### Widget boş görünüyor?
- App Group ID'lerin eşleştiğinden emin ol
- Uygulamayı aç, bir kart gönder, sonra widget'ı kontrol et

### "App Group erişilemedi" hatası?
- Her iki target'ta (frontend + SurpriseCardWidget) App Groups capability'nin aktif olduğunu kontrol et

### Widget güncellenmiyor?
- Widget'a uzun bas → "Edit Widget" → widget'ı sil ve tekrar ekle
- Cihazı yeniden başlat

### Bridging Header hatası?
- Build Settings → Swift Compiler → Objective-C Bridging Header yolunun doğru olduğunu kontrol et
- Genellikle: `frontend/frontend-Bridging-Header.h`

### "No such module 'WidgetKit'" hatası?
- Widget extension target'ında Deployment Target'ın iOS 14+ olduğundan emin ol

---

## 📂 Dosya Yapısı (Son Hali)

```
ios/
├── frontend/
│   ├── AppDelegate.swift
│   ├── WidgetBridge.swift          ← Native bridge (ADIM 8a)
│   ├── WidgetBridge.m              ← ObjC bridge (ADIM 8b)
│   ├── frontend-Bridging-Header.h  ← Bridging header (ADIM 8c)
│   └── ...
├── frontend.xcworkspace
├── Podfile
└── SurpriseCardWidget/
    ├── SurpriseCardWidget.swift     ← Widget kodu (ADIM 7)
    └── Info.plist
```

---

## 🔄 Veri Akışı

```
Kullanıcı A kart gönderir
    ↓
Backend'e kaydedilir (MongoDB)
    ↓
Kullanıcı B uygulamayı açar
    ↓
/api/cards/latest ile son kartı çeker
    ↓
saveCardToWidget() → App Group UserDefaults'a yazar
    ↓
WidgetCenter.shared.reloadAllTimelines()
    ↓
Widget güncellenir → Ana ekranda kart görünür! 🎉
```
