-- 036 — YAYIMDAKİ YASAL METİNLERDEN EV ADRESİ KALDIRILDI (23 Eki, işletmeci talimatı:
-- "Adres yerine onur_butun@hotmail.com adresini koy, ev adresini çıkardığın yere").
--
-- Yayımdaki Gizlilik Politikası, Kullanım Sözleşmesi, Aydınlatma Metni ve
-- Çerez Politikası'nın YENİ SÜRÜMÜ yayımlanır. Metin AYNIDIR; yalnız posta
-- adresi çıkar, iletişim e-postası onur_butun@hotmail.com olarak kalır.
--
-- ⚠ GÜVENLİK KİLİDİ: yalnız yayımdaki sürüm göçle yayımlanan metnin AYNISIYSA
-- (sha256 eşleşirse) değiştirilir. Admin panelinden başka bir sürüm
-- yayımlanmışsa o belgeye DOKUNULMAZ. Eski sürüm silinmez, ARCHIVED olur.
-- ⚠ Kullanım Sözleşmesi onay isteyen belge olduğu için kullanıcılardan yeni
-- sürüm için onay istenir (diğer üçü bilgilendirmedir, onay istemez).

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'privacy' AND status = 'PUBLISHED' AND sha256 = 'fdae443595b9f08c54f3bd6da1b9a4fcb51ce481c07e617ddbb422c02c55000d'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c001');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026c001', 'privacy',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'privacy'),
       '## 1. Veri sorumlusu

HizmetCep''in işletmecisi ve kişisel veriler bakımından veri sorumlusu, bu belgede belirtilen kapsamda Onur Bütün''dür. E-posta: onur_butun@hotmail.com. Bu bilgilerin yayımdan önce doğrulanması gerekir.

## 2. İşlenebilecek veri türleri

- Hesap ve iletişim: ad-soyad, telefon, e-posta, kullanıcı kimliği ve hesap/rol bilgileri.
- Üyelik kayıtları: 18 yaş beyanı, koşul ve aydınlatma metni sürümüne ilişkin kabul kayıtları ve zaman damgaları.
- Profil ve hizmet içeriği: profil bilgileri, hizmet kategorileri, il/ilçe veya kullanıcının girdiği konum, ilan açıklamaları, fotoğraflar, teklifler, talepler, yorumlar ve uygulama içi mesajlar.
- İletişim paylaşımı seçimleri, bildirim belirteçleri, doğrulama SMS/e-posta işlem kayıtları.
- Teknik ve güvenlik: oturum kayıtları, IP/cihaz bilgileri, kimlik doğrulama olayları, güvenlik kayıtları ve hata günlükleri.
- Destek/şikâyet kayıtları, yönetici erişim ve işlem kayıtları, hesap kısıtlama geçmişi, hesap silme talepleri.
- Kullanıcının yüklediği dosyalar/fotoğraflar ile dosya depolama ve silme işlemlerine ilişkin kayıtlar.

Listelenen bir veri türü, yalnızca bu belgede yazdığı için otomatik olarak toplanıyor sayılmaz. GPS veya arka planda konum takibi gibi özellikler varsa yayımdan önce ayrıca açıklanmalıdır.

## 3. İşleme amaçları

- Üyelik oluşturmak ve yönetmek; telefon/e-posta doğrulaması ve kullanıcı rollerini yürütmek.
- İlan, talep, teklif, profil ve iletişim özelliklerini sunmak.
- Kullanıcının seçimine göre iletişim bilgisini ilgili kullanıcıyla paylaşmak.
- Hesap güvenliği, kötüye kullanımın önlenmesi, hata giderme ve sistemin işletilmesi.
- Destek ve şikâyetleri değerlendirmek; hesap silme taleplerini yürütmek.
- Mevzuattan doğan yükümlülükleri yerine getirmek ve hukuki hakları tesis etmek, kullanmak veya korumak.

## 4. Hukuki sebepler

Her işlem için 6698 sayılı Kanun''da öngörülen uygun işleme şartı ayrı değerlendirilir. İşlemin niteliğine göre sözleşmenin kurulması/ifası için gereklilik, hukuki yükümlülük, bir hakkın tesisi-kullanılması-korunması veya temel hak ve özgürlüklere zarar vermemek kaydıyla meşru menfaat söz konusu olabilir. Uygun başka bir işleme şartı bulunmayan faaliyetlerde gerektiği ölçüde ayrı, belirli ve bilgilendirilmiş açık rıza alınır. Kullanım koşullarının veya bu politikanın kabulü kendiliğinden açık rıza yerine geçmez.

