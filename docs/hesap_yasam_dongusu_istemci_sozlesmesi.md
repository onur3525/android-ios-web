# HESAP YAŞAM DÖNGÜSÜ — İSTEMCİ SÖZLEŞMESİ VE UYUŞMAZLIK RAPORU

**Kapsam:** hesap dondurma / yeniden etkinleştirme / hesap silme.
**Bu belge backend kodu DEĞİLDİR.** Backend kaynağı bu çalışma
ortamında bulunmadığı için sunucu tarafı yazılamadı (bkz. §0).

Belge, Flutter istemcisinin **bugün fiilen ne yaptığını** koddan
çıkarır. Backend'i yazan taraf bunu sözleşme olarak alabilir;
`talimat §27` "Flutter sözleşmesini bozma" derken korunması gereken
şey buradaki davranıştır.

Kaynak dosyalar:
`lib/data/remote/api/account_api.dart`,
`lib/data/remote/api/auth_api.dart`,
`lib/data/remote/api_client.dart`,
`lib/data/remote/api_error_mapper.dart`,
`lib/screens/account_settings_screen.dart`.

---

## 0. NİÇİN BACKEND YAZILMADI

Bu ortamda **backend deposu yok**: `/home/claude` altında yalnız
Flutter projesi (`pl_new`) var; TypeScript kaynağı, `package.json`,
`schema.prisma` bulunmuyor. Ağ da kapalı.

Talimatın kendisi mevcut kod olmadan uygulanamayacak maddeler
içeriyor:

- §2 "mevcut modeli genişlet, **ikinci paralel yapı oluşturma**"
- §24 "mevcut hata kataloğunu kullan, **paralel ikinci hata sistemi
  oluşturma**"
- §21 "event isimlerini **mevcut proje naming standardına** göre seç"
- §29 "**mevcut** kullanıcı hesaplarını bozmayan" migration

Bunlar "mevcut"un ne olduğu görülmeden yapılamaz. Proje kuralı da
zaten **"yeni backend mimarisi kurulmayacak"** diyor. Kaynağı
görmeden yazılacak modül, tam olarak talimatın yasakladığı ikinci
paralel yapı olurdu.

**Gereken:** backend paketinin (NestJS + Prisma kaynağı) yüklenmesi.

⚠ Ayrıca ortamda `npm ci` / `prisma generate` / `jest`
**koşturulamaz** (bağımlılık indirilemiyor). Talimat §26 zorunlu
testler istiyor; testler yazılabilir ama **bu ortamda koşulamaz** —
sonuç Codemagic veya yerel makinede alınmalıdır.

---

## 1. İSTEMCİNİN ÇAĞIRDIĞI UÇLAR

Aşağıdaki yollar Flutter'da **yazılıdır**; backend farklı bir yol
seçerse istemci de değişmek zorundadır (talimat §7 "mevcut API
standardına uygun eşdeğer" diyor — eşdeğer seçilirse burası
güncellenmeli).

| İşlem | Metot | Yol | Gövde |
|---|---|---|---|
| Dondurma | POST | `/profiles/me/freeze` | `{reason?}` |
| Silme talebi | POST | `/profiles/me/deletion-request` | `{reason?}` |
| Talep iptali | DELETE | `/profiles/me/deletion-request` | — |
| Talep listesi | GET | `/profiles/me/account-requests` | — |
| Şifre doğrulama | POST | `/auth/verify-password` | `{password}` |

⚠ **`reason` şu an İSTEMCİDEN GÖNDERİLMİYOR.** Parametre var ama
ekran boş çağırıyor; alan isteğe bağlı kalmalı.

Kimlik: `userId` **gövdede taşınmıyor**, `me` bağlamı token'dan
çözülüyor. Talimat §25 ile uyumlu — backend gövdeden gelen kimliği
zaten görmeyecek.

---

## 2. HATA GÖVDESİ — DEĞİŞMEZ BİÇİM

İstemci şu gövdeyi bekler:

```json
{ "error": { "code": "...", "message": "...", "details": {} },
  "requestId": "...", "timestamp": "...", "path": "..." }
```

Kurallar (`api_error_mapper.dart`):

