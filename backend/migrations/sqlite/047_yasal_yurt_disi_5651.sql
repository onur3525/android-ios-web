-- 047 — YURT DIŞI SUNUCU VE 5651 TRAFİK KAYDI BİLGİLENDİRMESİ (29 Eki, TASLAK)
--
-- Gizlilik Politikası ve Aydınlatma Metni'nin yeni sürümleri:
--   · altyapının yurt dışı sunucularda (Render/Almanya, Cloudflare/Avrupa,
--     Google Firebase/ABD) çalıştığı ve verilerin orada işlendiği açıkça;
--   · 5651 trafik kayıtlarının (IP, kaynak port, işlem, zaman) 365 gün
--     saklanması ve hesap silinse de bu sürenin işlemesi; yasal kimlik arşivi;
--   · "Şikâyet Et" mekanizması ve şikâyet kayıtlarının saklama süresi;
--   · telefon doğrulama SMS'lerinin ve kullanıcı kimliklerinin Google
--     Firebase (yurt dışı) sunucularında işlendiği açıkça;
--   · kayıttaki ikinci kutuyla alınan "yurt dışı sunucularda işleme" açık
--     rızası ve geri alınması.
--   · 29 Eki (işletmeci talimatı): üç metinde iletişim e-postası
--     onur@hizmetcep.com, adres İzmir/Türkiye.
-- ⚠ Kullanım Sözleşmesi de yeni sürüm alır (iletişim satırı ve madde 14'te
-- açık rızanın ayrı kutuyla alındığı cümlesi); onay isteyen belge olduğu için mevcut kullanıcılardan bir
-- sonraki girişte yeniden onay istenir.
--
-- ⚠ GÜVENLİK KİLİDİ (040 ile aynı): yalnız yayımdaki sürüm 040'ın yayımladığı
-- metnin AYNISIYSA (sha256) değiştirilir; panelden başka sürüm yayımlanmışsa
-- o belgeye DOKUNULMAZ. Eski sürüm silinmez, ARCHIVED olur.

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'privacy' AND status = 'PUBLISHED' AND sha256 = 'ece793c8b48d12c56203714aa397360d4f4d1e0229a9a1d677ccafd245594794'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-29102026f001');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-29102026f001', 'privacy',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'privacy'),
       '## 1. Veri sorumlusu

HizmetCep''in işletmecisi ve kişisel veriler bakımından veri sorumlusu Onur Bütün''dür.
Adres: İzmir/Türkiye
E-posta: onur@hizmetcep.com

Bu politika, HizmetCep mobil uygulaması ve web sitesi üzerinden işlenen kişisel verileri açıklar. Kısa bilgilendirme Aydınlatma Metni''nde, web sitesindeki çerezler Çerez Politikası''nda yer alır.

## 2. İşlenen kişisel veriler

- Kimlik ve iletişim: ad-soyad, telefon numarası, e-posta adresi.
- Hesap: şifre (yalnızca geri döndürülemez özeti saklanır), kullanıcı rolleri (hizmet alan / hizmet veren), bildirim tercihleri, hesap durumu.
- Adres ve hizmet bölgesi: il, ilçe ve mahalle; hizmet verenler için hizmet kategorileri ve hizmet verilen ilçeler.
- Hizmet içerikleri: ilanlar (hizmet adı, konum açıklaması, açıklama, fotoğraflar, iş zamanı, iletişim tercihi), teklifler (tutar ve not), teklif talepleri, uygulama içi mesajlar ve mesajlardaki fotoğraflar, yorumlar ve puanlar, profil fotoğrafı.
- Şikâyetler: bir ilan, kullanıcı profili veya yorum hakkında yaptığınız şikâyetin nedeni, isteğe bağlı açıklaması ve tarihi; hakkınızda yapılan şikâyetlerin konusu ve sonucu.
- Destek: uygulamadan veya e-postayla iletilen destek talepleri ve yazışmalar, uygulama geri bildirimleri.
- Hukuki işlem: Kullanım Sözleşmesi''nin kabul edilen sürümü ile Gizlilik Politikası ve Aydınlatma Metni''nin gösterildiğine ve yurt dışındaki sunucularda işlemeye açık rıza verildiğine ilişkin kayıt (tarih-saat, sürüm, SHA-256 özeti, platform); hesap dondurma ve silme talepleri; hesap durumu değişiklikleri.
- İşlem güvenliği: oturum kayıtları (IP adresi, tarayıcı/cihaz bilgisi), doğrulama kodu kayıtları, bildirim (push) jetonu, yönetici işlem kayıtları.
- Trafik kayıtları: giriş, kayıt, oturum yenileme, ilan, teklif, mesaj, yorum ve şikâyet gönderme gibi işlemlerde IP adresi, kaynak port numarası, işlemin türü ile tarih ve saati.

HizmetCep GPS veya arka planda konum takibi yapmaz. Yüklenen fotoğraflardaki konum ve cihaz bilgisi (EXIF/GPS meta verisi) yüklemeden önce uygulama tarafından silinir. Özel nitelikli kişisel veri (sağlık, din, biyometrik veri vb.) istenmez; kullanıcıların bu tür bilgileri ilan, mesaj veya yorumlarda paylaşmaması gerekir.

## 3. İşleme amaçları ve hukuki sebepler

6698 sayılı Kişisel Verilerin Korunması Kanunu''nun ("KVKK") 5. maddesinin 2. fıkrası kapsamında:

