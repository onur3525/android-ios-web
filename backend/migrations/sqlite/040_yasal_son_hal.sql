-- 040 — YASAL METİNLERİN SON HÂLİ (23 Eki, işletmeci talimatı: "hukuki
-- boyutta içerikleri düzelt, HizmetCep'i ilgilendirmeyen yazıları çıkar,
-- onaylatılması gerekenlerin onaylatıldığından emin ol").
--
-- Yayımdaki Gizlilik Politikası, Kullanım Sözleşmesi ve Aydınlatma Metni'nin
-- içinde kalan hazırlık notları ("YAYIN ENGELİ", "doğrulanmalıdır", "test
-- sürümü" vb.) çıkarıldı; boş kalan bölümler (hukuki sebepler, alıcılar,
-- yurt dışı aktarım, saklama süreleri) uygulamanın GERÇEK işleyişine göre
-- dolduruldu. Çerez Politikası'nda not yoktu, değişmedi.
--
-- ⚠ GÜVENLİK KİLİDİ: yalnız yayımdaki sürüm 036'nın yayımladığı metnin
-- AYNISIYSA (sha256) değiştirilir; panelden başka sürüm yayımlanmışsa o
-- belgeye DOKUNULMAZ. Eski sürümler silinmez, ARCHIVED olur. 035 taslakları
-- (bu metinlerle aşıldı) DRAFT ise arşivlenir.
-- ⚠ Kullanım Sözleşmesi onay isteyen belgedir: kullanıcılardan yeni sürüm
-- için onay istenir. Aydınlatma ve Gizlilik bilgilendirmedir, onay istemez.

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE status = 'DRAFT' AND id IN ('7b0e6f2a-3c1d-4e5f-9a8b-23102026b011', '7b0e6f2a-3c1d-4e5f-9a8b-23102026b012',
                                    '7b0e6f2a-3c1d-4e5f-9a8b-23102026b013', '7b0e6f2a-3c1d-4e5f-9a8b-23102026b014');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'privacy' AND status = 'PUBLISHED' AND sha256 = 'd90bdf13499e41c4c32771f0223dd68e30501cc96df4460dae7b98211539b116'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026e001');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026e001', 'privacy',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'privacy'),
       '## 1. Veri sorumlusu

HizmetCep''in işletmecisi ve kişisel veriler bakımından veri sorumlusu Onur Bütün''dür.
E-posta: onur_butun@hotmail.com

Bu politika, HizmetCep mobil uygulaması ve web sitesi üzerinden işlenen kişisel verileri açıklar. Kısa bilgilendirme Aydınlatma Metni''nde, web sitesindeki çerezler Çerez Politikası''nda yer alır.

## 2. İşlenen kişisel veriler

- Kimlik ve iletişim: ad-soyad, telefon numarası, e-posta adresi.
- Hesap: şifre (yalnızca geri döndürülemez özeti saklanır), kullanıcı rolleri (hizmet alan / hizmet veren), bildirim tercihleri, hesap durumu.
- Adres ve hizmet bölgesi: il, ilçe ve mahalle; hizmet verenler için hizmet kategorileri ve hizmet verilen ilçeler.
- Hizmet içerikleri: ilanlar (hizmet adı, konum açıklaması, açıklama, fotoğraflar, iş zamanı, iletişim tercihi), teklifler (tutar ve not), teklif talepleri, uygulama içi mesajlar ve mesajlardaki fotoğraflar, yorumlar ve puanlar, profil fotoğrafı.
- Destek: uygulamadan veya e-postayla iletilen destek talepleri ve yazışmalar, uygulama geri bildirimleri.
- Hukuki işlem: Kullanım Sözleşmesi''nin kabul edilen sürümü ve Aydınlatma Metni''nin gösterildiğine ilişkin kayıt (tarih-saat, sürüm, platform); hesap dondurma ve silme talepleri; hesap durumu değişiklikleri.
- İşlem güvenliği: oturum kayıtları (IP adresi, tarayıcı/cihaz bilgisi), doğrulama kodu kayıtları, bildirim (push) jetonu, yönetici işlem kayıtları.

