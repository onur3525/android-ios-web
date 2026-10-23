-- 034 — YASAL METİNLER: TEMİZLENMİŞ TASLAK SÜRÜMLER (23 Eki, kullanıcı: "yapabileceklerin hepsini yap").
--
-- KVKK takip denetimi B1/E6: yayımdaki metinlerde editör notları ("YAYIN
-- ENGELİ", "yayımdan önce doğrulanmalı" vb.) ve tutarsız başvuru adresi
-- (hotmail / destek@hizmetcep.com) vardı. Bu göç, notları çıkarılmış ve
-- koddan DOĞRULANAN gerçeklerle (toplanan veriler, sağlayıcılar, silme
-- akışı, iletişim paylaşım kuralı, teknik saklama süreleri) yazılmış
-- metinleri TASLAK (DRAFT) olarak ekler. Başvuru adresi tek: destek@hizmetcep.com.
--
-- ⚠ HİÇBİR ŞEY YAYIMLANMAZ: yayımdaki sürümlere dokunulmaz, kullanıcıdan
-- yeniden onay istenmez. Hukukçu kontrolünden sonra Yasal sayfasından
-- yayımlanır. Koddan doğrulanamayan yerler ⟦DOĞRULANACAK: …⟧ ile işaretlidir
-- ve doldurulmadan yayımlanamaz (admin.js yayın kapısı reddeder).
-- ⚠ Yalnız belge varsa ve bu taslak daha önce eklenmediyse (sabit kimlik).


INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026b001', 'privacy',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'privacy'),
       '## 1. Veri sorumlusu

HizmetCep''in işletmecisi ve kişisel veriler bakımından veri sorumlusu Onur Bütün''dür.
Adres: 1847/2 Sokak, No: 25, Daire: 1, Örnekköy, Karşıyaka / İzmir.
E-posta: destek@hizmetcep.com

## 2. İşlenen kişisel veriler

- Hesap ve iletişim: ad-soyad, telefon numarası, e-posta adresi, şifre (yalnızca geri döndürülemez özeti saklanır), kullanıcı rolleri (hizmet alan / hizmet veren).
- Adres ve hizmet bölgesi: il, ilçe ve mahalle; hizmet verenler için hizmet kategorileri ve hizmet verilen ilçeler.
- Hizmet içerikleri: ilanlar (hizmet adı, konum açıklaması, açıklama, fotoğraflar, iş zamanı, iletişim tercihi), teklifler (tutar ve not), teklif talepleri, uygulama içi mesajlar ve mesajlardaki fotoğraflar, yorumlar ve puanlar, profil fotoğrafı.
- Destek: uygulamadan veya e-postayla iletilen destek talepleri ve yazışmalar, uygulama geri bildirimleri.
- Hesap ve onay kayıtları: Kullanım Sözleşmesi''nin kabul edilen sürümü, tarih-saat ve platform bilgisi; hesap dondurma ve silme talepleri; hesap durumu değişiklikleri.
- Teknik ve güvenlik: oturum kayıtları (IP adresi ve tarayıcı/cihaz bilgisi), doğrulama kodu kayıtları, bildirim (push) jetonu, bildirim tercihleri, yönetici işlem kayıtları, sunucu hata kayıtları (kişisel veri içermeyecek şekilde).

HizmetCep GPS veya arka planda konum takibi yapmaz. Yüklenen fotoğraflardaki konum ve cihaz bilgisi (EXIF/GPS meta verisi) yüklemeden önce uygulama tarafından silinir.

## 3. İşleme amaçları

- Üyelik oluşturmak ve yönetmek; telefon ve e-posta doğrulamasını yapmak.
- İlan, teklif, teklif talebi, mesajlaşma, yorum ve profil özelliklerini sunmak.
- Kullanıcının seçimine göre iletişim bilgisini ilgili kullanıcıyla paylaşmak.
- Hesap güvenliğini sağlamak, kötüye kullanımı önlemek, hataları gidermek ve sistemi işletmek.
- Destek taleplerini ve şikâyetleri değerlendirmek; hesap dondurma ve silme taleplerini yürütmek.
- Mevzuattan doğan yükümlülükleri yerine getirmek ve hukuki hakları korumak.

## 4. Hukuki sebepler

⟦DOĞRULANACAK: Hukukçu onayı — her işleme faaliyeti için 6698 sayılı Kanun m.5''teki hukuki sebep (sözleşmenin kurulması/ifası, hukuki yükümlülük, hakkın tesisi/kullanılması/korunması, meşru menfaat) tek tek belirlenmelidir.⟧

Kullanım Sözleşmesi''nin kabulü açık rıza yerine geçmez. HizmetCep''in mevcut işleyişinde açık rızaya dayanan bir işleme faaliyeti bulunmamaktadır; ileride gerekirse ayrı ve isteğe bağlı olarak alınır.

## 5. Kişisel verilerin aktarıldığı taraflar

- Diğer kullanıcılar: hizmet akışı için gerekli profil, ilan, teklif ve talep bilgileri ile kullanıcının seçimine göre paylaşılan iletişim bilgisi (bkz. madde 7).
- Hizmet sağlayıcılar (veri işleyenler):
  - Google LLC — Firebase Authentication (telefon doğrulama kodu SMS''lerinin gönderimi, e-posta doğrulaması, giriş) ve Firebase Cloud Messaging (bildirim gönderimi).
  - Apple Inc. — iOS cihazlara bildirim iletimi (Apple Push Notification service, Firebase üzerinden).
  - Render Services, Inc. — uygulama sunucusu ve veritabanı barındırma.
  - Resend — e-posta gönderimi ve destek adresine gelen e-postaların alınması.
  - ⟦DOĞRULANACAK: Dosya depolama sağlayıcısının adı (ör. Cloudflare R2)⟧ — fotoğrafların saklanması.
  - GitHub, Inc. — web sitesinin barındırılması (ziyaretçinin IP adresi ve tarayıcı bilgisi).
- Yetkili kamu kurum ve kuruluşları ile adli merciler: geçerli bir hukuki talep veya kanuni yükümlülük olduğunda.
- Gerektiği ölçüde hukuk ve mali müşavirlik gibi profesyonel danışmanlar.

## 6. Yurt dışına aktarım

Yukarıdaki hizmet sağlayıcıların bir kısmı verileri Türkiye dışında işler. Bu aktarımlar 6698 sayılı Kanun''un 9. maddesine uygun olarak yapılır.

⟦DOĞRULANACAK: Her sağlayıcı için verinin işlendiği ülke/bölge ve kullanılan aktarım mekanizması (ör. Kurul''a bildirilen standart sözleşme) yazılmalıdır.⟧

## 7. İletişim bilgilerinin paylaşılması

Telefon numarası herkese açık profil bilgisi değildir.

- İlan akışında: Hizmet alan ile teklif veren hizmet veren arasında iletişim açıldığında, hizmet verenin telefonu hizmet alana gösterilir. Hizmet alanın telefonu yalnızca ilanda "Telefonumu göster" seçildiyse hizmet verene gösterilir; "Sadece uygulama içi mesaj" seçildiyse hiçbir ekranda paylaşılmaz.
- Teklif talebi akışında: Hizmet veren teklif verdikten sonra, talep süresi dolmadığı sürece iletişim açıktır. Hizmet alanın telefonu yalnızca "Telefonumu göster" seçildiyse paylaşılır.
- E-posta adresi diğer kullanıcılarla paylaşılmaz.

Kullanıcılar başkalarının iletişim bilgilerini izinsiz yayımlayamaz veya başka amaçla kullanamaz.

## 8. Yönetici erişimi ve güvenlik

Yöneticiler verilere yalnızca görevleri için gereken yetkiyle erişir. Uygulama içi mesajları görüntülemek için yöneticinin bir gerekçe girmesi zorunludur ve her erişim kayıt altına alınır.

Şifreler geri döndürülemez biçimde saklanır, bağlantılar şifrelidir (HTTPS). Hiçbir sistem için mutlak güvenlik garantisi verilmez.

## 9. Saklama, hesap dondurma ve hesap silme

**Hesap dondurma:** Kullanıcı hesabını uygulamadan dondurabilir. Dondurulan hesap aramada görünmez, bildirim almaz; veriler silinmez. Yeniden giriş yapıldığında hesap etkinleşir.

**Hesap silme:** Kullanıcı uygulamadan, şifresini girerek silme talebi oluşturur. Talep 30 gün sonra uygulanır ve bu süre içinde iptal edilebilir. Silme uygulandığında:

- ad, telefon, e-posta, şifre ve profil fotoğrafları kaldırılır;
- adres, hizmet profili, bildirim jetonları, oturum kayıtları, bildirimler ve doğrulama kodu kayıtları silinir;
- kullanıcının yazdığı mesaj, ilan açıklaması, teklif notu, talep ve yorum metinleri kaldırılır;
- yüklediği dosyalar depolamadan silinmek üzere sıraya alınır;
- kimlik doğrulama kaydı Firebase''den silinir.

Karşı tarafın kendi yazdığı mesajlar onun verisi olduğu için silinmez. Yorumların yıldız puanı, kişiyle ilişkilendirilemeyecek şekilde kalır.

Aşağıdaki kayıtlar, hukuki yükümlülük ve hakların korunması amacıyla, kişisel alanları maskelenerek saklanır:

- sözleşme onay kayıtları,
- yönetici işlem kayıtları,
- hesap durumu geçmişi.

**Saklama süreleri:**

- Doğrulama kodları 1 gün içinde silinir.
- Süresi dolan oturum kayıtları 30 gün sonra silinir.
- Sunucu hata kayıtları 30 gün sonra silinir.
- ⟦DOĞRULANACAK: Onay kayıtları, yönetici işlem kayıtları, gönderim kayıtları, destek talepleri, mesajlar ve yedekler için saklama süreleri.⟧

Yedeklerdeki kopyalar, yedekleme döngüsü tamamlandığında silinir. ⟦DOĞRULANACAK: Yedek saklama süresi.⟧

## 10. Yaş sınırı

HizmetCep üyeliği 18 yaşını doldurmuş kişilerle sınırlıdır. Kullanıcı, Kullanım Sözleşmesi''ni kabul ederek 18 yaşını doldurduğunu beyan eder. Doğum tarihi istenmez.

## 11. Çerezler

Web sitesinde yalnızca hizmetin çalışması ve hesap güvenliği için zorunlu çerez ve tarayıcı depoları kullanılır. Reklam, pazarlama veya analiz çerezi kullanılmaz. Ayrıntılar Çerez Politikası''ndadır.

## 12. İlgili kişi hakları ve başvuru

6698 sayılı Kanun''un 11. maddesindeki haklarınız için destek@hizmetcep.com adresine veya yukarıdaki posta adresine başvurabilirsiniz. Başvurular en geç 30 gün içinde ücretsiz olarak sonuçlandırılır; kimliğinizi doğrulamak için ek bilgi istenebilir.

## 13. Güncellemeler

Politika güncellendiğinde yeni sürüm, sürüm numarası ve yürürlük tarihiyle uygulamada ve web sitesinde yayımlanır.',
       '9272c48d59353dd087f9befd7c37a7a885a5fcfb4ebae19093da432dd288b315', '2026-10-23', 'DRAFT', NULL, '2026-10-23T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'privacy')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026b001');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026b002', 'kvkk',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'kvkk'),
       'Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu''nun ("KVKK") 10. maddesi uyarınca, HizmetCep kullanıcılarını kişisel verilerinin işlenmesi hakkında bilgilendirmek için hazırlanmıştır. Ayrıntılı bilgi Gizlilik Politikası''ndadır.