- Üyeliğin oluşturulması ve yönetilmesi, telefon ve e-posta doğrulaması; ilan, teklif, teklif talebi, mesajlaşma, yorum ve profil özelliklerinin sunulması; seçiminize göre iletişim bilginizin karşı tarafla paylaşılması; işlemlerinizle ilgili bildirim gönderilmesi — sözleşmenin kurulması ve ifası (c bendi).
- Destek taleplerinin ve şikâyetlerin değerlendirilmesi, hukuka aykırı veya Kullanım Sözleşmesi''ne aykırı içeriklerin kaldırılması — sözleşmenin ifası (c bendi), hukuki yükümlülük (ç bendi) ve meşru menfaat (f bendi).
- Hesap güvenliğinin sağlanması, kötüye kullanımın önlenmesi, oturum ve güvenlik kayıtlarının tutulması, teknik sorunların giderilmesi — meşru menfaat (f bendi).
- 5651 sayılı İnternet Ortamında Yapılan Yayınların Düzenlenmesi ve Bu Yayınlar Yoluyla İşlenen Suçlarla Mücadele Edilmesi Hakkında Kanun ve ilgili mevzuat kapsamında trafik kayıtlarının saklanması ve yetkili mercilerin talebi hâlinde sunulması — hukuki yükümlülük (ç bendi).
- Sözleşme onay kayıtlarının, yönetici işlem kayıtlarının ve hesap silme taleplerinin tutulması; yetkili mercilerin taleplerinin karşılanması — hukuki yükümlülük (ç bendi) ve bir hakkın tesisi, kullanılması veya korunması (e bendi).

Kullanım Sözleşmesi''nin kabulü açık rıza yerine geçmez. Kişisel verilerinizin yurt dışındaki sunucularda işlenmesi için kayıt sırasında, sözleşme onayından ayrı bir onay kutusuyla açık rızanız alınır (bkz. madde 5).

## 4. Kişisel verilerin aktarıldığı taraflar

- Diğer kullanıcılar: hizmet akışı için gerekli profil, ilan, teklif ve talep bilgileri ile seçiminize göre paylaşılan iletişim bilgisi (bkz. madde 7).
- Hizmet sağlayıcılar (veri işleyenler):
  - Render Services, Inc. — uygulama sunucusu ve veritabanı barındırma.
  - Cloudflare, Inc. — uygulama ve web trafiğinin iletilmesi ve saldırılara karşı korunması (bu sırada IP adresi ve bağlantı bilgileri işlenir) ile fotoğrafların saklanması (Cloudflare R2).
  - Google LLC — Firebase Authentication (telefon doğrulama kodu SMS''lerinin üretilmesi ve gönderilmesi, telefon ve e-posta doğrulaması, hesap girişi ve şifre sıfırlama) ve Firebase Cloud Messaging (bildirim gönderimi).
  - Apple Inc. — iOS cihazlara bildirim iletimi (Apple Push Notification service).
  - Resend — e-posta gönderimi ve destek adresine gelen e-postaların alınması.
  - GitHub, Inc. — web sitesinin barındırılması (ziyaretçinin IP adresi ve tarayıcı bilgisi).
- Yetkili kamu kurum ve kuruluşları ile adli merciler: geçerli bir hukuki talep veya kanuni yükümlülük olduğunda.
- Gerektiği ölçüde hukuk ve mali müşavirlik gibi profesyonel danışmanlar.

## 5. Yurt dışındaki sunucularda işleme ve yurt dışına aktarım

HizmetCep''in altyapısı yurt dışında bulunan sunucular üzerinde çalışır. Bu nedenle kişisel verileriniz, hizmetin sunulması amacıyla aşağıdaki yurt dışı sunucularda saklanır ve işlenir:

- Render — Almanya (Frankfurt): uygulama sunucusu ve veritabanı. Hesap, profil, adres, ilan, teklif, talep, mesaj, yorum, şikâyet, onay kayıtları ile oturum ve trafik kayıtları bu sunucularda tutulur.
- Cloudflare — Avrupa: fotoğrafların saklanması (Cloudflare R2). Uygulamanın ve web sitesinin ağ trafiği de Cloudflare''in küresel ağı üzerinden iletilir.
- Google Firebase — Amerika Birleşik Devletleri ve Google''ın küresel veri merkezleri: telefon doğrulama kodu SMS''leri Firebase tarafından üretilir ve gönderilir. Firebase kullanıcı kimliği (UID), telefon numarası, e-posta adresi, giriş bilgileri (şifre Firebase''de geri döndürülemez biçimde saklanır), doğrulama sırasında cihaz ve IP bilgisi ile bildirim jetonları Google''ın sunucularında işlenir.
- Apple — Amerika Birleşik Devletleri ve küresel veri merkezleri: iOS bildirim iletimi.
- Resend — Japonya (Tokyo) üzerinden gönderim; şirket Amerika Birleşik Devletleri''ndedir.
- GitHub — Amerika Birleşik Devletleri.

Bu aktarımlar KVKK''nın 9. maddesi ve Kişisel Verilerin Yurt Dışına Aktarılmasına İlişkin Usul ve Esaslar Hakkında Yönetmelik kapsamında, Kişisel Verileri Koruma Kurulu''nun ilan ettiği standart sözleşmelere dayanılarak yapılır; standart sözleşmeler imzalandıktan sonra 5 iş günü içinde Kurul''a bildirilir. Ayrıca kayıt sırasında, kişisel verilerinizin hizmet sunumu amacıyla yurt dışındaki sunucularda işlenmesine açık rızanız alınır; bu rızanın verildiği tarih-saat ve metin sürümü kayıt altına alınır. Açık rızanızı onur@hizmetcep.com adresine başvurarak her zaman geri alabilirsiniz; altyapı yurt dışında olduğundan rızanın geri alınması hâlinde hizmet sunulamayabilir, bu durumda hesabınızı silebilirsiniz. Geri alma, o tarihe kadar yapılan işlemlerin hukuka uygunluğunu etkilemez. Aktarılan veriler, ilgili sağlayıcının hizmeti için gerekli olanlarla sınırlıdır. Bağlantılar şifrelidir (HTTPS) ve sağlayıcılar verileri yalnızca HizmetCep adına ve talimatı doğrultusunda işler.

## 6. Şikâyet ve içerik kaldırma