HizmetCep GPS veya arka planda konum takibi yapmaz. Yüklenen fotoğraflardaki konum ve cihaz bilgisi (EXIF/GPS meta verisi) yüklemeden önce uygulama tarafından silinir. Özel nitelikli kişisel veri (sağlık, din, biyometrik veri vb.) istenmez; kullanıcıların bu tür bilgileri ilan, mesaj veya yorumlarda paylaşmaması gerekir.

## 3. İşleme amaçları ve hukuki sebepler

6698 sayılı Kişisel Verilerin Korunması Kanunu''nun ("KVKK") 5. maddesinin 2. fıkrası kapsamında:

- Üyeliğin oluşturulması ve yönetilmesi, telefon ve e-posta doğrulaması; ilan, teklif, teklif talebi, mesajlaşma, yorum ve profil özelliklerinin sunulması; seçiminize göre iletişim bilginizin karşı tarafla paylaşılması; işlemlerinizle ilgili bildirim gönderilmesi — sözleşmenin kurulması ve ifası (c bendi).
- Destek taleplerinin ve şikâyetlerin değerlendirilmesi — sözleşmenin ifası (c bendi) ve meşru menfaat (f bendi).
- Hesap güvenliğinin sağlanması, kötüye kullanımın önlenmesi, oturum ve güvenlik kayıtlarının tutulması, teknik sorunların giderilmesi — meşru menfaat (f bendi).
- Sözleşme onay kayıtlarının, yönetici işlem kayıtlarının ve hesap silme taleplerinin tutulması; yetkili mercilerin taleplerinin karşılanması — hukuki yükümlülük (ç bendi) ve bir hakkın tesisi, kullanılması veya korunması (e bendi).

Kullanım Sözleşmesi''nin kabulü açık rıza yerine geçmez. HizmetCep''in mevcut işleyişinde açık rızaya dayanan bir işleme faaliyeti yoktur; ileride gerekirse ayrı ve isteğe bağlı olarak istenir.

## 4. Kişisel verilerin aktarıldığı taraflar

- Diğer kullanıcılar: hizmet akışı için gerekli profil, ilan, teklif ve talep bilgileri ile seçiminize göre paylaşılan iletişim bilgisi (bkz. madde 6).
- Hizmet sağlayıcılar (veri işleyenler):
  - Google LLC — Firebase Authentication (telefon doğrulama kodu SMS''i, e-posta doğrulaması, giriş) ve Firebase Cloud Messaging (bildirim gönderimi).
  - Apple Inc. — iOS cihazlara bildirim iletimi (Apple Push Notification service).
  - Render Services, Inc. — uygulama sunucusu ve veritabanı barındırma.
  - Cloudflare, Inc. — fotoğrafların saklanması (Cloudflare R2).
  - Resend — e-posta gönderimi ve destek adresine gelen e-postaların alınması.
  - GitHub, Inc. — web sitesinin barındırılması (ziyaretçinin IP adresi ve tarayıcı bilgisi).
- Yetkili kamu kurum ve kuruluşları ile adli merciler: geçerli bir hukuki talep veya kanuni yükümlülük olduğunda.
- Gerektiği ölçüde hukuk ve mali müşavirlik gibi profesyonel danışmanlar.

## 5. Yurt dışına aktarım

Yukarıdaki hizmet sağlayıcıların sunucuları Türkiye dışındadır:

- Google LLC ve Apple Inc. — Amerika Birleşik Devletleri ve şirketlerin küresel veri merkezleri.
- Render — Almanya (Frankfurt).
- Cloudflare R2 — Avrupa.
- Resend — Japonya (Tokyo) üzerinden gönderim; şirket Amerika Birleşik Devletleri''ndedir.
- GitHub — Amerika Birleşik Devletleri.

