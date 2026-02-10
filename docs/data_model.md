# Veri Modeli

## 1) Tasarim Hedefi
Veri modeli; sadelik, deterministik davranis ve denetlenebilirlik icin optimize edilir.

## 2) Kavramsal Model

```text
Election (1) ---- (N) Candidate
Election (1) ---- (N) VoteLedgerRecord
Candidate (1) --- (N) VoteLedgerRecord
```

## 3) Tablo Onerileri

### `election`
- `id` INTEGER PRIMARY KEY
- `title` TEXT NOT NULL
- `status` TEXT NOT NULL CHECK(status IN ('setup','locked','counting','finalized'))
- `created_at` TEXT NOT NULL
- `locked_at` TEXT
- `finalized_at` TEXT

### `candidate`
- `id` INTEGER PRIMARY KEY
- `election_id` INTEGER NOT NULL
- `entry_order` INTEGER NOT NULL
- `display_name` TEXT NOT NULL
- `created_at` TEXT NOT NULL

Kisitlar:
- `(election_id, entry_order)` unique olmalidir.
- `entry_order` değiştirilmemelidir.

### `vote_ledger`
- `seq_no` INTEGER PRIMARY KEY
- `election_id` INTEGER NOT NULL
- `candidate_id` INTEGER NOT NULL
- `created_at` TEXT NOT NULL
- `prev_hash` TEXT NOT NULL
- `record_hash` TEXT NOT NULL

## 4) Hash Zinciri Mantigi
Onerilen hesap girişi:

```text
record_hash = HASH(seq_no|election_id|candidate_id|created_at|prev_hash)
```

- Ilk kayit icin `prev_hash` sabit bir genesis degeri olabilir.
- Her kayit bir onceki kayda kriptografik olarak baglanir.

## 5) Raporlamada Kullanilan Turetilmis Alanlar
- Toplam oy = `COUNT(vote_ledger.seq_no)`
- Aday oyu = `GROUP BY candidate_id`
- Sıralama = `votes DESC`, `entry_order ASC`

## 6) Append-Only Prensibi
- `vote_ledger` satirlari UPDATE/DELETE edilmez.
- Düzeltme ihtiyacı olursa yeni bir seçim süreci açılarak yönetilir.