Bir ilanı, kullanıcı profilini veya yorumu uygulamadaki "Şikâyet Et" seçeneğiyle bildirebilirsiniz. Şikâyetler yöneticiler tarafından incelenir; hukuka veya Kullanım Sözleşmesi''ne aykırı bulunan içerik yayından kaldırılır ("Yönetim kaldırdı") ya da ilgili hesap hakkında tedbir uygulanır. Kaldırılan içerik, olası hukuki talepler için madde 9''daki süreler boyunca kayıtlarda tutulur. Şikâyet eden kişinin kimliği şikâyet edilen kişiye bildirilmez.

## 7. İletişim bilgilerinin paylaşılması

Telefon numarası herkese açık profil bilgisi değildir.

- İlan akışında: Hizmet alan ile teklif veren hizmet veren arasında iletişim açıldığında, hizmet verenin telefonu hizmet alana gösterilir. Hizmet alanın telefonu yalnızca ilanda "Telefonumu göster" seçildiyse hizmet verene gösterilir; "Sadece uygulama içi mesaj" seçildiyse hiçbir ekranda paylaşılmaz.
- Teklif talebi akışında: Hizmet veren teklif verdikten sonra, talep süresi dolmadığı sürece iletişim açıktır. Hizmet alanın telefonu yalnızca "Telefonumu göster" seçildiyse paylaşılır.
- E-posta adresi diğer kullanıcılarla paylaşılmaz.

Kullanıcılar başkalarının iletişim bilgilerini izinsiz yayımlayamaz veya başka amaçla kullanamaz.

## 8. Yönetici erişimi ve güvenlik

Yöneticiler verilere yalnızca görevleri için gereken yetkiyle erişir. Uygulama içi mesajları görüntülemek için yöneticinin bir gerekçe girmesi zorunludur ve her erişim kayıt altına alınır. Yönetici hesapları iki aşamalı doğrulamayla korunur. Trafik kayıtları değiştirilemez biçimde tutulur.

Şifreler geri döndürülemez biçimde saklanır, bağlantılar şifrelidir (HTTPS). Hiçbir sistem için mutlak güvenlik garantisi verilmez.

## 9. Saklama, hesap dondurma ve hesap silme

**Hesap dondurma:** Hesabınızı uygulamadan dondurabilirsiniz. Dondurulan hesap aramada görünmez, bildirim almaz; veriler silinmez. Yeniden giriş yaptığınızda hesap etkinleşir.

**Hesap silme:** Uygulamadan, şifrenizi girerek silme talebi oluşturursunuz. Talep 30 gün sonra uygulanır ve bu süre içinde iptal edilebilir. Silme uygulandığında:

- ad, telefon, e-posta, şifre ve profil fotoğrafları hesaptan kaldırılır;
- adres, hizmet profili, bildirim jetonları, oturum kayıtları, bildirimler ve doğrulama kodu kayıtları silinir;
- yazdığınız mesaj, ilan açıklaması, teklif notu, talep, yorum ve şikâyet açıklaması metinleri kaldırılır;
- yüklediğiniz dosyalar depolamadan silinir;
- kimlik doğrulama kaydınız Firebase''den silinir.

**Kanuni saklama istisnası:** 5651 sayılı Kanun kapsamındaki trafik kayıtları hesap silinse de 1 yıllık süre dolana kadar saklanır. Bu kayıtların yetkili mercilerin talebinde kişiyle eşleştirilebilmesi için hesap silinirken ad, telefon ve e-posta bilgisinin bir kopyası ayrı bir yasal arşivde 1 yıl (365 gün) tutulur. Bu arşiv yalnızca yetkili mercilerin hukuken geçerli talebi hâlinde kullanılır, başka hiçbir amaçla işlenmez ve süre sonunda silinir.

Karşı tarafın kendi yazdığı mesajlar onun verisi olduğu için silinmez. Yorumların yıldız puanı, kişiyle ilişkilendirilemeyecek şekilde kalır.

**Saklama süreleri:**

- Doğrulama kodları: 1 gün.
- Oturum kayıtları (IP adresi, cihaz bilgisi): oturumun süresi dolduktan sonra 30 gün.
- Trafik kayıtları (IP adresi, kaynak port, işlem türü, tarih-saat): 5651 sayılı Kanun ve ilgili mevzuat uyarınca 1 yıl (365 gün); hesap silinse de bu süre boyunca saklanır.
- Yasal kimlik arşivi (silinen hesabın ad, telefon ve e-postası): hesabın silinmesinden itibaren 1 yıl (365 gün).
- Sunucu hata kayıtları (kişisel veri içermez): 30 gün.
- Hesap, profil ve hizmet içerikleri (ilan, teklif, talep, mesaj, yorum, fotoğraf): hesap açık olduğu sürece; hesap silindiğinde yukarıdaki şekilde silinir. Yönetim tarafından kaldırılan içerikler yayında görünmez; hesap silinene kadar kayıtlarda tutulur.
- Şikâyet kayıtları: sonuçlandırılmasından itibaren 2 yıl.
- SMS ve e-posta gönderim kayıtları: 2 yıl.
- Üye olmayan kişilerin destek e-postaları: talebin kapanmasından itibaren 2 yıl.
- Sözleşme onay kayıtları, yönetici işlem kayıtları ve hesap durumu geçmişi: hukuki yükümlülük ve olası uyuşmazlıklar için hesabın silinmesinden itibaren 10 yıl; hesap silindiğinde bu kayıtlardaki kişisel alanlar maskelenir.
- Veritabanı yedekleri: en fazla 7 gün; bu süre sonunda yedekteki kopyalar da silinir.

Süre sonunda veriler silinir, yok edilir veya anonim hâle getirilir.

## 10. Yaş sınırı

HizmetCep üyeliği 18 yaşını doldurmuş kişilerle sınırlıdır. Kullanım Sözleşmesi''ni kabul ederek 18 yaşını doldurduğunuzu beyan edersiniz. Doğum tarihi istenmez.