Bu aktarımlar KVKK''nın 9. maddesinde öngörülen standart sözleşme usulüne tabidir; standart sözleşmeler imzalandıktan sonra 5 iş günü içinde Kişisel Verileri Koruma Kurulu''na bildirilir. Aktarılan veriler, ilgili sağlayıcının hizmeti için gerekli olanlarla sınırlıdır.

## 6. İletişim bilgilerinin paylaşılması

Telefon numarası herkese açık profil bilgisi değildir.

- İlan akışında: Hizmet alan ile teklif veren hizmet veren arasında iletişim açıldığında, hizmet verenin telefonu hizmet alana gösterilir. Hizmet alanın telefonu yalnızca ilanda "Telefonumu göster" seçildiyse hizmet verene gösterilir; "Sadece uygulama içi mesaj" seçildiyse hiçbir ekranda paylaşılmaz.
- Teklif talebi akışında: Hizmet veren teklif verdikten sonra, talep süresi dolmadığı sürece iletişim açıktır. Hizmet alanın telefonu yalnızca "Telefonumu göster" seçildiyse paylaşılır.
- E-posta adresi diğer kullanıcılarla paylaşılmaz.

Kullanıcılar başkalarının iletişim bilgilerini izinsiz yayımlayamaz veya başka amaçla kullanamaz.

## 7. Yönetici erişimi ve güvenlik

Yöneticiler verilere yalnızca görevleri için gereken yetkiyle erişir. Uygulama içi mesajları görüntülemek için yöneticinin bir gerekçe girmesi zorunludur ve her erişim kayıt altına alınır. Yönetici hesapları iki aşamalı doğrulamayla korunur.

Şifreler geri döndürülemez biçimde saklanır, bağlantılar şifrelidir (HTTPS). Hiçbir sistem için mutlak güvenlik garantisi verilmez.

## 8. Saklama, hesap dondurma ve hesap silme

**Hesap dondurma:** Hesabınızı uygulamadan dondurabilirsiniz. Dondurulan hesap aramada görünmez, bildirim almaz; veriler silinmez. Yeniden giriş yaptığınızda hesap etkinleşir.

**Hesap silme:** Uygulamadan, şifrenizi girerek silme talebi oluşturursunuz. Talep 30 gün sonra uygulanır ve bu süre içinde iptal edilebilir. Silme uygulandığında:

- ad, telefon, e-posta, şifre ve profil fotoğrafları kaldırılır;
- adres, hizmet profili, bildirim jetonları, oturum kayıtları, bildirimler ve doğrulama kodu kayıtları silinir;
- yazdığınız mesaj, ilan açıklaması, teklif notu, talep ve yorum metinleri kaldırılır;
- yüklediğiniz dosyalar depolamadan silinir;
- kimlik doğrulama kaydınız Firebase''den silinir.

Karşı tarafın kendi yazdığı mesajlar onun verisi olduğu için silinmez. Yorumların yıldız puanı, kişiyle ilişkilendirilemeyecek şekilde kalır.

**Saklama süreleri:**

- Doğrulama kodları: 1 gün.
- Oturum kayıtları (IP adresi, cihaz bilgisi): oturumun süresi dolduktan sonra 30 gün.
- Sunucu hata kayıtları (kişisel veri içermez): 30 gün.
- Hesap, profil ve hizmet içerikleri (ilan, teklif, talep, mesaj, yorum, fotoğraf): hesap açık olduğu sürece; hesap silindiğinde yukarıdaki şekilde silinir.
- SMS ve e-posta gönderim kayıtları: 2 yıl.
- Üye olmayan kişilerin destek e-postaları: talebin kapanmasından itibaren 2 yıl.
- Sözleşme onay kayıtları, yönetici işlem kayıtları ve hesap durumu geçmişi: hukuki yükümlülük ve olası uyuşmazlıklar için hesabın silinmesinden itibaren 10 yıl; hesap silindiğinde bu kayıtlardaki kişisel alanlar maskelenir.
- Veritabanı yedekleri: en fazla 7 gün; bu süre sonunda yedekteki kopyalar da silinir.