## 1. Veri sorumlusu

Veri sorumlusu: Onur Bütün
Adres: 1847/2 Sokak No: 25, Daire: 1, Örnekköy, Karşıyaka/İzmir
E-posta: destek@hizmetcep.com

## 2. İşlenen kişisel veri kategorileri

- **Kimlik ve iletişim:** ad-soyad, telefon numarası, e-posta adresi.
- **Hesap:** şifre özeti, kullanıcı rolleri, bildirim tercihleri, hesap durumu.
- **Adres ve hizmet bölgesi:** il, ilçe, mahalle; hizmet verenler için hizmet kategorileri ve ilçeler.
- **Hizmet içerikleri:** ilanlar, fotoğraflar, teklifler, teklif talepleri, uygulama içi mesajlar, yorumlar ve puanlar.
- **Destek:** destek talepleri, destek e-postaları ve uygulama geri bildirimleri.
- **Hukuki işlem:** Kullanım Sözleşmesi onay kayıtları; hesap dondurma ve silme talepleri.
- **İşlem güvenliği:** oturum kayıtları (IP adresi, tarayıcı/cihaz bilgisi), doğrulama kodu kayıtları, bildirim jetonu, yönetici işlem kayıtları.

## 3. İşleme amaçları

Kişisel verileriniz şu amaçlarla işlenir:

- üyeliğin oluşturulması ve yönetilmesi;
- telefon ve e-posta doğrulaması;
- hizmet alanlarla hizmet verenlerin buluşturulması;
- ilan, teklif, talep ve mesajlaşma süreçlerinin yürütülmesi;
- seçiminize göre iletişim bilgisinin karşı tarafla paylaşılması;
- bildirim gönderilmesi;
- destek taleplerinin karşılanması;
- hesap güvenliğinin sağlanması ve kötüye kullanımın önlenmesi;
- teknik sorunların giderilmesi;
- hukuki yükümlülüklerin yerine getirilmesi ve hakların korunması.

## 4. Toplama yöntemi ve hukuki sebep

Kişisel verileriniz mobil uygulama ve web sitesi üzerinden, doldurduğunuz alanlar, yaptığınız işlemler ve otomatik sistem kayıtlarıyla elektronik ortamda toplanır.

⟦DOĞRULANACAK: Hukukçu onayı — her kategori için KVKK m.5/2 kapsamındaki hukuki sebep (sözleşmenin kurulması veya ifası, hukuki yükümlülük, bir hakkın tesisi/kullanılması/korunması, meşru menfaat) belirlenmelidir.⟧

Bu metin bir bilgilendirmedir; açık rıza veya onay anlamına gelmez.

