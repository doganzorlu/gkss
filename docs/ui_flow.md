# UI Akisi ve Operasyon Rehberi

## 1) Tek Ekran Ilkesi
Operatorun kullandigi ekran, projeksiyonla katilimcilara aynen yansitilir.

Ekranda her zaman görünür alanlar:
- Seçim durumu (`Setup/Locked/Counting/Finalized`)
- Numarali aday listesi (sabit sıra)
- Aday bazli oy sayisi
- Toplam oy
- Son işlem zamani

## 2) İşlem Akisi

```text
[Operator aday satirina tıklar]
            |
            v
    [Onay dialogu acilir]
       | Evet      | Hayir
       v           v
   [+1 kayit]   [İptal]
       |
       v
[Ekranda anlik güncelleme]
```

## 3) Operator Proseduru
1. Setup'ta adaylari resmi sıraya göre gir.
2. Gozlemciyle aday sırasıni birlikte doğrula.
3. Lock işlemiyle listeyi sabitle.
4. Count modunda her pusula icin ilgili adaya git, onayla, +1 kaydi isle.
5. Sayım bitince Finalize et.

## 4) Manuel Hata Senaryolari
1. Yanlis adaya tıklama:
- Beklenen: Onay penceresinden iptal ile kayit olusmamali.

2. Cift tıklama riski:
- Beklenen: Her artış ayri onay gerektirmeli.

3. Durum hatasi:
- Beklenen: Counting disi durumda oy artışi yapilamamalidir.

4. Finalize sonrasi tıklama:
- Beklenen: Hiçbir adayın oyu artmamali.

5. Görünürluk:
- Beklenen: Projeksiyondan aday satiri, oy ve zaman bilgisi okunabilmeli.

## 5) Projeksiyon Kontrol Listesi
- Imlec görünür ve yeterince belirgin mi?
- Font boyutu salonun arka tarafindan okunuyor mu?
- Renk kontrasti dusuk isikta yeterli mi?
- Son işlem zamanı canlı değişimi yansıtıyor mu?