Süre sonunda veriler silinir, yok edilir veya anonim hâle getirilir.

## 9. Yaş sınırı

HizmetCep üyeliği 18 yaşını doldurmuş kişilerle sınırlıdır. Kullanım Sözleşmesi''ni kabul ederek 18 yaşını doldurduğunuzu beyan edersiniz. Doğum tarihi istenmez.

## 10. Çerezler

Web sitesinde yalnızca hizmetin çalışması ve hesap güvenliği için zorunlu çerez ve tarayıcı depoları kullanılır. Reklam, pazarlama veya analiz çerezi kullanılmaz. Ayrıntılar Çerez Politikası''ndadır. Mobil uygulama çerez kullanmaz.

## 11. İlgili kişi hakları ve başvuru

KVKK''nın 11. maddesindeki haklarınız için onur_butun@hotmail.com adresine başvurabilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır; kimliğinizi doğrulamak için ek bilgi istenebilir. Başvurunuzun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi hâlinde Kişisel Verileri Koruma Kurulu''na şikâyette bulunabilirsiniz.

## 12. Güncellemeler

Politika güncellendiğinde yeni sürüm, sürüm numarası ve yürürlük tarihiyle uygulamada ve web sitesinde yayımlanır.',
       'ece793c8b48d12c56203714aa397360d4f4d1e0229a9a1d677ccafd245594794', '2026-10-23', 'PUBLISHED', NULL, '2026-10-23T13:00:00.000Z', NULL, '2026-10-23T13:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'privacy')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026e001')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'privacy' AND status = 'PUBLISHED');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'terms' AND status = 'PUBLISHED' AND sha256 = '2351068b785c01835841cfc5eb897e5449aa6531ac851094cdb13e6cb5ff78e3'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026e002');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026e002', 'terms',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'terms'),
       '## 1. Taraflar ve tanımlar

İşbu Kullanım Sözleşmesi (“Sözleşme”), HizmetCep isimli dijital platformu işleten Onur Bütün (“İşletmeci”) ile HizmetCep’e kayıt olan veya platformu kullanan gerçek kişi (“Kullanıcı”) arasında, Kullanıcı’nın elektronik ortamda Sözleşme’yi kabul etmesiyle yürürlüğe girer.

İşletmeci iletişim bilgileri: Onur Bütün. E-posta: onur_butun@hotmail.com.

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

Bu Sözleşme’nin kabul edilmesi, gerekli olduğu durumlarda açık rıza yerine geçmez. Açık rıza gereken işlemler, üyelik veya temel hizmetin şartı hâline getirilmeden ayrı ve özgür iradeye dayalı şekilde düzenlenir.

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
       '2f2ce979d44882d48fdc0844e3c2b1e3d8f184a8a53d105f6ab22240d01db2ef', '2026-10-23', 'PUBLISHED', NULL, '2026-10-23T13:00:00.000Z', NULL, '2026-10-23T13:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026e002')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'terms' AND status = 'PUBLISHED');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'kvkk' AND status = 'PUBLISHED' AND sha256 = 'c28d43712e2f8f30613388acf9ea76cad6fc3f6aa5e0e7c701420bc85c112ac9'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026e003');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026e003', 'kvkk',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'kvkk'),
       'Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu''nun ("KVKK") 10. maddesi uyarınca, HizmetCep kullanıcılarını kişisel verilerinin işlenmesi hakkında bilgilendirmek için hazırlanmıştır. Ayrıntılı bilgi Gizlilik Politikası''ndadır.

## 1. Veri sorumlusu

Veri sorumlusu: Onur Bütün
E-posta: onur_butun@hotmail.com

## 2. İşlenen kişisel veri kategorileri

