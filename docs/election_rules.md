# Seçim Kurallari (Uygulama Tarafindan Zorunlu)

## 1) Aday Listesi
- Adaylar sadece `Setup` asamasinda eklenir.
- Aday sırası, giriş sırasıdir (entry order).
- `Locked` asamasindan sonra liste degisemez.

## 2) Oy İşleme Kurali
- Her gecerli pusula okundugunda ilgili adaya bir kez tıklanir.
- Tıklama sonrasi onay adimi zorunludur.
- Onaylanmis işlem yalnizca +1 artış uretir.

## 3) Yasakli Islevler
Asagidaki işlemler sistemde olmayacaktir:
- decrement
- delete
- edit
- undo
- hidden correction path

## 4) Durum Makinesi

```text
SETUP
  | lock
  v
LOCKED
  | start_counting
  v
COUNTING
  | finalize
  v
FINALIZED
```

- Geriye donus yoktur.
- Durum atlama yoktur.

## 5) Sıralama ve Esitlik (Tie-break)
Sıralama anahtarlari:
1. Oy sayisi (descending)
2. Aday giriş sırası (ascending)

Bu kural deterministic olmalidir; manuel yorum gerektirmemelidir.

## 6) Kurallarin Uygulama Katmani
- Kurallar sadece UI seviyesinde birakilmamali.
- Domain/service katmaninda guard kontrolleri bulunmali.
- DB seviyesinde de append-only prensibini destekleyen kisitlar tanimlanmalidir.