- **`message` doğrudan kullanıcıya gösterilir.** Türkçe, tek cümle
  ve son kullanıcıya güvenli olmalıdır. Teknik ayrıntı, tablo adı,
  stack, alan adı içeremez.
- **`code` kullanıcıya GÖSTERİLMEZ**, yalnız sınıflandırma içindir.
- `message` boşsa istemci "İşlem tamamlanamadı. Lütfen tekrar
  deneyin." yazar — yani **engelin gerekçesi kaybolur**. Talimat §3
  "generic 500 verme" derken kastedilen kayıp tam olarak budur:
  `ACCOUNT_FREEZE_BLOCKED` dönerken `message` **dolu** olmalıdır.

Hesap ayarları ekranı bu mesajı `_sunucuGerekcesi(e)` ile alıp
kartların üstünde gösterir; sunucu susarsa yerine "Hesap
dondurulamadı. Lütfen tekrar deneyin." yazar.

---

## 3. İSTEMCİ AKIŞI (BOZULMAMASI GEREKEN)

### Dondurma
1. Yerel ön denetim (`_devamEdenIsVar`) — **yalnız erken uyarı**,
   otorite değil.
2. Panel: açıklama → `Vazgeç` / `Hesabı Dondur`.
3. `POST /profiles/me/freeze`.
4. Başarı → "Hesabınız donduruldu" → yerel oturum ve "Beni Hatırla"
   temizlenir → `/home`.

### Silme
1. Panel: açıklama → `Vazgeç` / `Devam Et`.
2. **Şifre doğrulama** → `POST /auth/verify-password`.
3. Son onay → `Vazgeç` / `Hesabımı Sil`.
4. `POST /profiles/me/deletion-request`.
5. Başarı → **"Hesap silme işleminiz alındı."** → oturum temizlenir
   → `/home`.

⚠ 5. adımdaki metin bilinçlidir: backend yalnız **talep**
oluşturduğu için "Hesabınız silindi" **denmez** (talimat §7 ile
birebir aynı). Backend anında silmeye geçerse metin
güncellenmelidir — istemci bunu **kendiliğinden anlayamaz**, bkz.
§4/C.

---

## 4. UYUŞMAZLIKLAR — BACKEND GELİNCE PATLAYACAK NOKTALAR

Talimat §27 "gerçek bir sözleşme uyuşmazlığı varsa sessizce UI'ı
değiştirme, **raporla**" diyor. Rapor budur; **istemcide bu tur
hiçbir değişiklik yapılmadı.**

### A. Dondurulmuş hesap istemcide TANINMIYOR — en ağır eksik

Talimat §5 dondurulmuş hesabın normal uçları kullanamamasını
istiyor. Backend bunu uygulayınca kullanıcı 403 alacak. Ama
`api_client.dart` + `api_error_mapper.dart` **hesap durumu diye bir
kavram tanımıyor**: `FORBIDDEN` → `UnauthorizedError` → ekranlarda
sıradan bir hata satırı.

Sonuç: dondurulmuş kullanıcı uygulamada **dolaşmaya devam eder**,
her ekranda anlamsız bir hata görür, oturumu düşmez.

Gerekli (ayrı iş): `ACCOUNT_FROZEN` / `ACCOUNT_DELETED` kodları
için `api_client` seviyesinde tek merkezden yakalama → oturum
temizleme → `/home`. Bugün `sessionExpired` için olan davranışın
eşdeğeri.

### B. Yeniden etkinleştirme akışı İSTEMCİDE YOK

Talimat §6 tam bir yeniden etkinleştirme mekanizması istiyor.
Flutter'da **hiç karşılığı yok**: ekran yok, uç yok, giriş
ekranında "hesabınız dondurulmuş" dalı yok.

Backend `FROZEN` kullanıcıya giriş sırasında ne dönecekse
(`ACCOUNT_FROZEN` + reactivation ucu), istemci tarafı **ayrı bir
paket** olarak planlanmalıdır. Aksi hâlde dondurma tek yönlü kapı
olur: kullanıcı hesabını dondurur ve **geri dönemez**.

### C. Silme durumu istemciye HİÇ okunmuyor

`myRequests()` yazılı ama hesabın **durumu** (`ACTIVE` / `FROZEN` /
`DELETION_REQUESTED` / `DELETED`) hiçbir yerden okunmuyor;
`restoreSession` profili getirirken de bu alan yok.

