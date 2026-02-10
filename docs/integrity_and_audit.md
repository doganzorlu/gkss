# Bütünlük ve Denetim Rehberi

## 1) Hedef
Sayım sonrasinda "kayit değişti mi?" sorusuna teknik olarak cevap verebilmek.

## 2) Kanit Katmanlari
1. Canli projeksiyon (anlik görünürluk)
2. Append-only ledger (işlem gecmisi)
3. Hash-zinciri (kayit baglantisi)
4. Build/versiyon kaydi (hangi binary kullanildi)

## 3) Doğrulama Algoritmasi

```text
Adim 1: seq_no degerleri 1..N araliksiz mi?
Adim 2: Her satirin record_hash'i yeniden hesapla.
Adim 3: satir[n].prev_hash == satir[n-1].record_hash mi?
Adim 4: Aday toplamlarini nihai ekran sonucu ile karsilastir.
Adim 5: Kullanilan app version + commit hash + build date kaydini eslestir.
```

## 4) Seçim Öncesi Checklist
- Aday listesi resmi belgeyle satir satir eslesti.
- Projeksiyon test edildi.
- Imlec görünürlugu doğrulandi.
- Örnek tıklama ile onay penceresi çalışma testi yapildi.
- Sayım baslangici oncesi veritabani durumunun temiz olduğu doğrulandi.

## 5) Seçim Sonrası Checklist
- Finalize sonrasinda oy artışina izin verilmedigi test edildi.
- Ledger hash-zinciri doğrulandi.
- Sonuc raporu oluşturuldu.
- Build artefakti ve kaynak surumu birlikte arsivlendi.

## 6) Inceleme ve Itiraz Durumlari
Itiraz halinde asagidaki paket saglanir:
- Nihai sonuc ozeti
- Ledger export'u
- Hash doğrulama ciktilari
- Kullanilan binary surumu
- İşlem tarih/saat kayitlari

## 7) Sinirlar ve Dikkat Notu
Bu sistem hileyi teorik olarak sifira indirmez; amac, değişiklik veya usulsuzluk iddialarini olabildigince erken ve teknik olarak tespit edebilmektir.