## 5. Veri alıcıları

- Diğer kullanıcılar: ilgili hizmet akışı için gösterilen profil/ilan içeriği ve kullanıcının seçimiyle paylaşılan iletişim bilgileri.
- Teknik altyapı, barındırma, kimlik doğrulama ve dosya depolama sağlayıcıları.
- SMS, e-posta ve bildirim sağlayıcıları: doğrulama ve kullanıcının talep ettiği iletişim için gerekli veriler.
- Yetkili kamu kurumları/adli merciler: geçerli hukuki talep veya mevzuat yükümlülüğü kapsamında.
- Gerekli olduğu ölçüde hukuk ve profesyonel danışmanlar.

Proje envanterinde Firebase/Google, Render, Cloudflare R2 ve GitHub Pages yer almaktadır. Sentry veya başka hata izleme, analiz, SMS ya da e-posta sağlayıcısı fiilen etkinse sağlayıcının rolü ve veri akışı envantere eklenmelidir. Sağlayıcıların fiilen kullanımı, hangi veriyi aldığı ve veri bölgesi teknik ayar/sözleşmelerle doğrulanmalıdır.

## 6. Yurt dışına aktarım

Bazı altyapı sağlayıcıları verileri Türkiye dışında işleyebilir veya verilere yurt dışından erişebilir. Yurt dışına kişisel veri aktarımı, 6698 sayılı Kanun''un 9. maddesi ve ilgili düzenlemelerdeki şartlardan biri sağlanmadan başlatılmamalıdır. Sağlayıcı bazında ülke, veri kategorileri, amaç, alıcı rolü ve aktarım mekanizması belirlenerek bu bölüm yayımdan önce tamamlanmalıdır.

YAYIN ENGELİ: Mevcut bilgiler, tüm sağlayıcıların veri bölgelerini, sözleşme durumlarını veya aktarım mekanizmalarının tamamlandığını kanıtlamamaktadır. Bu bölüm, gerçek sözleşme/panel bilgileriyle tamamlanıp hukukçu tarafından kontrol edilmeden nihai yayıma hazır değildir.

## 7. İletişim bilgilerinin paylaşılması

Telefon numarası herkese açık profil bilgisi olarak değerlendirilmemelidir. İlan akışında hizmet verenin iletişim bilgisini görebilmesi, hizmet alanın ilgili iletişim paylaşımını açmasına bağlıdır. Teklif/talep akışında paylaşım ilgili ekranda sunulan seçime göre yürütülür. Kullanıcılar başkalarının iletişim bilgilerini izinsiz yayımlayamaz veya başka amaçla kullanamaz. Bu açıklama, gerçek istemci ve sunucu davranışıyla doğrulanmalıdır.

## 8. Yönetici erişimi ve güvenlik

Yetkili kişiler verilere yalnız görevleri ve yetkileri ölçüsünde erişmelidir. Mesaj veya talep içeriğine yönetici erişimi, gerekli yetki ve gerekçe kontrolleriyle sınırlandırılmalıdır. İşletmeci uygun teknik ve idari tedbirler uygulamayı hedefler; hiçbir sistem için mutlak güvenlik garantisi verilmez.

## 9. Saklama ve hesap silme

Veriler, işleme amacı için gerekli süre ve uygulanabilir yasal saklama süreleri boyunca tutulur. Saklama sebebi sona erdiğinde veriler silinir, yok edilir veya anonimleştirilir. Kullanıcı uygulama içinden hesap silme talebi oluşturabilir. Mevcut teknik akıştaki 30 günlük bekleme süresi devam edecekse, talep ekranında kullanıcıya önceden açıkça bildirilmelidir.

Silme; hesap kaydı, ilişkili kişisel veriler, kullanıcı içerikleri, dosyalar, oturumlar ve üçüncü taraf kopyaları için farklı teknik süreçler gerektirebilir. Kuyruklar, sağlayıcı yanıtı ve yedekleme döngüleri nedeniyle tüm kopyaların aynı anda silinmesi garanti edilemez. Kanunen tutulması gereken veya belirli bir hakkın korunması için gerçekten gerekli veriler, amaç ve gerekli süreyle sınırlı saklanabilir; mümkün olduğunda kişisel alanlar maskelenir veya anonimleştirilir.

