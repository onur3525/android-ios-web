# HizmetCep — Canlı Dağıtım ve Yatay Ölçekleme

Uygulama kodu **tek sunucu varsaymaz**. Aynı imajdan bir ya da daha çok
örnek, yük dengeleyici (load balancer) arkasında çalışır. Örnek sayısını
artırmak/azaltmak KOD DEĞİŞİKLİĞİ gerektirmez; otomatik ölçeklemeyi
altyapı (Kubernetes HPA, ECS, Cloud Run, Fly, Render vb.) yapar.

## Neden durumsuz

| Durum | Nerede tutulur | Örnekler arası |
|---|---|---|
| Kullanıcı/admin oturumları | PostgreSQL (`user_sessions`, `admin_sessions`) | ortak |
| Hız sınırları (giriş, OTP, MFA) | PostgreSQL (`rate_limits`, atomik UPSERT) | ortak — örnek sayısıyla çoğalmaz |
| Gerçek zamanlı olaylar | PostgreSQL LISTEN/NOTIFY (`src/olaylar.js`) | her örnek kendi soketlerine iletir |
| Dosyalar | Nesne depolama (S3/R2/MinIO), imzalı adres | sunucu diskine yazılmaz |
| Entegrasyon ayarları | PostgreSQL; değişiklik olayla bütün örneklerde önbellekten düşer | ortak |
| Arka plan işleri (ilan/talep süresi, hesap silme) | her örnekte zamanlanır, **danışma kilidiyle yalnız biri** çalıştırır | çift iş yok |
| Şema göçleri | açılışta tek işlem + danışma kilidi | aynı anda açılan örnekler güvenli |

## Yük dengeleyici gereksinimleri

- **WebSocket upgrade** desteği (`/socket.io/`). İstemci yalnız WebSocket
  taşıyıcısı kullanır → **yapışkan oturum (sticky session) GEREKMEZ**.
- Boşta zaman aşımı ≥ 60 sn (sunucu keep-alive 65 sn; Socket.IO ping 25 sn).
- Sağlık uçları: `/healthz` (canlılık), `/readyz` (veritabanı erişimi;
  kapanış sırasında 503).
- TLS dengeleyicide sonlanıyorsa: `HC_TRUST_PROXY=true` (gerçek istemci IP'si
  `X-Forwarded-For`'dan; aksi hâlde bu başlık yok sayılır).

## Düzgün kapanış

`SIGTERM` → `/readyz` 503 döner (5 sn) → yeni bağlantı alınmaz → açık
istekler biter → WebSocket'ler kapanır (istemci başka örneğe yeniden
bağlanır) → veritabanı kapanır. En fazla 25 sn.

## PostgreSQL bağlantı bütçesi

Her örnek `HC_DB_POOL` (varsayılan 10) + 1 LISTEN bağlantısı açar.
`örnek_sayısı_azami × (HC_DB_POOL + 1) < max_connections` olmalı.
PgBouncer kullanılacaksa **transaction** modunda havuz bağlantıları için
uygundur; LISTEN bağlantısı ise **session** modu ister (ayrı havuz ya da
doğrudan bağlantı).

## Otomatik ölçekleme önerisi

- Başlangıç: 2 örnek (biri düşerse hizmet sürer), en fazla N.
- Ölçek ölçütü: CPU %60 ya da örnek başına açık WebSocket sayısı.
- Her örnek: 0,5 vCPU / 512 MB yeterli başlangıçtır.

## Zorunlu ortam değişkenleri (BÜTÜN örneklerde AYNI)

`NODE_ENV=production`, `HC_DATABASE_URL`, `HC_MASTER_KEY`, `HC_JWT_SECRET`,
`HC_SMS_PROVIDER`/`HC_EMAIL_PROVIDER` (+ webhook adres/anahtar) ya da admin
panelinden etkin entegrasyon, depolama için `HC_S3_*` ya da admin
entegrasyonu. ⚠ `HC_MASTER_KEY` ve `HC_JWT_SECRET` örnekler arasında farklı
olursa oturumlar ve şifreli sırlar ÇALIŞMAZ.

## Kova (bucket) ayarı

- Genel erişim KAPALI; okuma/yazma yalnız imzalı adresle.
- Yaşam döngüsü kuralı: `u/` önekinde 1 günden eski, ilana bağlanmamış
  nesneler (uygulama `storage_objects.status = DISCARDED/PENDING` tutar)
  için temizlik işi ya da kural.
- CORS: web istemcisinin kaynağından `PUT` + `Content-Type`.