## 11. Çerezler

Web sitesinde yalnızca hizmetin çalışması ve hesap güvenliği için zorunlu çerez ve tarayıcı depoları kullanılır. Reklam, pazarlama veya analiz çerezi kullanılmaz. Ayrıntılar Çerez Politikası''ndadır. Mobil uygulama çerez kullanmaz.

## 12. İlgili kişi hakları ve başvuru

KVKK''nın 11. maddesindeki haklarınız için onur@hizmetcep.com adresine başvurabilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır; kimliğinizi doğrulamak için ek bilgi istenebilir. Başvurunuzun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi hâlinde Kişisel Verileri Koruma Kurulu''na şikâyette bulunabilirsiniz.

## 13. Güncellemeler

Politika güncellendiğinde yeni sürüm, sürüm numarası ve yürürlük tarihiyle uygulamada ve web sitesinde yayımlanır.',
       'f07c6ad401aaabdbf6ef4452f7ed10c461801a2d5ecb67a7b70d717499768af5', '2026-10-29', 'PUBLISHED', NULL, '2026-10-29T13:00:00.000Z', NULL, '2026-10-29T13:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'privacy')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-29102026f001')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'privacy' AND status = 'PUBLISHED');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'terms' AND status = 'PUBLISHED' AND sha256 = '2f2ce979d44882d48fdc0844e3c2b1e3d8f184a8a53d105f6ab22240d01db2ef'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-29102026f002');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-29102026f002', 'terms',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'terms'),
       '## 1. Taraflar ve tanımlar

İşbu Kullanım Sözleşmesi (“Sözleşme”), HizmetCep isimli dijital platformu işleten Onur Bütün (“İşletmeci”) ile HizmetCep’e kayıt olan veya platformu kullanan gerçek kişi (“Kullanıcı”) arasında, Kullanıcı’nın elektronik ortamda Sözleşme’yi kabul etmesiyle yürürlüğe girer.

İşletmeci iletişim bilgileri: Onur Bütün. Adres: İzmir/Türkiye. E-posta: onur@hizmetcep.com.

“Platform”; HizmetCep mobil uygulamasını, web arayüzünü ve bunlarla bağlantılı kullanıcı ekranlarını ifade eder. “Hizmet Alan”; platform üzerinden hizmet arayan, talep veya ilan oluşturan kullanıcıdır. “Hizmet Veren”; profil oluşturan, hizmet sunmayı tanıtan veya taleplere teklif veren kullanıcıdır. Bir kullanıcı, platformun izin verdiği ölçüde her iki rolde de işlem yapabilir.

## 2. Sözleşmenin konusu ve kapsamı

Bu Sözleşme; hesap oluşturma ve kullanma, kullanıcı profilleri, ilanlar ve hizmet talepleri, teklif süreçleri, kullanıcılar arası iletişim, kullanıcı içerikleri, güvenlik, şikâyetler, hesap kısıtlamaları ve üyeliğin sona ermesine ilişkin temel şartları düzenler.

HizmetCep başlangıçta İzmir''de hizmet vermektedir. Hizmet verilen bölgeler ve özellikler uygulamada gösterilir.

## 3. Platformun niteliği ve İşletmecinin rolü

HizmetCep, hizmet almak isteyen kişiler ile hizmet sunmak isteyen kişileri dijital ortamda buluşturmayı amaçlayan bir platformdur. İşletmeci, kullanıcılar arasındaki işi bizzat yapan hizmet sağlayıcı, işveren, yüklenici veya hizmet sözleşmesinin tarafı değildir.

Hizmetin kapsamı, fiyatı, zamanı, ödeme şekli, malzeme giderleri, teslim, iptal, garanti, ayıp, yeniden iş yapma ve diğer ticari koşullar, ilgili kullanıcılar arasında kararlaştırılır. Kullanıcılar anlaşmalarını ve önemli koşulları işlem öncesinde açıkça belirlemelidir.

Bir profilin, yorumun, teklifin veya ilanın platformda bulunması; kişinin kimliğinin, mesleki yeterliliğinin, ruhsatının, sigortasının, referanslarının, güvenilirliğinin veya hizmet kalitesinin İşletmeci tarafından kesin olarak doğrulandığı anlamına gelmez. Platformda yapılan doğrulama, telefon numarasının ve kullanıcı doğrularsa e-posta adresinin hesap sahibine ait olduğunun doğrulanmasıyla sınırlıdır.

Bu maddeler, İşletmecinin kendi kusurundan, kanundan doğan yükümlülüklerinden veya emredici mevzuat uyarınca sorumlu olduğu durumlardan kaynaklanan sorumluluğunu ortadan kaldıracak şekilde yorumlanamaz.

## 4. Üyelik şartları ve yaş koşulu

HizmetCep’e üye olabilmek ve platformu bağımsız olarak kullanabilmek için Kullanıcı’nın 18 yaşını doldurmuş olması gerekir. Kullanıcı, Sözleşme’yi elektronik ortamda kabul ederek 18 yaşını doldurduğunu ve verdiği bilgilerin doğru olduğunu beyan eder.

Bu beyan, Sözleşme''nin kabulüyle birlikte tarih-saat ve sözleşme sürümüyle kayıt altına alınır. İşletmeci kullanıcının yaşını ayrıca belgeyle doğrulamaz; gerçeğe aykırı beyan tespit edilirse hesap hakkında madde 12''deki tedbirler uygulanabilir.

Kullanıcı, kayıt sırasında doğru, güncel ve kendisine ait bilgileri vermek; iletişim bilgileri değiştiğinde bunları güncellemekle yükümlüdür. Başkasının kimliğini kullanmak, gerçeğe aykırı bilgi vermek veya bir başkası adına yetkisiz hesap açmak yasaktır.

## 5. Hesap güvenliği ve kullanım sorumluluğu