YAYIN ÖNCESİ TAMAMLANACAK: Denetim kayıtları, hesap durumu geçmişi, onay kayıtları, silme talepleri, anonim iş verileri, günlükler ve yedekler için saklama gerekçesi, süre ve imha yöntemi belirlenmelidir. Kesin süreler belirlenmeden belirli bir sürede tüm kopyaların silineceği vaat edilmemelidir.

## 10. Yaş sınırı

HizmetCep üyeliği 18 yaşını doldurmuş kişilerle sınırlıdır. Kayıt sırasında bu yönde beyan alınır. Doğum tarihi, hizmet için gerekli olmadığı sürece istenmez. Gerçeğe aykırı beyan tespit edilirse somut durum ve mevzuat dikkate alınarak hesap hakkında işlem yapılabilir.

## 11. İlgili kişi hakları ve başvuru

İlgili kişiler 6698 sayılı Kanun''un 11. maddesindeki hakları için onur_butun@hotmail.com adresine başvurabilir. Başvurular mevzuattaki usul ve sürelerde değerlendirilir; gerekli kimlik doğrulaması yapılabilir. Başvuru kanalları ve usulü yayımdan önce doğrulanmalıdır.

## 12. Güncellemeler

Hizmet veya mevzuat değişikliklerinde politika güncellenebilir. Önemli değişiklikler kullanıcıya uygun yöntemle bildirilir; gerektiğinde yeniden onay veya ayrı açık rıza alınır. Güncel sürüm ve yürürlük tarihi gösterilmelidir.',
       'd90bdf13499e41c4c32771f0223dd68e30501cc96df4460dae7b98211539b116', '2026-10-23', 'PUBLISHED', NULL, '2026-10-23T12:30:00.000Z', NULL, '2026-10-23T12:30:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'privacy')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c001')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'privacy' AND status = 'PUBLISHED');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'terms' AND status = 'PUBLISHED' AND sha256 = '4343d06fb46bf8fe93d49f79b0f6aaa313fb67f81b13faff76d9e6661cd19e4d'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c002');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026c002', 'terms',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'terms'),
       '## 1. Taraflar ve tanımlar

İşbu Kullanım Sözleşmesi (“Sözleşme”), HizmetCep isimli dijital platformu işleten Onur Bütün (“İşletmeci”) ile HizmetCep’e kayıt olan veya platformu kullanan gerçek kişi (“Kullanıcı”) arasında, Kullanıcı’nın elektronik ortamda Sözleşme’yi kabul etmesiyle yürürlüğe girer.

İşletmeci iletişim bilgileri: Onur Bütün. E-posta: onur_butun@hotmail.com.

“Platform”; HizmetCep mobil uygulamasını, web arayüzünü ve bunlarla bağlantılı kullanıcı ekranlarını ifade eder. “Hizmet Alan”; platform üzerinden hizmet arayan, talep veya ilan oluşturan kullanıcıdır. “Hizmet Veren”; profil oluşturan, hizmet sunmayı tanıtan veya taleplere teklif veren kullanıcıdır. Bir kullanıcı, platformun izin verdiği ölçüde her iki rolde de işlem yapabilir.

## 2. Sözleşmenin konusu ve kapsamı

Bu Sözleşme; hesap oluşturma ve kullanma, kullanıcı profilleri, ilanlar ve hizmet talepleri, teklif süreçleri, kullanıcılar arası iletişim, kullanıcı içerikleri, güvenlik, şikâyetler, hesap kısıtlamaları ve üyeliğin sona ermesine ilişkin temel şartları düzenler.

HizmetCep’in ilk kullanım ve test aşaması İzmir odaklı olabilir; erişim test kullanıcılarıyla sınırlandırılabilir. Bölge, özellik ve erişim kapsamı uygulamada ayrıca duyurulabilir. Platformun test sürümünde bulunması, yürürlükteki emredici mevzuatın uygulanmasını ortadan kaldırmaz.

## 3. Platformun niteliği ve İşletmecinin rolü

HizmetCep, hizmet almak isteyen kişiler ile hizmet sunmak isteyen kişileri dijital ortamda buluşturmayı amaçlayan bir platformdur. İşletmeci, uygulamada açıkça ayrıca sunulduğu belirtilmedikçe kullanıcılar arasındaki işi bizzat yapan hizmet sağlayıcı, işveren, yüklenici veya hizmet sözleşmesinin tarafı değildir.

