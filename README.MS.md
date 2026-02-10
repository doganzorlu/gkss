# MOSB Genel Kurul Sayım Sistemi - Fiziksel Sandık Oy Sayım Uygulamasi (Flutter Desktop)

Bu dokuman, insan gelistiriciler, sandık operasyon ekibi, gozlemciler ve denetcilere yoneliktir.

## 1) Projenin Amaci
MOSB Genel Kurul Sayım Sistemi, **fiziksel pusulalarla yapılan bir oylamanın sayımını** dijital olarak görünür ve izlenebilir şekilde kaydetmek için tasarlanmıştır.

- Oylar kagit pusula ile kullanilir.
- Pusulalar fiziken acilir ve yüksek sesle okunur.
- Teknik operator, okunan adaya tıklayarak oy sayisini +1 artirir.
- Ekran canli olarak salona/projeksiyona yansitilir.

Bu sistem bir **elektronik oylama** platformu degildir. Bu sistem bir **elektronik sayım kayit** aracidir.

## 2) Sistem Ne Yapar / Ne Yapmaz

### Yapar
- Adayları sayım oncesi sisteme alir.
- Aday sırasıni giriş sırasına göre sabitler.
- Oy artışini yalnizca +1 olarak uygular.
- Her oy artışini onay adimiyla görünür şekilde isler.
- Oy gecmisini yerel SQLite veritabaninda append-only olarak kaydeder.
- Kayitlarin butunlugunu hash-zinciri ile doğrulamaya imkan verir.

### Yapmaz
- Online oy kullanimi yapmaz.
- Uzaktan bağlantı/yönetim sağlamaz.
- Kullanici rol, yetki, admin paneli icermez.
- Oy dusurme, silme, duzeltme, geri alma yapmaz.
- Sonuc sıralamasinda akilli/AI temelli karar vermez.

## 3) Yuksek Seviye Isleyis

```text
Fiziksel Pusula -> Sesli Okuma -> Operator Tıklamasi -> Onay -> +1 Kayit
                                              |
                                              v
                                   Projeksiyonda Anlık Görünüm
```

Durumlar:

```text
[SETUP] -> [LOCKED] -> [COUNTING] -> [FINALIZED]
   |          |            |             |
Aday Giriş  Liste Sabit  Sadece +1     Salt okunur sonuç
```

## 4) Etkilesim Modeli
- Tek ekran vardir; operatorun gordugu ekran ayni anda salona yansitilir.
- Her aday satiri numarali ve sabit sıradadir.
- Her oy artışi oncesinde acik onay penceresi gosterilir.
- Onaydan sonra sayac aninda güncellenir.
- Son işlem zamani görünür tutulur.

## 5) Gelistirme Ortami Kurulumu

### Gereksinimler
- Flutter SDK (desktop destekli)
- Dart SDK (Flutter ile gelir)
- Windows: Visual Studio 2022 + Desktop C++ workload
- macOS: Xcode + command line tools

### Hizli Kontrol
```bash
flutter --version
flutter doctor
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
```

### Bagimlilik Kurulumu
```bash
flutter pub get
```

## 6) Uygulamayi Calistirma

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos
```

Not: Bu asamada uygulama yalnizca temel iskelet/yer tutucu ekrani icerir.

## 7) Manuel Test Yaklaşımı (Prosedürel Doğruluk)
Bu projede otomatik testten once prosedur doğrulugu esastir.

### Temel Senaryolar
1. Aday girişi sadece Setup durumunda yapilabiliyor mu?
2. Lock sonrasi aday sırasınin değişmedigi goruluyor mu?
3. Oy artışi sadece +1 mi?
4. Onay penceresi iptal edilince kayit olusmuyor mu?
5. Finalize sonrasi hicbir adayda artir butonu çalışmiyor mu?
6. Projeksiyon ekranında imleç ve anlık değişim net seçiliyor mu?

Detaylar icin: `docs/ui_flow.md`, `docs/integrity_and_audit.md`

## 8) Build ve Release

### Release Build Komutlari
```bash
flutter build windows --release
flutter build macos --release
```

### Cikti Konumlari
- Windows: `build/windows/x64/runner/Release/`
- macOS: `build/macos/Build/Products/Release/`

### Paketleme Yaklasimi
- Her seçim icin sabit bir surum etiketi kullanin: `vYYYY.MM.DD-<kurul_kodu>`
- Build artefakti + kaynak kod commit hash birlikte arsivlensin.
- Build yapan makine, Flutter surumu ve tarih kayit altina alinsin.

## 9) Hukuki ve Güven Varsayımlari
- Bu yazilim fiziksel seçim surecinin yerine gecmez; sayım ekrani ve kayit altyapisidir.
- Nihai güven: fiziksel tutanak + canli görünürluk + bagimsiz gozlem + teknik log birlikte degerlendirilmelidir.
- Hash-zinciri, manipule etmeyi tamamen imkansiz kilmaz; ancak sonradan değişiklik iddialarini teknik olarak incelemeyi saglar.

## 10) Acik Non-Goal Listesi
- Online oylama
- QR tabanli oy kullanim senaryolari
- Kimlik doğrulama/yetkilendirme sistemi
- Remote access / remote administration
- Sonuc uzerinde manipulatif otomasyon
- AI/ML tabanli akilli sıralama veya karar mantigi

## 11) Depo Yapisi

```text
/root
  /lib
  /docs
    system_overview.md
    election_rules.md
    ui_flow.md
    data_model.md
    integrity_and_audit.md
  README.MS.md
  README.AI.md
```