## 5. Aktarım

Kişisel verileriniz şu taraflara aktarılabilir:

- **Diğer kullanıcılar:** hizmetin gerektirdiği ölçüde ve seçiminize göre.
- **Hizmet sağlayıcılar:**
  - Google (Firebase: doğrulama kodu SMS''i, kimlik doğrulama ve bildirim)
  - Apple (iOS bildirim iletimi)
  - Render (sunucu ve veritabanı barındırma)
  - Resend (e-posta)
  - ⟦DOĞRULANACAK: dosya depolama sağlayıcısı⟧
  - GitHub (web sitesi barındırma)
- **Yetkili kamu kurum ve kuruluşları:** kanuni yükümlülük hâlinde.

Hizmet sağlayıcıların bir kısmı verileri yurt dışında işler. Bu aktarımlar KVKK''nın 9. maddesine uygun olarak yapılır. ⟦DOĞRULANACAK: Ülke/bölge ve aktarım mekanizması.⟧

## 6. Saklama süresi

Veriler, işleme amacının gerektirdiği süre ve mevzuattaki saklama süreleri boyunca tutulur; süre sonunda silinir, yok edilir veya anonim hâle getirilir. Hesap silme talebi 30 gün sonra uygulanır. Ayrıntılı süreler Gizlilik Politikası''ndadır.

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

Taleplerinizi kimliğinizi ve talebinizi değerlendirmeye yetecek bilgilerle birlikte iki yoldan iletebilirsiniz:

- destek@hizmetcep.com adresine e-postayla;
- yukarıdaki adrese yazılı olarak.

Başvurular en geç 30 gün içinde sonuçlandırılır.',
       '183db8618d774024ae33cc844e606143ef1dd37cf5271cda0bb94a757dfeb072', '2026-10-23', 'DRAFT', NULL, '2026-10-23T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'kvkk')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026b002');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026b003', 'terms',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'terms'),
       '## 1. Taraflar ve tanımlar