Kullanıcı, hesabına ait giriş bilgilerini ve doğrulama kodlarını korumalı; bunları başkalarıyla paylaşmamalıdır. Hesabının izinsiz kullanıldığını düşündüğünde İşletmeci’ye gecikmeden bildirimde bulunmalıdır.

Kullanıcı hesabı üzerinden gerçekleştirilen işlemler, aksi kanıtlanana kadar hesap güvenliği bakımından dikkate alınabilir; ancak bu hüküm, olayın koşullarına göre yapılması gereken incelemeyi veya kanuni hakları ortadan kaldırmaz.

İşletmeci; güvenlik, kötüye kullanımın önlenmesi, hukuki yükümlülüklerin yerine getirilmesi veya destek amacıyla gerekli ve ölçülü doğrulama adımları uygulayabilir.

## 6. Kullanıcının yükümlülükleri ve yasaklanan davranışlar

Kullanıcı; yürürlükteki mevzuata, bu Sözleşme’ye, uygulama içi kurallara ve diğer kullanıcıların haklarına uygun davranır.

Aşağıdaki davranışlar yasaktır: sahte veya yanıltıcı profil/ilan/teklif oluşturmak; gerçekte sunulmayan hizmeti varmış gibi tanıtmak; dolandırıcılık veya ödeme kötüye kullanımı; tehdit, taciz, ayrımcılık veya hakaret; izinsiz kişisel veri paylaşımı; fikrî mülkiyet ihlali; zararlı yazılım, güvenlik açığı istismarı veya platformun çalışmasını bozma girişimi; spam; sahte yorum ve değerlendirmeler; hukuka aykırı ürün veya hizmetlerin tanıtımı; platformu hukuka aykırı amaçlarla kullanmak.

Kullanıcı, başka kişilerin telefon, e-posta, adres, fotoğraf veya diğer kişisel verilerini hukuki dayanak ve gerekli izin olmadan paylaşamaz; platformdan edindiği bilgileri amaç dışı kullanamaz.

Kullanıcı, sunduğu hizmetin gerektirdiği mesleki yeterlilik, izin, ruhsat, vergi ve diğer yasal yükümlülüklerden kendisi sorumludur.

## 7. Profil, ilan, talep ve teklif kuralları

Kullanıcı, profil, ilan, talep ve tekliflerinde doğru, güncel, açık ve yanıltıcı olmayan bilgi vermelidir. Fiyat, kapsam, süre, konum ve hizmet koşulları mümkün olduğunca açıkça belirtilmelidir.

İşletmeci; hukuka aykırı, yanıltıcı, güvenlik riski oluşturan, şikâyet edilen veya bu Sözleşme’yi ihlal ettiği yönünde makul gerekçe bulunan içerikleri inceleyebilir; gerekli ve orantılı tedbirleri uygulayabilir.

İlanın veya teklifin yayımlanması, İşletmeci’nin ilgili hizmeti onayladığı, garanti ettiği veya taraflar arasında bir sözleşmenin kurulduğunu kabul ettiği anlamına gelmez.

## 8. Kullanıcı içerikleri ve fikrî haklar

Kullanıcı; profil metni, fotoğraf, ilan, talep, teklif, mesaj, değerlendirme ve yüklediği diğer içeriklerin (“Kullanıcı İçeriği”) hukuka uygun olduğunu ve bunları paylaşmaya yetkili bulunduğunu beyan eder.

Kullanıcı, Kullanıcı İçeriği üzerindeki haklarını saklı tutar. Kullanıcı, içeriğin platformda gösterilmesi, saklanması, iletilmesi, yedeklenmesi ve hizmetin sunulması için teknik olarak gerekli işlemlerin yapılmasına yönelik, platformu işletmek amacıyla sınırlı, münhasır olmayan ve kullanım süresiyle sınırlı bir izin verir. Bu izin, içeriğin bağımsız reklam amacıyla sınırsız kullanımına izin vermez.

Kullanıcı, üçüncü kişilerin telif, marka, kişilik ve gizlilik haklarını ihlal eden içerik paylaşamaz. Hak ihlali bildirimi için İşletmeci’ye e-posta yoluyla başvurulabilir.

## 9. Kullanıcılar arası iletişim ve hizmet anlaşmazlıkları

Kullanıcılar; hizmetin kapsamını, fiyatını, zamanı, ödeme ve iptal koşullarını, malzeme ve ulaşım giderlerini, teslim/ifa şartlarını ve varsa garanti koşullarını doğrudan ve açık biçimde kararlaştırmalıdır.

HizmetCep ödeme aracılığı, emanet, sigorta, garanti veya uyuşmazlık çözüm hizmeti sunmaz; hizmet bedeli ve ödeme doğrudan kullanıcılar arasında kararlaştırılır ve yapılır.

Kullanıcılar arası uyuşmazlıklarda İşletmeci, elindeki ilgili kayıtları hukuka uygun ve gerekli olduğu ölçüde inceleyebilir; ancak uyuşmazlığın tarafı olmadığı durumlarda her uyuşmazlığı çözmeyi veya zararı karşılamayı taahhüt etmez. Kanuni başvuru ve tüketici hakları saklıdır.

## 10. Mesajlar, denetim ve şikâyetler

Platform içi mesajlar, hizmetin sunulması ve kullanıcılar arası iletişim için işlenebilir. Kullanıcılar mesajlarda tehdit, taciz, dolandırıcılık, hukuka aykırı içerik veya izinsiz kişisel veri paylaşımı yapamaz.

Yetkili personel mesajlara yalnızca şikâyet incelemesi, güvenlik, kötüye kullanımın önlenmesi, teknik destek veya hukuki yükümlülük amacıyla erişebilir. Her erişim için gerekçe girilmesi zorunludur ve erişim kayıt altına alınır.

Şikâyetler uygulamadaki Destek Merkezi''nden veya destek@hizmetcep.com adresinden iletilebilir. İşletmeci, başvuruyu değerlendirmek için gerekli açıklama ve kanıtları ölçülü şekilde isteyebilir.