- **Kimlik ve iletişim:** ad-soyad, telefon numarası, e-posta adresi.
- **Hesap:** şifre özeti, kullanıcı rolleri, bildirim tercihleri, hesap durumu.
- **Adres ve hizmet bölgesi:** il, ilçe, mahalle; hizmet verenler için hizmet kategorileri ve ilçeler.
- **Hizmet içerikleri:** ilanlar, fotoğraflar, teklifler, teklif talepleri, uygulama içi mesajlar, yorumlar ve puanlar.
- **Destek:** destek talepleri, destek e-postaları ve uygulama geri bildirimleri.
- **Hukuki işlem:** Kullanım Sözleşmesi onay kayıtları; hesap dondurma ve silme talepleri.
- **İşlem güvenliği:** oturum kayıtları (IP adresi, tarayıcı/cihaz bilgisi), doğrulama kodu kayıtları, bildirim jetonu, yönetici işlem kayıtları.

## 3. İşleme amaçları ve hukuki sebepler

- Üyeliğin oluşturulması ve yönetilmesi; telefon ve e-posta doğrulaması; hizmet alanlarla hizmet verenlerin buluşturulması; ilan, teklif, talep ve mesajlaşma süreçlerinin yürütülmesi; seçiminize göre iletişim bilgisinin karşı tarafla paylaşılması; bildirim gönderilmesi — sözleşmenin kurulması ve ifası (KVKK m.5/2-c).
- Destek taleplerinin karşılanması — sözleşmenin ifası ve meşru menfaat (m.5/2-c ve f).
- Hesap güvenliğinin sağlanması, kötüye kullanımın önlenmesi ve teknik sorunların giderilmesi — meşru menfaat (m.5/2-f).
- Onay ve işlem kayıtlarının tutulması, hukuki yükümlülüklerin yerine getirilmesi ve hakların korunması — hukuki yükümlülük ve hakkın tesisi, kullanılması veya korunması (m.5/2-ç ve e).

Bu metin bir bilgilendirmedir; açık rıza veya onay anlamına gelmez.

## 4. Toplama yöntemi

Kişisel verileriniz mobil uygulama ve web sitesi üzerinden; doldurduğunuz alanlar, yaptığınız işlemler, destek e-postaları ve otomatik sistem kayıtlarıyla elektronik ortamda toplanır.

## 5. Aktarım

Kişisel verileriniz şu taraflara aktarılabilir:

- **Diğer kullanıcılar:** hizmetin gerektirdiği ölçüde ve seçiminize göre.
- **Hizmet sağlayıcılar:** Google (Firebase: doğrulama kodu SMS''i, kimlik doğrulama ve bildirim), Apple (iOS bildirim iletimi), Render (sunucu ve veritabanı), Cloudflare (fotoğraf depolama), Resend (e-posta), GitHub (web sitesi barındırma).
- **Yetkili kamu kurum ve kuruluşları:** kanuni yükümlülük hâlinde.

Bu hizmet sağlayıcıların sunucuları Türkiye dışındadır (ABD, Almanya, Avrupa ve Japonya). Yurt dışına aktarım KVKK''nın 9. maddesinde öngörülen standart sözleşme usulüne tabidir. Ayrıntılar Gizlilik Politikası''ndadır.

## 6. Saklama süresi

Veriler, işleme amacının gerektirdiği süre ve mevzuattaki saklama süreleri boyunca tutulur; süre sonunda silinir, yok edilir veya anonim hâle getirilir. Hesap silme talebi 30 gün sonra uygulanır. Kategori bazında süreler Gizlilik Politikası''ndadır.

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

Taleplerinizi, kimliğinizi ve talebinizi değerlendirmeye yetecek bilgilerle birlikte onur_butun@hotmail.com adresine e-postayla iletebilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır. Başvurunuzun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi hâlinde Kişisel Verileri Koruma Kurulu''na şikâyette bulunabilirsiniz.',
       '196483ca8cb5c34500934d415544f64a951d2e2ff560c847edda77e8059f4450', '2026-10-23', 'PUBLISHED', NULL, '2026-10-23T13:00:00.000Z', NULL, '2026-10-23T13:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'kvkk')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026e003')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'kvkk' AND status = 'PUBLISHED');