Hizmetin kapsamı, fiyatı, zamanı, ödeme şekli, malzeme giderleri, teslim, iptal, garanti, ayıp, yeniden iş yapma ve diğer ticari koşullar, ilgili kullanıcılar arasında kararlaştırılır. Kullanıcılar anlaşmalarını ve önemli koşulları işlem öncesinde açıkça belirlemelidir.

Bir profilin, yorumun, teklifin veya ilanın platformda bulunması; kişinin kimliğinin, mesleki yeterliliğinin, ruhsatının, sigortasının, referanslarının, güvenilirliğinin veya hizmet kalitesinin İşletmeci tarafından kesin olarak doğrulandığı anlamına gelmez. Platformda belirli bir doğrulama yapılıyorsa yalnızca kapsamı açıkça belirtilen doğrulama esas alınır.

Bu maddeler, İşletmecinin kendi kusurundan, kanundan doğan yükümlülüklerinden veya emredici mevzuat uyarınca sorumlu olduğu durumlardan kaynaklanan sorumluluğunu ortadan kaldıracak şekilde yorumlanamaz.

## 4. Üyelik şartları ve yaş koşulu

HizmetCep’e üye olabilmek ve platformu bağımsız olarak kullanabilmek için Kullanıcı’nın 18 yaşını doldurmuş olması gerekir. Kullanıcı, Sözleşme’yi elektronik ortamda kabul ederek 18 yaşını doldurduğunu ve verdiği bilgilerin doğru olduğunu beyan eder.

Bu yaş koşulu sözleşme hükmüdür; uygulamada ayrıca bir “18 yaşındayım” onay kutusu bulunması şartı olarak tasarlanmamıştır. Sözleşmenin kabulü kayıt sırasında ayrı ve ispatlanabilir şekilde kaydedilmelidir. Bu hüküm tek başına kişinin yaşını teknik olarak doğruladığı anlamına gelmez.

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

İşletmeci, uygulamada açıkça ödeme, emanet, sigorta, garanti veya uyuşmazlık çözüm hizmeti sunduğunu belirtmedikçe bu hizmetleri sunduğu varsayılamaz. Platformda bulunmayan bir koruma veya garanti varmış gibi hareket edilmemelidir.

Kullanıcılar arası uyuşmazlıklarda İşletmeci, elindeki ilgili kayıtları hukuka uygun ve gerekli olduğu ölçüde inceleyebilir; ancak uyuşmazlığın tarafı olmadığı durumlarda her uyuşmazlığı çözmeyi veya zararı karşılamayı taahhüt etmez. Kanuni başvuru ve tüketici hakları saklıdır.

## 10. Mesajlar, denetim ve şikâyetler

Platform içi mesajlaşma özelliği kullanılıyorsa mesajlar, hizmetin sunulması ve kullanıcılar arası iletişim için işlenebilir. Kullanıcılar mesajlarda tehdit, taciz, dolandırıcılık, hukuka aykırı içerik veya izinsiz kişisel veri paylaşımı yapamaz.

Yetkili personelin mesajlara erişimi, yalnızca şikâyet incelemesi, güvenlik, kötüye kullanımın önlenmesi, teknik destek veya hukuki yükümlülük gibi meşru ve belirli amaçlarla, gerekli olduğu ölçüde ve yetki sınırları içinde gerçekleştirilmelidir. Gerçek erişim yetkileri uygulamanın teknik yapısıyla uyumlu olmalıdır.

Şikâyetler uygulamada sunulan bildirim kanalı veya onur_butun@hotmail.com adresi üzerinden iletilebilir. İşletmeci, başvuruyu değerlendirmek için gerekli açıklama ve kanıtları ölçülü şekilde isteyebilir.

## 11. Ücretler, ödeme ve tanıtımlar

HizmetCep’in mevcut test sürümü ücretsiz olarak sunulmaktadır. Ücretsiz sunum, gelecekte ücretli özelliklerin eklenmeyeceği yönünde taahhüt değildir.

İleride üyelik, ilan, teklif, reklam veya başka bir özellik için ücret uygulanacaksa, uygulanabilir mevzuatın gerektirdiği bilgilendirme ve onay süreçleri tamamlanmadan Kullanıcı’dan ücret talep edilmez. Ücretli bir özellik varsa ücret, kapsam, tahsilat ve iptal koşulları işlem öncesinde açıkça gösterilir.

Test sürümünde pazarlama amaçlı ticari elektronik ileti gönderilmesi planlanmıyorsa, bu amaçla veri kullanılmamalıdır. Gelecekte ticari elektronik ileti gönderilecekse gerekli izinler ve ret mekanizmaları, üyelik sözleşmesinden ayrı ve mevzuata uygun biçimde yönetilir.

