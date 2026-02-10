# Sistem Genel Bakis

## 1) Problem Tanimı
Genel Kurulda oylar fiziksel pusulayla kullanilir. Sayım sureci kamuya acik, görünür ve tartışmaya kapali şekilde yurutilmelidir.

SandıkSayım bu ihtiyac icin:
- canli sayım görünürlugu,
- deterministic kural seti,
- sonradan denetlenebilir kayit
sunar.

## 2) Sistem Sinirlari

```text
[DISARIDA]
- Oy kullanimi (fiziksel)
- Pusula doğrulama
- Hukuki itiraz surecleri

[SISTEM ICINDE]
- Aday listesi tanimi
- Sayımda +1 kayit
- Toplamlarin goruntulenmesi
- Audit amacli kayit butunlugu
```

## 3) Mimari Bakis

```text
+-------------------------+
| Presentation (Single UI)|
+------------+------------+
             |
             v
+-------------------------+
| Election Application    |
| (state transitions)     |
+------------+------------+
             |
             v
+-------------------------+
| SQLite Persistence      |
| + append-only ledger    |
+------------+------------+
             |
             v
+-------------------------+
| Integrity Verifier      |
| (hash-chain checks)     |
+-------------------------+
```

## 4) Neden Tek Ekran?
- Operator ve izleyici ayni veriyi ayni anda gorur.
- Gizli arayuz/sakli komut supheleri azalir.
- İşlem adimlari topluluk onunde doğrulanabilir.

## 5) Basari Kriterleri
1. Kural ihlali olmamasi (ozellikle vote decrement olmamasi)
2. İşlem görünürlugunun korunmasi
3. Sayım sonu kayit butunlugunun doğrulanabilir olmasi