Talimat §2 "source of truth backend" diyor. Bunun istemcide
karşılığı olması için **profil yanıtına hesap durumu alanı
eklenmesi** ve istemcinin onu okuması gerekir. Alan eklemek geriye
dönük uyumludur (istemci bilinmeyen alanı yok sayar); **okumak** ayrı
iştir.

### D. Şifre doğrulaması ile silme çağrısı BİRBİRİNE BAĞLI DEĞİL

Talimat §8 kısa ömürlü bir step-up yetkisi istiyor ve istemcinin
`passwordVerified=true` demesine güvenilmemesini söylüyor.

Bugünkü istemci **tam da bunu yapıyor sayılır**: `verify-password`
ayrı bir çağrı, `deletion-request` ayrı; aralarında **hiçbir
belirteç taşınmıyor**. Yani silme ucu doğrudan çağrılabilir.

İki seçenek var, ikisi de **istemci değişikliği gerektirir**:
1. `verify-password` kısa ömürlü bir step-up belirteci döner,
   istemci onu `deletion-request` başlığında/gövdesinde taşır.
2. `deletion-request` şifreyi kendisi ister (tek çağrı).

**Karar backend'indir; istemci tarafını ona göre yazarım.** Şu anki
hâlde §8 karşılanmıyor.

### E. Yeni hata kodları istemcide TANIMLI DEĞİL

`ACCOUNT_ALREADY_FROZEN`, `ACCOUNT_FREEZE_BLOCKED`,
`ACCOUNT_DELETION_BLOCKED`, `ACCOUNT_DELETION_ALREADY_REQUESTED`,
`ACCOUNT_ALREADY_DELETED`, `STEP_UP_REQUIRED` … hiçbiri
`api_error_mapper.dart`'ta yok.

**Kırılma yaratmaz**: bilinmeyen kod `ValidationError`'a düşer ve
`message` kullanıcıya gösterilir — yani gerekçe yine görünür. Ama
istemci bu durumları **ayırt edemez** (ör. `STEP_UP_REQUIRED`
gelince doğrulama panelini yeniden açmak). Kodlar
kesinleştiğinde eşleme eklenmelidir.

### F. `_cancelDeletion` ekranda ULAŞILAMIYOR

İptal işlevi yazılı ve mock koruması var, ama düğmesi yalnız
`/profiles/me/account-requests` **dolu** dönerse çizilir. Backend o
ucu doldurmadığı sürece kullanıcı talebini uygulamadan **iptal
edemez** (talimat §23 iptali destekliyor).

---

## 5. YEREL ÖN DENETİMİN SINIRI

`account_settings_screen._devamEdenIsVar()` şunları sayar:

- kendi ilanları: `open` · `providerSelected` · `inProgress`
- verdiği teklifler: `active` · `selected`

`completed` · `cancelled` · `expired` · teklifte `cancelled` **engel
değildir** (talimat §3 ile aynı).

⚠ Bu denetim **yalnız cihazdaki veriye** bakar ve **finansal
süreçleri hiç görmez** (`PENDING_FINANCIAL_OPERATION` karşılığı
yok). Talimat §3'ün istediği gibi **otorite backend'dir**; yerel
denetim kullanıcıyı boşuna panel açmaktan kurtarmak içindir.
Backend engel koyduğunda gerekçesi §2'deki `message` ile
gösterilir.

---

## 6. BACKEND'İN İSTEMCİYİ DEĞİŞTİRMEDEN YAPABİLECEKLERİ

Aşağıdakiler istemci dokunulmadan çalışır:

- Hesap durum modeli, state machine, transaction, idempotency,
  concurrency, outbox, audit, silme job'ı (§2, §4, §19–§22)
- Dondurma/silme engelleri — **`message` dolu olmak kaydıyla** (§3, §9)
- Token/oturum iptali (§4, §15)
- Retention sınıflandırması, anonimleştirme (§11, §13, §14)
- Push token ilişkilerinin kaldırılması (§16)
- Çift rollü hesabın tamamının kapsanması (§10) — istemci zaten rol
  bazlı bir silme sunmuyor

İstemci değişikliği **gerektirenler**: §5 (A), §6 (B), §8 (D),
kısmen §2 (C) ve §24 (E).