## 12. İçeriğin kaldırılması ve hesap kısıtlamaları

İşletmeci; güvenlik riski, hukuka aykırılık, sahtecilik, kötüye kullanım, hak ihlali veya Sözleşme’nin ihlali hakkında makul gerekçe bulunduğunda, olayın ağırlığına göre içerik görünürlüğünü sınırlayabilir, içeriği kaldırabilir, kullanıcıdan açıklama isteyebilir veya hesabı geçici olarak kısıtlayabilir ya da sonlandırabilir.

Acil güvenlik veya hukuki zorunluluk bulunan hâller dışında tedbirler mümkün olduğu ölçüde gerekçeli ve orantılı olmalıdır. Kullanıcı, uygulanan tedbir hakkında açıklama isteyebilir ve kanuni başvuru yollarını kullanabilir.

İşletmeci, kanunen zorunlu bildirimleri yapabilir ve hukuka uygun talepler üzerine yetkili kamu kurumlarıyla iş birliği yapabilir.

## 13. Hizmetin kullanılabilirliği, bakım ve değişiklikler

Platformun kesintisiz, hatasız veya her cihazda aynı şekilde çalışacağı garanti edilmez. Bakım, güncelleme, ağ sorunları, üçüncü taraf hizmetlerdeki arızalar veya kontrol dışındaki olaylar geçici kesintilere neden olabilir.

İşletmeci; güvenlik, mevzuata uyum, ürün geliştirme veya operasyonel gereklilikler nedeniyle özellikleri değiştirebilir, durdurabilir veya yenilerini ekleyebilir. Kullanıcıların kanundan doğan hakları saklıdır. Esaslı değişikliklerde, gerektiğinde güncellenmiş koşullar kullanıcıya sunulur ve gerekli kabul alınır.

## 14. Kişisel veriler ve gizlilik

Kişisel verilerin işlenmesi; 6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) ve ilgili mevzuat çerçevesinde, ayrıca erişilebilir olması gereken Aydınlatma Metni ve Gizlilik Politikası’nda açıklanan amaçlar, hukuki sebepler, veri kategorileri, alıcı grupları ve saklama süreleri doğrultusunda yürütülür.

Bu Sözleşme’nin kabul edilmesi, gerekli olduğu durumlarda açık rıza yerine geçmez. Açık rıza gereken işlemler, üyelik veya temel hizmetin şartı hâline getirilmeden ayrı ve özgür iradeye dayalı şekilde düzenlenir. Kişisel verilerin yurt dışına aktarılması, gerçek veri akışı ve KVKK’nın yürürlükteki aktarım hükümleri esas alınarak ayrıca değerlendirilir.

Firebase, Render, Cloudflare R2/S3 veya başka bir hizmet sağlayıcı, ancak fiilen kullanıldığı ve veri akışında yer aldığı ölçüde dikkate alınır. Sağlayıcı, veri bölgesi, alt işleyen, erişim ve aktarım koşulları doğrulanmadan belirli bir sağlayıcıya veri aktarıldığı veya aktarımın hukuken tamamlandığı beyan edilmez.

İşletmeci, hukuki yükümlülükleri çerçevesinde uygun teknik ve idari tedbirleri almayı hedefler. Hiçbir sistem için mutlak güvenlik garantisi verilmez.

## 15. Hesap kapatma, silme ve saklama

Kullanıcı, uygulamada sunulan hesap silme işlevi veya onur_butun@hotmail.com adresi üzerinden hesap silme talebinde bulunabilir. Talebin hesap sahibinden geldiğini doğrulamak için gerekli ve ölçülü ek doğrulama istenebilir.

Silme talebi; hesap ve profil kayıtları, ilanlar/talepler, teklifler, mesajlar ve ekleri, fotoğraflar/dosyalar, bildirim belirteçleri ve ilişkili diğer kayıtlar bakımından, gerçek veri mimarisi ve uygulanabilir mevzuat çerçevesinde değerlendirilir; uygun olduğu ölçüde silme, yok etme veya anonimleştirme yapılır.

Kanunen saklanması gereken veya bir hakkın tesisi, kullanılması ya da korunması için gerekli sınırlı kayıtlar, gerekli amaç ve süreyle saklanabilir. Yedeklerde veya üçüncü taraf sistemlerde bulunan kopyaların silinme süresi, gerçek yedekleme ve saklama düzenine göre belirlenir; tüm kopyaların talep anında derhal silindiği yönünde doğrulanmamış taahhüt verilmez.

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