## 11. Ücretler, ödeme ve tanıtımlar

HizmetCep şu anda ücretsiz olarak sunulmaktadır. Bu, gelecekte ücretli özellik eklenmeyeceği anlamına gelmez.

İleride üyelik, ilan, teklif, reklam veya başka bir özellik için ücret uygulanacaksa, uygulanabilir mevzuatın gerektirdiği bilgilendirme ve onay süreçleri tamamlanmadan Kullanıcı’dan ücret talep edilmez. Ücretli bir özellik varsa ücret, kapsam, tahsilat ve iptal koşulları işlem öncesinde açıkça gösterilir.

HizmetCep pazarlama amaçlı ticari elektronik ileti göndermez. Uygulamanın gönderdiği SMS, e-posta ve bildirimler yalnızca hesabınız ve işlemlerinizle ilgilidir. İleride ticari elektronik ileti gönderilecekse, bu Sözleşme''den ayrı olarak mevzuata uygun izin alınır ve izni geri çekme imkânı sunulur.

## 12. İçeriğin kaldırılması ve hesap kısıtlamaları

İşletmeci; güvenlik riski, hukuka aykırılık, sahtecilik, kötüye kullanım, hak ihlali veya Sözleşme’nin ihlali hakkında makul gerekçe bulunduğunda, olayın ağırlığına göre içerik görünürlüğünü sınırlayabilir, içeriği kaldırabilir, kullanıcıdan açıklama isteyebilir veya hesabı geçici olarak kısıtlayabilir ya da sonlandırabilir.

Acil güvenlik veya hukuki zorunluluk bulunan hâller dışında tedbirler mümkün olduğu ölçüde gerekçeli ve orantılı olarak uygulanır. Kullanıcı, uygulanan tedbir hakkında açıklama isteyebilir ve kanuni başvuru yollarını kullanabilir.

İşletmeci, kanunen zorunlu bildirimleri yapabilir ve hukuka uygun talepler üzerine yetkili kamu kurumlarıyla iş birliği yapabilir.

## 13. Hizmetin kullanılabilirliği, bakım ve değişiklikler

Platformun kesintisiz, hatasız veya her cihazda aynı şekilde çalışacağı garanti edilmez. Bakım, güncelleme, ağ sorunları, üçüncü taraf hizmetlerdeki arızalar veya kontrol dışındaki olaylar geçici kesintilere neden olabilir.

İşletmeci; güvenlik, mevzuata uyum, ürün geliştirme veya operasyonel gereklilikler nedeniyle özellikleri değiştirebilir, durdurabilir veya yenilerini ekleyebilir. Kullanıcıların kanundan doğan hakları saklıdır. Esaslı değişikliklerde, gerektiğinde güncellenmiş koşullar kullanıcıya sunulur ve gerekli kabul alınır.

## 14. Kişisel veriler ve gizlilik

Kişisel verilerin işlenmesi; 6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) ve ilgili mevzuat çerçevesinde, uygulamada ve web sitesinde her zaman erişilebilen Aydınlatma Metni ve Gizlilik Politikası’nda açıklanan amaçlar, hukuki sebepler, veri kategorileri, alıcı grupları ve saklama süreleri doğrultusunda yürütülür.

Bu Sözleşme’nin kabul edilmesi, gerekli olduğu durumlarda açık rıza yerine geçmez. Kişisel verilerin yurt dışındaki sunucularda işlenmesine ilişkin açık rıza, kayıt ekranında bu Sözleşme’nin kabulünden ayrı bir onay kutusuyla alınır.

Hizmetin sunulmasında kullanılan altyapı sağlayıcıları ve yurt dışına aktarım Gizlilik Politikası ile Aydınlatma Metni''nde açıklanmıştır.

İşletmeci, hukuki yükümlülükleri çerçevesinde uygun teknik ve idari tedbirleri almayı hedefler. Hiçbir sistem için mutlak güvenlik garantisi verilmez.

## 15. Hesap kapatma, silme ve saklama

Kullanıcı, uygulamadaki hesap silme işleviyle veya destek@hizmetcep.com adresine yazarak hesap silme talebinde bulunabilir. Uygulamadan verilen talep 30 gün sonra uygulanır ve bu süre içinde iptal edilebilir. Talebin hesap sahibinden geldiğini doğrulamak için gerekli ve ölçülü ek doğrulama istenebilir.

Silme uygulandığında hesap ve profil bilgileri, kullanıcının yazdığı ilan, teklif, talep, mesaj ve yorum metinleri, fotoğraflar ve bildirim jetonları silinir veya anonim hâle getirilir. Ayrıntılar Gizlilik Politikası''ndadır.

Kanunen saklanması gereken veya bir hakkın tesisi, kullanılması ya da korunması için gerekli sınırlı kayıtlar, gerekli amaç ve süreyle saklanabilir. Yedeklerdeki kopyalar en fazla 7 gün içinde silinir.

## 16. Sorumluluk ve kanuni haklar

Kullanıcı, kendi beyanlarının, içeriklerinin, platformu kullanımının ve hizmet sunarken yerine getirmesi gereken yasal yükümlülüklerin sorumluluğunu taşır.

İşletmeci’nin sorumluluğu, yürürlükteki emredici mevzuat ve somut olayın koşulları çerçevesinde değerlendirilir. İşbu Sözleşme; kasıt veya ağır kusurdan doğan sorumluluğu, tüketicinin emredici haklarını veya kanunen sınırlandırılamayan sorumlulukları ortadan kaldırmaz.

İşletmeci, kullanıcıların birbirlerinin kimliğini, yetkinliğini, davranışını veya sunduğu hizmeti her durumda doğruladığına dair genel bir garanti vermez. Kullanıcılar, hizmet almadan veya vermeden önce karşı tarafı ve anlaşma koşullarını makul ölçüde değerlendirmelidir.

## 17. Mücbir sebepler