İşbu Kullanım Sözleşmesi (“Sözleşme”), HizmetCep isimli dijital platformu işleten Onur Bütün (“İşletmeci”) ile HizmetCep’e kayıt olan veya platformu kullanan gerçek kişi (“Kullanıcı”) arasında, Kullanıcı’nın elektronik ortamda Sözleşme’yi kabul etmesiyle yürürlüğe girer.

İşletmeci iletişim bilgileri: Onur Bütün, 1847/2 Sokak No: 25, Daire: 1, Örnekköy, Karşıyaka/İzmir. E-posta: destek@hizmetcep.com.

“Platform”; HizmetCep mobil uygulamasını, web arayüzünü ve bunlarla bağlantılı kullanıcı ekranlarını ifade eder. “Hizmet Alan”; platform üzerinden hizmet arayan, talep veya ilan oluşturan kullanıcıdır. “Hizmet Veren”; profil oluşturan, hizmet sunmayı tanıtan veya taleplere teklif veren kullanıcıdır. Bir kullanıcı, platformun izin verdiği ölçüde her iki rolde de işlem yapabilir.

## 2. Sözleşmenin konusu ve kapsamı

Bu Sözleşme; hesap oluşturma ve kullanma, kullanıcı profilleri, ilanlar ve hizmet talepleri, teklif süreçleri, kullanıcılar arası iletişim, kullanıcı içerikleri, güvenlik, şikâyetler, hesap kısıtlamaları ve üyeliğin sona ermesine ilişkin temel şartları düzenler.

HizmetCep başlangıçta İzmir''de hizmet vermektedir. Hizmet verilen bölgeler ve özellikler uygulamada gösterilir.

## 3. Platformun niteliği ve İşletmecinin rolü

HizmetCep, hizmet almak isteyen kişiler ile hizmet sunmak isteyen kişileri dijital ortamda buluşturmayı amaçlayan bir platformdur. İşletmeci, uygulamada açıkça ayrıca sunulduğu belirtilmedikçe kullanıcılar arasındaki işi bizzat yapan hizmet sağlayıcı, işveren, yüklenici veya hizmet sözleşmesinin tarafı değildir.

Hizmetin kapsamı, fiyatı, zamanı, ödeme şekli, malzeme giderleri, teslim, iptal, garanti, ayıp, yeniden iş yapma ve diğer ticari koşullar, ilgili kullanıcılar arasında kararlaştırılır. Kullanıcılar anlaşmalarını ve önemli koşulları işlem öncesinde açıkça belirlemelidir.

Bir profilin, yorumun, teklifin veya ilanın platformda bulunması; kişinin kimliğinin, mesleki yeterliliğinin, ruhsatının, sigortasının, referanslarının, güvenilirliğinin veya hizmet kalitesinin İşletmeci tarafından kesin olarak doğrulandığı anlamına gelmez. Platformda belirli bir doğrulama yapılıyorsa yalnızca kapsamı açıkça belirtilen doğrulama esas alınır.

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

İşletmeci, uygulamada açıkça ödeme, emanet, sigorta, garanti veya uyuşmazlık çözüm hizmeti sunduğunu belirtmedikçe bu hizmetleri sunduğu varsayılamaz. Platformda bulunmayan bir koruma veya garanti varmış gibi hareket edilmemelidir.

Kullanıcılar arası uyuşmazlıklarda İşletmeci, elindeki ilgili kayıtları hukuka uygun ve gerekli olduğu ölçüde inceleyebilir; ancak uyuşmazlığın tarafı olmadığı durumlarda her uyuşmazlığı çözmeyi veya zararı karşılamayı taahhüt etmez. Kanuni başvuru ve tüketici hakları saklıdır.

## 10. Mesajlar, denetim ve şikâyetler

Platform içi mesajlaşma özelliği kullanılıyorsa mesajlar, hizmetin sunulması ve kullanıcılar arası iletişim için işlenebilir. Kullanıcılar mesajlarda tehdit, taciz, dolandırıcılık, hukuka aykırı içerik veya izinsiz kişisel veri paylaşımı yapamaz.

Yetkili personel mesajlara yalnızca şikâyet incelemesi, güvenlik, kötüye kullanımın önlenmesi, teknik destek veya hukuki yükümlülük amacıyla erişebilir. Her erişim için gerekçe girilmesi zorunludur ve erişim kayıt altına alınır.