Kullanıcı, destek, şikâyet, içerik ihlali ve hesap silme taleplerini uygulamada sunulan kanallar veya onur_butun@hotmail.com adresi üzerinden iletebilir. Başvuruda konu ve talep açıkça belirtilmelidir.

Elektronik bildirimlerin hukuki sonuç doğuracağı durumlarda yürürlükteki mevzuatın öngördüğü şekil ve ispat kuralları saklıdır.

## 20. Uygulanacak hukuk ve uyuşmazlıklar

Bu Sözleşme Türkiye Cumhuriyeti hukukuna tabidir. Uyuşmazlıklarda görevli ve yetkili mahkemeler ile tüketici hakem heyetleri, uygulanabilir mevzuata göre belirlenir. Tüketicinin kanunen sahip olduğu başvuru yolları ve yetkiler bu Sözleşme ile sınırlandırılamaz.

## 21. Son hükümler ve elektronik kabul

Kullanıcı, kayıt sırasında Sözleşme’nin erişilebilir bağlantısını açabilmeli ve kabul ettiği metnin sürümü kayıt altına alınmalıdır. Kabul kaydı, uygulanabilir mevzuat ve veri minimizasyonu ilkesi gözetilerek tarih-saat, sözleşme sürümü ve gerekli teknik kayıtları içerebilir.

Sözleşme’nin bir hükmünün geçersiz veya uygulanamaz olması, diğer hükümlerin geçerliliğini kendiliğinden ortadan kaldırmaz; ilgili hüküm emredici mevzuata uygun şekilde değerlendirilir.

Kullanıcı, “Kullanım Sözleşmesi’ni okudum ve kabul ediyorum” şeklindeki ayrı sözleşme kabul işlemini tamamlayarak bu metni elektronik ortamda kabul eder. Bu kabul; KVKK Aydınlatma Metni’nin okunduğuna dair bilgilendirme, gerekli açık rızalar veya ticari elektronik ileti izinleriyle aynı işlem olarak değerlendirilmez.',
       '2351068b785c01835841cfc5eb897e5449aa6531ac851094cdb13e6cb5ff78e3', '2026-10-23', 'PUBLISHED', NULL, '2026-10-23T12:30:00.000Z', NULL, '2026-10-23T12:30:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c002')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'terms' AND status = 'PUBLISHED');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'kvkk' AND status = 'PUBLISHED' AND sha256 = 'c295c1bf218d25ea5faeae1330d29d0bd8a83887570a289699232d8a1eb94010'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c003');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026c003', 'kvkk',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'kvkk'),
       'Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) kapsamında HizmetCep kullanıcılarını kişisel verilerinin işlenmesi hakkında bilgilendirmek amacıyla hazırlanmıştır. Yayımdan önce fiilî veri işleme süreçleriyle karşılaştırılmalıdır.

## 1. Veri Sorumlusu ve İletişim Bilgileri

Veri sorumlusu: Onur Bütün
E-posta: onur_butun@hotmail.com

## 2. İşlenebilecek Kişisel Veri Kategorileri

HizmetCep’in fiilî işleyişine ve kullanılan özelliklere bağlı olarak ad, soyad, hesap bilgileri, telefon numarası, e-posta adresi, profil ve hizmet bilgileri, il/ilçe/mahalle gibi hizmet bölgesi bilgileri, ilanlar, hizmet talepleri, teklifler, uygulama içi iletişim içerikleri, bildirim bilgileri, doğrulama ve hesap güvenliği kayıtları ile IP adresi, cihaz ve bağlantı kayıtları gibi teknik veriler işlenebilir. Yalnızca fiilen toplanan ve işlenen veri kategorileri bu kapsamda tutulmalıdır.

## 3. İşleme Amaçları

Veriler; hesap oluşturma ve yönetme, telefon/hesap doğrulama, hizmet alanlarla hizmet verenleri buluşturma, profil ve hizmet bilgilerini gösterme, ilan/talep/teklif süreçlerini yürütme, destek taleplerini karşılama, güvenliği sağlama ve kötüye kullanımı önleme, teknik sorunları giderme, hukuki yükümlülükleri yerine getirme ve hakların tesisi, kullanılması veya korunması amaçlarıyla işlenebilir. Fiilen sunulmayan özelliklere ilişkin amaçlar çıkarılmalıdır.

## 4. Hukuki Sebepler