Tarafların makul kontrolü dışında gelişen ve yükümlülüklerin yerine getirilmesini engelleyen doğal afet, savaş, yaygın altyapı kesintisi, kamu otoritesi kararı, siber olay veya benzeri olayların etkileri, yürürlükteki mevzuat çerçevesinde değerlendirilir. Bu madde, olayın niteliğine göre doğabilecek kanuni yükümlülükleri ortadan kaldırmaz.

## 18. Sözleşmenin yürürlüğü, güncellenmesi ve sona ermesi

Sözleşme, Kullanıcı tarafından elektronik ortamda kabul edildiği tarihte yürürlüğe girer ve üyelik sona erene kadar uygulanır.

İşletmeci, Sözleşme’yi hukuki veya operasyonel gereklilikler nedeniyle güncelleyebilir. Güncel metin, sürüm numarası ve yürürlük tarihiyle yayımlanır. Kullanıcının yeniden kabulünün gerekli olduğu değişikliklerde, gerekli kabul alınmadan değişiklik kullanıcı aleyhine uygulanmaz.

Kullanıcı hesabını kapatarak platform kullanımını sona erdirebilir. Sona erme, niteliği gereği devam eden hükümleri veya kanunen saklanması gereken kayıtları ortadan kaldırmaz.

## 19. Bildirimler ve iletişim

Kullanıcı; destek, şikâyet, içerik ihlali ve hesap silme taleplerini uygulamadaki Destek Merkezi''nden veya destek@hizmetcep.com adresinden iletebilir. Başvuruda konu ve talep açıkça belirtilmelidir.

Elektronik bildirimlerin hukuki sonuç doğuracağı durumlarda yürürlükteki mevzuatın öngördüğü şekil ve ispat kuralları saklıdır.

## 20. Uygulanacak hukuk ve uyuşmazlıklar

Bu Sözleşme Türkiye Cumhuriyeti hukukuna tabidir. Uyuşmazlıklarda görevli ve yetkili mahkemeler ile tüketici hakem heyetleri, uygulanabilir mevzuata göre belirlenir. Tüketicinin kanunen sahip olduğu başvuru yolları ve yetkiler bu Sözleşme ile sınırlandırılamaz.

## 21. Son hükümler ve elektronik kabul

Kullanıcı kayıt sırasında Sözleşme''nin tam metnini açabilir. Kabul edilen sürüm, sürümün özeti (SHA-256), tarih-saat ve platform bilgisi kayıt altına alınır.

Sözleşme’nin bir hükmünün geçersiz veya uygulanamaz olması, diğer hükümlerin geçerliliğini kendiliğinden ortadan kaldırmaz; ilgili hüküm emredici mevzuata uygun şekilde değerlendirilir.

Kullanıcı, “Kullanım Sözleşmesi’ni okudum ve kabul ediyorum” şeklindeki ayrı sözleşme kabul işlemini tamamlayarak bu metni elektronik ortamda kabul eder. Bu kabul; KVKK Aydınlatma Metni’nin okunduğuna dair bilgilendirme, gerekli açık rızalar veya ticari elektronik ileti izinleriyle aynı işlem olarak değerlendirilmez.',
       '60c440b1cc631ce191070381c5e5e2b2e7c9a08d107ba577d2ed0ca90cdbde11', '2026-10-29', 'PUBLISHED', NULL, '2026-10-29T13:00:00.000Z', NULL, '2026-10-29T13:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-29102026f002')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'terms' AND status = 'PUBLISHED');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'kvkk' AND status = 'PUBLISHED' AND sha256 = '196483ca8cb5c34500934d415544f64a951d2e2ff560c847edda77e8059f4450'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-29102026f003');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-29102026f003', 'kvkk',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'kvkk'),
       'Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu''nun ("KVKK") 10. maddesi uyarınca, HizmetCep kullanıcılarını kişisel verilerinin işlenmesi hakkında bilgilendirmek için hazırlanmıştır. Ayrıntılı bilgi Gizlilik Politikası''ndadır.

## 1. Veri sorumlusu

Veri sorumlusu: Onur Bütün
Adres: İzmir/Türkiye
E-posta: onur@hizmetcep.com

## 2. İşlenen kişisel veri kategorileri

- **Kimlik ve iletişim:** ad-soyad, telefon numarası, e-posta adresi.
- **Hesap:** şifre özeti, kullanıcı rolleri, bildirim tercihleri, hesap durumu.
- **Adres ve hizmet bölgesi:** il, ilçe, mahalle; hizmet verenler için hizmet kategorileri ve ilçeler.
- **Hizmet içerikleri:** ilanlar, fotoğraflar, teklifler, teklif talepleri, uygulama içi mesajlar, yorumlar ve puanlar.
- **Şikâyetler:** yaptığınız şikâyetlerin nedeni ve açıklaması; hakkınızdaki şikâyetlerin konusu ve sonucu.
- **Destek:** destek talepleri, destek e-postaları ve uygulama geri bildirimleri.
- **Hukuki işlem:** Kullanım Sözleşmesi onay kayıtları, Gizlilik Politikası ve Aydınlatma Metni''nin gösterildiğine ve yurt dışındaki sunucularda işlemeye açık rıza verildiğine ilişkin kayıtlar; hesap dondurma ve silme talepleri.
- **İşlem güvenliği:** oturum kayıtları (IP adresi, tarayıcı/cihaz bilgisi), doğrulama kodu kayıtları, bildirim jetonu, yönetici işlem kayıtları.
- **Trafik kayıtları:** işlem yaptığınızda IP adresi, kaynak port numarası, işlemin türü ve tarih-saati.

## 3. İşleme amaçları ve hukuki sebepler