Şikâyetler uygulamadaki Destek Merkezi''nden veya destek@hizmetcep.com adresinden iletilebilir. İşletmeci, başvuruyu değerlendirmek için gerekli açıklama ve kanıtları ölçülü şekilde isteyebilir.

## 11. Ücretler, ödeme ve tanıtımlar

HizmetCep şu anda ücretsiz olarak sunulmaktadır. Bu, gelecekte ücretli özellik eklenmeyeceği anlamına gelmez.

İleride üyelik, ilan, teklif, reklam veya başka bir özellik için ücret uygulanacaksa, uygulanabilir mevzuatın gerektirdiği bilgilendirme ve onay süreçleri tamamlanmadan Kullanıcı’dan ücret talep edilmez. Ücretli bir özellik varsa ücret, kapsam, tahsilat ve iptal koşulları işlem öncesinde açıkça gösterilir.

HizmetCep pazarlama amaçlı ticari elektronik ileti göndermez. Uygulamanın gönderdiği SMS, e-posta ve bildirimler yalnızca hesabınız ve işlemlerinizle ilgilidir. İleride ticari elektronik ileti gönderilecekse, bu Sözleşme''den ayrı olarak mevzuata uygun izin alınır ve izni geri çekme imkânı sunulur.

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

Hizmetin sunulmasında kullanılan altyapı sağlayıcıları ve yurt dışına aktarım Gizlilik Politikası ile Aydınlatma Metni''nde açıklanmıştır.

İşletmeci, hukuki yükümlülükleri çerçevesinde uygun teknik ve idari tedbirleri almayı hedefler. Hiçbir sistem için mutlak güvenlik garantisi verilmez.

## 15. Hesap kapatma, silme ve saklama

Kullanıcı, uygulamadaki hesap silme işleviyle veya destek@hizmetcep.com adresine yazarak hesap silme talebinde bulunabilir. Uygulamadan verilen talep 30 gün sonra uygulanır ve bu süre içinde iptal edilebilir. Talebin hesap sahibinden geldiğini doğrulamak için gerekli ve ölçülü ek doğrulama istenebilir.

Silme uygulandığında hesap ve profil bilgileri, kullanıcının yazdığı ilan, teklif, talep, mesaj ve yorum metinleri, fotoğraflar ve bildirim jetonları silinir veya anonim hâle getirilir. Ayrıntılar Gizlilik Politikası''ndadır.

Kanunen saklanması gereken veya bir hakkın tesisi, kullanılması ya da korunması için gerekli sınırlı kayıtlar, gerekli amaç ve süreyle saklanabilir. Yedeklerdeki kopyalar yedekleme döngüsü tamamlandığında silinir.

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
       '2d23ee918f86b69055ade87545ccede3dcddf861d9f588b518e6761323cc9dc2', '2026-10-23', 'DRAFT', NULL, '2026-10-23T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026b003');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-23102026b004', 'cookies',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'cookies'),
       'Bu Çerez Politikası, HizmetCep web sitesini ve web uygulamasını kullanırken tarayıcınızda saklanan çerezler ve benzeri teknolojiler (tarayıcı deposu) hakkında 6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında sizi bilgilendirmek amacıyla hazırlanmıştır.

## 1. Veri Sorumlusu

Veri sorumlusu: Onur Bütün
Adres: 1847/2 Sokak No: 25, Daire: 1, Örnekköy, Karşıyaka/İzmir
E-posta: destek@hizmetcep.com

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

KVKK''nın 11. maddesindeki haklarınıza ilişkin taleplerinizi destek@hizmetcep.com adresine iletebilirsiniz. Ayrıntılı bilgi için Aydınlatma Metni''ni inceleyebilirsiniz.

## 7. Güncellemeler

Kullanılan çerez veya depolarda değişiklik olursa bu politika güncellenir ve güncel sürüm web sitesinde yayımlanır.',
       '12deb1893af2b19d36f4332ed69f3fb31851e7c9905b6d41dd8c4046398c07f7', '2026-10-23', 'DRAFT', NULL, '2026-10-23T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'cookies')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-23102026b004');