Her işleme faaliyeti bakımından geçerli olduğu ölçüde KVKK’nın 5. maddesindeki hukuki sebepler uygulanır. Bunlar sözleşmenin kurulması veya ifasıyla doğrudan ilgili olma, hukuki yükümlülüğün yerine getirilmesi, bir hakkın tesisi/kullanılması/korunması ve temel hak ve özgürlüklere zarar vermemek kaydıyla meşru menfaat gibi sebepleri içerebilir. Her veri kategorisi ve amaç için doğru hukuki sebep ayrıca doğrulanmalıdır.

## 5. Aktarım Yapılabilecek Taraflar

Profil, ilan, talep veya teklif bilgilerinin gerekli bölümleri diğer HizmetCep kullanıcılarına gösterilebilir. Teknik barındırma, doğrulama, bildirim veya destek sağlayıcılarına aktarım yalnızca ilgili hizmetler gerçekten kullanılıyorsa ve veri akışı mevcutsa söz konusu olur. Kanunen yetkili kamu kurum ve kuruluşlarına, yasal şartlar oluştuğunda aktarım yapılabilir. Yurt dışına veri aktarımı varsa fiilî kapsam ve KVKK’daki geçerli aktarım şartları ayrıca belirlenmelidir.

## 6. Toplama Yöntemi

Veriler; mobil uygulama, web arayüzü, kullanıcıların doldurduğu alanlar, uygulama içi işlemler, doğrulama süreçleri ve sistem/bağlantı kayıtları üzerinden, kullanılan özelliklere bağlı olarak elektronik ortamda toplanabilir.

## 7. Saklama Süresi ve İmha

Veriler, işleme amaçları için gerekli süre boyunca ve ilgili mevzuattaki saklama süreleriyle sınırlı olarak tutulur. İşleme sebebi ortadan kalktığında ve başka bir hukuki saklama nedeni bulunmadığında, mevzuata uygun şekilde silme, yok etme veya anonimleştirme uygulanır. Kesin süreler gerçek veri envanteri ve yasal yükümlülüklere göre belirlenmelidir.

## 8. KVKK Kapsamındaki Haklarınız

KVKK’nın 11. maddesi kapsamında; verilerinizin işlenip işlenmediğini öğrenme, işlenmişse bilgi talep etme, amaçlarını ve amaca uygun kullanımı öğrenme, aktarım yapılan üçüncü kişileri bilme, eksik veya yanlış verilerin düzeltilmesini isteme, kanuni şartlarla silme/yok etme talep etme, bu işlemlerin üçüncü kişilere bildirilmesini isteme, münhasıran otomatik analiz sonucu aleyhinize çıkan sonuca itiraz etme ve kanuna aykırı işleme nedeniyle zararınız varsa giderilmesini talep etme haklarına sahipsiniz.

## 9. Başvuru Yöntemi

KVKK kapsamındaki taleplerinizi kimliğinizi ve talebinizi değerlendirmeye yetecek bilgileri içerecek şekilde onur_butun@hotmail.com adresine iletebilirsiniz. Başvurular KVKK ve ilgili mevzuattaki usul ve süreler çerçevesinde değerlendirilir.

## 10. Güncellemeler

HizmetCep’in özellikleri, veri işleme faaliyetleri veya mevzuat değişiklikleri nedeniyle bu metin güncellenebilir. Güncel metin uygulama veya web arayüzünde erişilebilir şekilde yayımlanmalıdır.',
       'c28d43712e2f8f30613388acf9ea76cad6fc3f6aa5e0e7c701420bc85c112ac9', '2026-10-23', 'PUBLISHED', NULL, '2026-10-23T12:30:00.000Z', NULL, '2026-10-23T12:30:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'kvkk')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c003')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'kvkk' AND status = 'PUBLISHED');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'cookies' AND status = 'PUBLISHED' AND sha256 = 'cad9f1203f397f2cb2f77d8f5c3658175fd0d89aea472f06fbca4fdb2e990891'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c004');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026c004', 'cookies',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'cookies'),
       'Bu Çerez Politikası, HizmetCep web sitesini ve web uygulamasını kullanırken tarayıcınızda saklanan çerezler ve benzeri teknolojiler (tarayıcı deposu) hakkında 6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında sizi bilgilendirmek amacıyla hazırlanmıştır.

## 1. Veri Sorumlusu

Veri sorumlusu: Onur Bütün
E-posta: onur_butun@hotmail.com