- Üyeliğin oluşturulması ve yönetilmesi; telefon ve e-posta doğrulaması; hizmet alanlarla hizmet verenlerin buluşturulması; ilan, teklif, talep ve mesajlaşma süreçlerinin yürütülmesi; seçiminize göre iletişim bilgisinin karşı tarafla paylaşılması; bildirim gönderilmesi — sözleşmenin kurulması ve ifası (KVKK m.5/2-c).
- Destek taleplerinin ve şikâyetlerin değerlendirilmesi, aykırı içeriklerin kaldırılması — sözleşmenin ifası, hukuki yükümlülük ve meşru menfaat (m.5/2-c, ç ve f).
- Hesap güvenliğinin sağlanması, kötüye kullanımın önlenmesi ve teknik sorunların giderilmesi — meşru menfaat (m.5/2-f).
- 5651 sayılı Kanun kapsamında trafik kayıtlarının 1 yıl saklanması ve yetkili mercilere sunulması — hukuki yükümlülük (m.5/2-ç).
- Onay ve işlem kayıtlarının tutulması, hukuki yükümlülüklerin yerine getirilmesi ve hakların korunması — hukuki yükümlülük ve hakkın tesisi, kullanılması veya korunması (m.5/2-ç ve e).

Bu metin bir bilgilendirmedir; açık rıza veya onay anlamına gelmez.

## 4. Toplama yöntemi

Kişisel verileriniz mobil uygulama ve web sitesi üzerinden; doldurduğunuz alanlar, yaptığınız işlemler, destek e-postaları ve otomatik sistem kayıtlarıyla elektronik ortamda toplanır.

## 5. Aktarım ve yurt dışındaki sunucularda işleme

Kişisel verileriniz şu taraflara aktarılabilir:

- **Diğer kullanıcılar:** hizmetin gerektirdiği ölçüde ve seçiminize göre.
- **Hizmet sağlayıcılar:** Render (sunucu ve veritabanı), Cloudflare (ağ trafiği ve fotoğraf depolama), Google (Firebase: telefon doğrulama kodu SMS''i, kimlik doğrulama, giriş ve bildirim), Apple (iOS bildirim iletimi), Resend (e-posta), GitHub (web sitesi barındırma).
- **Yetkili kamu kurum ve kuruluşları ile adli merciler:** kanuni yükümlülük hâlinde.

**Yurt dışı sunucular:** HizmetCep''in altyapısı yurt dışındaki sunucularda çalışır ve kişisel verileriniz hizmetin sunulması amacıyla bu sunucularda saklanır ve işlenir:

- Render — Almanya (Frankfurt): uygulama sunucusu ve veritabanı; hesap, içerik, onay, oturum ve trafik kayıtları burada tutulur.
- Cloudflare — Avrupa: fotoğraf depolama; ağ trafiği Cloudflare''in küresel ağı üzerinden iletilir.
- Google Firebase — ABD ve küresel veri merkezleri: telefon doğrulama kodu SMS''leri Firebase tarafından gönderilir; kullanıcı kimliği (UID), telefon numarası, e-posta adresi, giriş bilgileri, doğrulama sırasında cihaz ve IP bilgisi ile bildirim jetonları burada işlenir.
- Apple (ABD), Resend (Japonya üzerinden gönderim, ABD şirketi) ve GitHub (ABD).

Yurt dışına aktarım KVKK''nın 9. maddesinde öngörülen standart sözleşme usulüyle yapılır; standart sözleşmeler imzalandıktan sonra 5 iş günü içinde Kişisel Verileri Koruma Kurulu''na bildirilir. Ayrıca kayıt sırasında, yurt dışındaki sunucularda işlemeye ayrı bir onay kutusuyla açık rızanız alınır; rızanızı onur@hizmetcep.com adresine başvurarak geri alabilirsiniz (geri alınması hâlinde hizmet sunulamayabilir). Ayrıntılar Gizlilik Politikası''ndadır.

## 6. Saklama süresi

Veriler, işleme amacının gerektirdiği süre ve mevzuattaki saklama süreleri boyunca tutulur; süre sonunda silinir, yok edilir veya anonim hâle getirilir. Trafik kayıtları 5651 sayılı Kanun uyarınca 1 yıl (365 gün) saklanır; hesap silinse de bu süre dolmadan silinmez. Hesap silindiğinde, trafik kayıtlarının yetkili merci talebinde eşleştirilebilmesi için ad, telefon ve e-posta bilgisi ayrı bir yasal arşivde 1 yıl tutulur. Hesap silme talebi 30 gün sonra uygulanır. Kategori bazında süreler Gizlilik Politikası''ndadır.

## 7. Haklarınız

KVKK''nın 11. maddesi uyarınca şu haklara sahipsiniz:

- kişisel verilerinizin işlenip işlenmediğini öğrenme;
- işlenmişse buna ilişkin bilgi talep etme;
- işleme amacını ve amaca uygun kullanılıp kullanılmadığını öğrenme;
- yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme;
- eksik veya yanlış işlenmişse düzeltilmesini isteme;
- kanuni şartlar çerçevesinde silinmesini veya yok edilmesini isteme;
- bu işlemlerin aktarılan üçüncü kişilere bildirilmesini isteme;
- münhasıran otomatik sistemlerle analiz edilmesi sonucu aleyhinize bir sonucun ortaya çıkmasına itiraz etme;
- kanuna aykırı işleme nedeniyle zarara uğramanız hâlinde zararın giderilmesini talep etme.

## 8. Başvuru

Taleplerinizi, kimliğinizi ve talebinizi değerlendirmeye yetecek bilgilerle birlikte onur@hizmetcep.com adresine e-postayla iletebilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır. Başvurunuzun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi hâlinde Kişisel Verileri Koruma Kurulu''na şikâyette bulunabilirsiniz.',
       '4d5023498dedcbab6d068bc52c2d393c7fe90cb9caba936dfa13f293a184e066', '2026-10-29', 'PUBLISHED', NULL, '2026-10-29T13:00:00.000Z', NULL, '2026-10-29T13:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'kvkk')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-29102026f003')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'kvkk' AND status = 'PUBLISHED');