## 2. Çerez ve Tarayıcı Deposu Nedir?

Çerez, ziyaret ettiğiniz internet sitesinin tarayıcınıza kaydettiği küçük bir metin dosyasıdır. Tarayıcı deposu (local storage / session storage) da benzer şekilde tarayıcınızda küçük bilgiler saklar.

## 3. HizmetCep''in Kullandığı Çerezler ve Depolar

HizmetCep yalnızca hizmetin çalışması ve hesabınızın güvenliği için zorunlu olan çerez ve depoları kullanır. Reklam, pazarlama, profil çıkarma veya üçüncü taraf analiz çerezi KULLANILMAZ.

Oturum çerezi (hc_rt): Giriş yaptığınızda oluşturulur. Oturumunuzun güvenli biçimde sürmesini sağlar; JavaScript tarafından okunamaz (HttpOnly), yalnızca güvenli bağlantıda gönderilir. Süresi en fazla 30 gündür; çıkış yaptığınızda silinir.

Oturum izi (hc.oturumIzi): Bu tarayıcıda açık bir oturum bulunduğunu hatırlar; yalnızca "var / yok" bilgisi tutar, kimlik veya şifre içermez. Çıkış yaptığınızda sıfırlanır.

Cihaz kimliği (hc.cihazKimligi): Giriş yaptığınızda tarayıcı için rastgele üretilen bir numaradır. Hesap güvenliği ve yetkili hesapların bakım çalışmaları sırasında erişimi için kullanılır. IMEI, telefon numarası, reklam kimliği gibi donanım veya kişisel bilgi içermez.

Giriş tercihi (oturum_hatirla, oturum_telefon): Bir sonraki girişte telefon numaranızın hazır gelmesi için kullanılır. Çıkış yaptığınızda silinir.

Taslak ilan (hc.pendingListing): Üye olmadan ilan oluşturmaya başladığınızda, kayıt veya giriş sırasında ilanınızın kaybolmaması için geçici olarak saklanır. İlan yayımlandığında silinir.

İncelenen ilanlar (hc.incelenenIlanlar): Hizmet verenlerin daha önce açtığı ilanları listede ayırt edebilmesi için ilan numaralarını tutar.

Sekme bilgileri (sessionStorage): Sayfa yenilendiğinde açık ekranın korunması için kullanılır; sekme kapatıldığında tarayıcı tarafından silinir.

Bildirim kaydı (yalnız tarayıcı bildirimlerine izin verirseniz): Size uygulama bildirimi gönderilebilmesi için Google Firebase Cloud Messaging hizmeti, tarayıcınızın veritabanında (IndexedDB) bir bildirim jetonu ve kurulum kimliği saklar ve bunun için bir servis çalışanı (service worker) kaydeder. Bildirim iznini tarayıcı ayarlarından istediğiniz zaman kaldırabilirsiniz.

Uygulama dosyaları: Web uygulamasının daha hızlı açılması için uygulama dosyaları tarayıcı önbelleğinde tutulur; bu dosyalar kişisel veri içermez.

## 4. Hukuki Sebep

Bu çerez ve depolar, hizmetin sunulması ve güvenliğinin sağlanması için zorunlu olduğundan KVKK''nın 5. maddesinin 2. fıkrasının (c) bendi (sözleşmenin kurulması ve ifası) ve (f) bendi (meşru menfaat) kapsamında işlenir; bu nedenle açık rızanız istenmez.

## 5. Çerezleri Nasıl Yönetebilirsiniz?

Tarayıcınızın ayarlarından çerezleri ve site verilerini silebilir veya engelleyebilirsiniz. Zorunlu çerezleri engellerseniz giriş yapamayabilir veya oturumunuz sürmeyebilir.

## 6. Haklarınız

KVKK''nın 11. maddesindeki haklarınıza ilişkin taleplerinizi onur_butun@hotmail.com adresine iletebilirsiniz. Ayrıntılı bilgi için Aydınlatma Metni''ni inceleyebilirsiniz.

## 7. Güncellemeler

Kullanılan çerez veya depolarda değişiklik olursa bu politika güncellenir ve güncel sürüm web sitesinde yayımlanır.',
       '877ea68b9b87a5e82d59396c2ff608d2d900a15f08a6eed2fdb149caacf41936', '2026-10-23', 'PUBLISHED', NULL, '2026-10-23T12:30:00.000Z', NULL, '2026-10-23T12:30:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'cookies')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026c004')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'cookies' AND status = 'PUBLISHED');
