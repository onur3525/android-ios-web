-- 054 — YASAL METİNLER: SİSTEMLE UYUM (6 Kas, işletmeci talebi). sqlite/054 ile BİREBİR.
--
-- Yayındaki metinler sistemin bugünkü davranışıyla karşılaştırıldı ve
-- uyumsuz/eksik maddeler düzeltildi:
--   · Kullanım Sözleşmesi: Hizmet Veren profili tamamlanmadan aktif değildir
--     (ilan göremez, teklif veremez, Bul'da görünmez); e-posta/telefon
--     değişikliği şifresiz, doğrulama bağlantısı / SMS koduyla; ilan 48 saat,
--     en çok 3 teklif, dolunca diğer hizmet verenlere görünmez; teklif talebi
--     30 saat; yeni maddeler: Sıralama ve eşleştirme (Madde 8), Yorum ve
--     puanlar (Madde 9); bakım ekranı; madde numaraları ve iç atıflar.
--   · Aydınlatma Metni: amaçlara Bul'da gösterim, eşleştirme ve iletişim
--     bilgisi değişikliği; otomatik karar beyanı; görünürlük atfı.
--   · Gizlilik Politikası: diğer kullanıcıların görebildiği bilgiler
--     (madde 8); e-posta/telefon değişikliği; cihaz kimliğinin bakım kullanımı;
--     Sözleşme atfı (15. madde).
-- Çerez Politikası ve Ticari İleti Onay Metni değişmedi.
--
-- Yayımdaki sürümler ARŞİVLENİR (silinmez). Kullanım Sözleşmesi onay isteyen
-- belgedir: kullanıcılardan yeni sürüm için onay istenir. Boş veritabanında
-- `baslangic_verisi.js` 053'ten sonra bu göçü de bir kez daha çalıştırır
-- (sabit sürüm kimlikleriyle idempotent).

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'terms' AND status = 'PUBLISHED'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-06112026f001');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-06112026f001', 'terms',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'terms'),
       'İşbu Kullanım Sözleşmesi ("Sözleşme"), HizmetCep mobil uygulamasını ve web sitesini (birlikte "Platform") işleten hizmet sağlayıcı ("İşletmeci") ile Platform''a üye olan veya Platform''u kullanan gerçek kişi ("Kullanıcı") arasında, Kullanıcı''nın elektronik ortamda kabulüyle kurulur.

## Madde 1 – Taraflar

- Unvan: Onur Bütün (Bütün Mühendislik)
- Adres: İzmir/Türkiye
- E-posta: onur@hizmetcep.com
- Destek: destek@hizmetcep.com

## Madde 2 – Tanımlar

- Hizmet Alan: Platform üzerinden hizmet arayan, ilan veya teklif talebi oluşturan Kullanıcı.
- Hizmet Veren: Platform''da profil oluşturan, ilanlara ve taleplere teklif veren Kullanıcı.
- Kullanıcı İçeriği: Kullanıcı''nın Platform''a yüklediği veya yazdığı profil bilgisi, fotoğraf, ilan, teklif, talep, mesaj, yorum ve puanlar.
- Hizmet Sözleşmesi: Hizmet Alan ile Hizmet Veren arasında, Platform aracılığıyla buluştuktan sonra kurulan, işin yapılmasına ilişkin anlaşma.

Bir Kullanıcı, Platform''un izin verdiği ölçüde her iki rolde de işlem yapabilir.

## Madde 3 – Platform''un niteliği ve İşletmeci''nin rolü

HizmetCep, hizmet almak isteyenler ile hizmet sunmak isteyenleri dijital ortamda buluşturan bir pazaryeridir. İşletmeci, 6563 sayılı Elektronik Ticaretin Düzenlenmesi Hakkında Kanun kapsamında aracı hizmet sağlayıcı, 5651 sayılı Kanun kapsamında yer sağlayıcıdır.

İşletmeci; Hizmet Sözleşmesi''nin tarafı, işi yapan, işveren, yüklenici, garantör veya ödeme kuruluşu değildir. İşin kapsamı, fiyatı, zamanı, malzemesi, ödemesi, iptali, garantisi ve ayıp sorumluluğu yalnızca Hizmet Alan ile Hizmet Veren arasında kararlaştırılır.

Platform''da bir profilin, ilanın, teklifin veya yorumun bulunması; kişinin kimliğinin, mesleki yeterliliğinin, ruhsatının, sigortasının veya hizmet kalitesinin İşletmeci tarafından doğrulandığı anlamına gelmez. Platform''daki doğrulama; telefon numarasının SMS koduyla, e-posta adresinin ise doğrulama bağlantısıyla veya Google/Apple hesabıyla hesap sahibine ait olduğunun doğrulanmasıyla sınırlıdır.

Bu madde, İşletmeci''nin kendi kusurundan veya emredici mevzuattan doğan sorumluluğunu ortadan kaldırmaz.

## Madde 4 – Üyelik ve yaş koşulu

Platform''a yalnızca 18 yaşını doldurmuş kişiler üye olabilir. Kullanıcı, Sözleşme''yi kabul ederek 18 yaşını doldurduğunu ve verdiği bilgilerin doğru ve kendisine ait olduğunu beyan eder. Gerçeğe aykırı beyan tespit edilirse hesap Madde 14''e göre kapatılabilir.

Üyelik şu yollardan biriyle oluşturulur:

- E-posta ve şifre: ad-soyad, telefon, e-posta ve şifre ile.
- Google ile Giriş veya Apple ile Giriş: Kullanıcı''nın izin verdiği ölçüde ad, e-posta adresi ve sağlayıcının verdiği benzersiz hesap kimliği alınır. Bu hesaplarda şifre zorunlu değildir; Kullanıcı dilerse Hesap Ayarları''ndan ayrıca şifre oluşturabilir.

Profilin tamamlanması:

- Hizmet Alan: ilan veya teklif talebi oluşturmadan önce telefon numarasını SMS koduyla doğrular ve adresini (il, ilçe, mahalle) girer.
- Hizmet Veren: telefon numarasını SMS koduyla doğrular, adresini girer ve en az bir hizmet kategorisi ile en az bir hizmet bölgesi (ilçe) seçer.

Hizmet Veren bu bilgileri tamamlayana kadar Platform''da aktif hesap sayılmaz: ilanları göremez, ilanlara ve teklif taleplerine teklif veremez, "Bul" aramalarında görünmez, herkese açık profili gösterilmez ve kendisine teklif talebi gönderilemez. Bilgiler tamamlandığında bu kısıtlar kendiliğinden kalkar.

## Madde 5 – Hesap güvenliği

Kullanıcı; şifresini, doğrulama kodlarını ve Google/Apple hesabının güvenliğini korumakla yükümlüdür ve bunları kimseyle paylaşmaz. Hesabının izinsiz kullanıldığını fark ederse gecikmeden destek@hizmetcep.com adresine bildirir.

Güvenlik için bir hesap aynı anda tek cihazda açık kalır; yeni bir cihazdan giriş yapıldığında önceki cihazdaki oturum kapanır. İşletmeci, kötüye kullanımı önlemek için hız sınırları (örneğin doğrulama kodlarının sayısı ve sıklığı) ve ek doğrulama adımları uygulayabilir.

İletişim bilgilerinin değiştirilmesi:

- E-posta adresi: Profil Bilgilerim ekranında yeni adres girildiğinde bu adrese bir doğrulama bağlantısı gönderilir. Adres, yalnızca bağlantı tıklandığında değişir; o zamana kadar mevcut adres geçerlidir. Değişiklik tamamlandığında eski adrese bilgilendirme e-postası gönderilir.
- Telefon numarası: yeni numaraya gönderilen SMS kodu girildiğinde değişir; değişiklikten sonra diğer cihazlardaki oturumlar kapatılır.

Bu iki işlemde mevcut şifre istenmez; değişiklik, yeni e-posta adresinin veya yeni telefon numarasının Kullanıcı''ya ait olduğunun doğrulanmasıyla yapılır. Bu nedenle Kullanıcı, oturumu açık cihazını başkalarının kullanımına bırakmamakla ve cihaz kilidini kullanmakla yükümlüdür.

## Madde 6 – Kullanıcı''nın yükümlülükleri ve yasaklar

Kullanıcı mevzuata, bu Sözleşme''ye ve diğer kullanıcıların haklarına uygun davranır. Özellikle şunlar yasaktır:

- sahte veya yanıltıcı profil, ilan, teklif veya yorum oluşturmak; başkasının kimliğini kullanmak;
- dolandırıcılık, ödeme hilesi, tehdit, taciz, hakaret veya ayrımcılık;
- başkalarının kişisel verilerini izinsiz paylaşmak veya Platform''dan edinilen bilgileri amaç dışı kullanmak;
- fikri mülkiyet ve kişilik haklarını ihlal etmek;
- zararlı yazılım, otomatik veri toplama (bot, kazıma) veya Platform''un çalışmasını bozma girişimi;
- spam ve izinsiz reklam; hukuka aykırı ürün veya hizmet tanıtımı.

Hizmet Veren; sunduğu işin gerektirdiği mesleki yeterlilik, ruhsat, izin, sigorta, vergi ve fatura yükümlülüklerinden kendisi sorumludur.

## Madde 7 – İlan, talep ve teklif kuralları

Kullanıcı; ilan, talep ve tekliflerinde doğru, güncel ve yanıltıcı olmayan bilgi verir.

İlanlar:

- Hizmet Alan''ın yayımladığı ilan 48 saat yayında kalır ve süre sonunda kendiliğinden kapanır.
- İlan, kategorisine ve bölgesine uyan, profili tamamlanmış Hizmet Verenlere gösterilir.
- Bir ilana en fazla 3 Hizmet Veren teklif verebilir. Üçüncü teklif verildiği anda ilan, teklif vermemiş Hizmet Verenlerin listesinden kaldırılır ve onlar tarafından görüntülenemez.
- Hizmet Alan tekliflerden birini seçmekte veya hiçbirini seçmemekte serbesttir.

Teklif talepleri ("Bul"):

- Hizmet Alan, "Bul" ile bulduğu bir Hizmet Veren''e doğrudan teklif talebi gönderebilir.
- Hizmet Veren talebe teklif verebilir veya talebi reddedebilir. Teklif verildikten sonra Hizmet Alan 30 saat içinde teklifi kabul etmezse talep kendiliğinden kapanır ve mesajlaşma sona erer.
- Mesajlaşma yalnızca teklif verildikten sonra ve yalnızca iki taraf arasında açılır.

Uygulamada gösterilen süre ve sınırlar Platform''un işleyişi gereği değiştirilebilir; Kullanıcı aleyhine esaslı değişiklikler Madde 20''ye göre yapılır.

Bir ilanın veya teklifin yayımlanması, İşletmeci''nin hizmeti onayladığı veya taraflar arasında bir sözleşmenin kurulduğu anlamına gelmez. Teklif tutarı Hizmet Veren''in beyanıdır; bağlayıcı fiyat taraflar arasında kararlaştırılır.

## Madde 8 – Sıralama ve eşleştirme

Platform, kullanıcıları aşağıdaki ana ölçütlerle eşleştirir ve sıralar:

- "Bul" sonuçları: Hizmet Alan''ın seçtiği hizmeti veya kategoriyi kendi profilinde seçmiş, profili tamamlanmış ve hesabı etkin Hizmet Verenler listelenir; Hizmet Alan''ın ilçesine hizmet verenler önce gösterilir.
- Hizmet Veren''in iş listesi: Hizmet Veren''in seçtiği kategorilere ve hizmet bölgelerine uyan, yayında olan ve teklif sınırı dolmamış ilanlar gösterilir; varsayılan olarak kategori eşleşmesine ve yayın tarihine göre sıralanır; Hizmet Veren sıralamayı uygulamadaki "Sırala" seçeneğiyle değiştirebilir.

Platform''da ücret karşılığı öne çıkarma, sıralama yükseltme veya reklamlı sonuç yoktur; İşletmeci sıralamayı herhangi bir Kullanıcı lehine ücret veya başka bir menfaat karşılığında değiştirmez. Böyle bir özellik eklenirse ücretli sonuçlar açıkça işaretlenir ve Sözleşme güncellenir.

## Madde 9 – Yorum ve puanlar

- Yalnızca gerçek bir işlemin tarafı olan Hizmet Alan değerlendirme yapabilir: ilan akışında bir teklifi seçtiği iş için, teklif talebi akışında iş tamamlandı olarak işaretlendikten sonra. Her iş için bir kez, 1–5 arası puan ve isteğe bağlı en fazla 1.000 karakterlik yorum verilebilir.
- Yorumlar, yazarın kısaltılmış adıyla (örneğin "Ad S.") Hizmet Veren''in profilinde yayımlanır; ortalama puan ve puan dağılımı yayımdaki tüm yorumlardan hesaplanır.
- İşletmeci yorumların içeriğini değiştirmez, olumsuz olduğu için yorum kaldırmaz veya gizlemez, Hizmet Veren lehine yorum satın almaz veya yazdırmaz.
- Hakaret, tehdit, kişisel veri, sahte veya işlemle ilgisiz içerik barındıran ya da hukuka aykırı yorumlar, şikâyet üzerine veya resen incelenerek kaldırılabilir; kaldırma gerekçesiyle birlikte kayda alınır.
- Hizmet Veren, kendisi hakkındaki bir yorumu "Şikâyet Et" seçeneğiyle bildirebilir.

## Madde 10 – Ödeme platform dışındadır

Platform üzerinden hiçbir ödeme alınmaz ve yapılmaz. Hizmet bedeli; Hizmet Alan ile Hizmet Veren arasında, Platform dışında (nakit, havale/EFT vb.) kararlaştırılır ve doğrudan ödenir.

- İşletmeci; ödeme aracısı, emanetçi, tahsilatçı veya ödeme kuruluşu değildir; bedelin ödenmesini, iadesini veya işin yapılmasını garanti etmez.
- Platform hiçbir aşamada kredi kartı, banka kartı veya banka hesap bilgisi istemez, işlemez ve saklamaz. Platform adına bu bilgileri isteyen mesajlar dolandırıcılık girişimi olabilir ve destek@hizmetcep.com adresine bildirilmelidir.
- Kullanıcılar; iş yapılmadan bedelin tamamını peşin ödememenin, makbuz veya fatura istemenin ve anlaşmayı yazılı hâle getirmenin kendi yararlarına olduğunu kabul eder.
- İleride Platform''a ödeme özelliği eklenirse kart verileri yalnızca 6493 sayılı Kanun kapsamında lisanslı bir ödeme kuruluşu tarafından işlenir; ücret, kapsam ve iptal koşulları işlem öncesinde gösterilir ve Sözleşme güncellenir.

## Madde 11 – Ücretler

Platform şu anda ücretsizdir. İleride ücretli bir özellik eklenirse, ücret ve koşullar önceden açıkça gösterilmeden ve Kullanıcı''nın ayrıca onayı alınmadan hiçbir ücret talep edilmez.

## Madde 12 – Kullanıcı içeriği ve fikri haklar

Kullanıcı, Kullanıcı İçeriği''nin hukuka uygun olduğunu ve paylaşmaya yetkili olduğunu beyan eder; içerik üzerindeki hakları kendisinde kalır. Kullanıcı, içeriğin Platform''da gösterilmesi, saklanması, iletilmesi ve yedeklenmesi için gerekli olan, Platform''u işletme amacıyla sınırlı, münhasır olmayan ve üyelik süresiyle sınırlı bir kullanım izni verir. Bu izin, içeriğin reklam amacıyla kullanımını kapsamaz.

Platform''un yazılımı, tasarımı, logosu ve markası İşletmeci''ye aittir; izinsiz kopyalanamaz.

## Madde 13 – Mesajlar, şikâyetler ve içerik kaldırma

Uygulama içi mesajlar, hizmetin sunulması için işlenir. Yetkili yönetici mesajlara yalnızca şikâyet incelemesi, güvenlik, kötüye kullanımın önlenmesi veya hukuki yükümlülük amacıyla, gerekçe girerek erişebilir; her erişim kayıt altına alınır.

Bir ilan, kullanıcı profili veya yorum, uygulamadaki "Şikâyet Et" seçeneğiyle ya da destek@hizmetcep.com adresinden bildirilebilir. 5651 sayılı Kanun kapsamındaki hukuka aykırı içerik bildirimleri de bu adrese yapılır. Şikâyet edenin kimliği şikâyet edilene bildirilmez.

## Madde 14 – Tedbirler ve hesap kısıtlama

İşletmeci; hukuka aykırılık, sahtecilik, güvenlik riski veya bu Sözleşme''nin ihlali hakkında makul gerekçe bulunduğunda, olayın ağırlığıyla orantılı olarak içeriği kaldırabilir, hesabı geçici olarak askıya alabilir veya kalıcı olarak kapatabilir. Acil durumlar dışında tedbirin gerekçesi Kullanıcı''ya bildirilir; Kullanıcı destek@hizmetcep.com adresinden itiraz edebilir.

## Madde 15 – Hesabı dondurma ve silme

Dondurma: Kullanıcı, Hesap Ayarları > Hesabı Dondur ile hesabını geçici olarak kapatabilir. Devam eden bir iş varken dondurma yapılamaz. Dondurulan hesabın açık oturumları kapatılır; hesap aramalarda görünmez ve bildirim almaz; veriler silinmez. Yeniden giriş yapıldığında hesap etkinleşir.

Silme: Kullanıcı, uygulamadaki veya web sitesindeki Hesap Ayarları > Hesabı Sil adımıyla ya da destek@hizmetcep.com adresine yazarak hesabının silinmesini isteyebilir.

- Kimlik doğrulama: Şifreli hesapta mevcut şifre istenir. Google veya Apple ile açılmış hesapta şifre yerine aynı sağlayıcıyla yeniden giriş yapılarak kimlik doğrulanır. E-postayla gelen talepte, talebin hesap sahibinden geldiğini doğrulamak için ölçülü ek bilgi istenebilir.
- 30 günlük süre: Talep 30 gün sonra uygulanır; bu süre içinde giriş yapılarak iptal edilebilir.
- Silme uygulandığında: ad, telefon, e-posta, şifre, profil fotoğrafı, adres ve hizmet profili kaldırılır; Kullanıcı''nın yazdığı ilan, teklif notu, talep, mesaj, yorum ve şikâyet metinleri ile yüklediği dosyalar silinir; oturumlar ve bildirim jetonları silinir; Google Firebase''deki kimlik kaydı silinir; Apple ile açılmış hesaplarda Apple''a verilen yetki geri alınır.
- Kanuni istisnalar: 5651 sayılı Kanun gereği trafik kayıtları ve bunların eşleştirilebilmesi için ad, telefon ve e-posta bilgisinin ayrı bir yasal arşivdeki kopyası 1 yıl saklanır; sözleşme onay ve işlem kayıtları kişisel alanları maskelenmiş olarak saklanır. Ayrıntılar Gizlilik Politikası''ndadır.
- Yedekler: Silinen veriler şifreli yedeklerden en geç 14 gün içinde kendiliğinden silinir.

Karşı tarafın kendi yazdığı mesajlar onun verisi olduğu için silinmez.

## Madde 16 – Kişisel veriler ve ticari ileti

Kişisel veriler, uygulamada ve web sitesinde her zaman erişilebilen KVKK Aydınlatma Metni ve Gizlilik Politikası''na göre işlenir. Bu Sözleşme''nin kabulü kişisel veri işleme için açık rıza anlamına gelmez ve açık rıza üyelik şartı değildir.

Platform''un gönderdiği işlem bildirimleri (doğrulama kodu, teklif, mesaj, hesap güvenliği) ticari ileti değildir ve izne bağlı değildir. Kampanya ve duyuru içerikli ticari elektronik iletiler yalnızca Kullanıcı ayrı ve isteğe bağlı Ticari Elektronik İleti Onayı''nı verdiyse gönderilir; onay vermemek üyeliği etkilemez ve onay her zaman ücretsiz geri alınabilir.

## Madde 17 – Hizmetin sürekliliği, bakım ve değişiklikler

Platform''un kesintisiz ve hatasız çalışacağı garanti edilmez; bakım, güncelleme veya üçüncü taraf hizmetlerindeki arızalar geçici kesintiye yol açabilir. Planlı veya acil bakım sırasında Platform geçici olarak kullanıma kapatılabilir; bu süre boyunca uygulamada ve web sitesinde bakım ekranı gösterilir, bakım bittiğinde Platform kendiliğinden yeniden açılır. İşletmeci özellikleri değiştirebilir veya kaldırabilir; Kullanıcı''nın kanuni hakları saklıdır.

## Madde 18 – Sorumluluk

Kullanıcı, kendi beyanlarından, içeriklerinden ve karşı tarafla yaptığı Hizmet Sözleşmesi''nden sorumludur. İşletmeci, Hizmet Sözleşmesi''nin tarafı olmadığından işin yapılmamasından, ayıplı yapılmasından veya bedelin ödenmemesinden sorumlu tutulamaz. Bu Sözleşme; kast veya ağır kusurdan doğan sorumluluğu ve 6502 sayılı Kanun başta olmak üzere emredici mevzuattan doğan hakları sınırlamaz.

## Madde 19 – Mücbir sebep

Doğal afet, savaş, salgın, yaygın altyapı kesintisi, siber saldırı ve kamu otoritesi kararları gibi tarafların kontrolü dışındaki olaylar süresince yükümlülüklerin ifası ertelenir.

## Madde 20 – Süre, güncelleme ve sona erme

Sözleşme kabul tarihinde yürürlüğe girer ve üyelik süresince geçerlidir. Güncel metin sürüm numarası ve yürürlük tarihiyle yayımlanır. Kullanıcı aleyhine esaslı değişikliklerde yeni sürüm Kullanıcı''ya gösterilir ve onayı alınmadan uygulanmaz; onaylamayan Kullanıcı hesabını silebilir.

## Madde 21 – Bildirim ve ispat

Kullanıcı''ya bildirimler kayıtlı e-posta adresine, telefonuna veya uygulama içinden yapılır. Taraflar, İşletmeci''nin sunucularındaki elektronik kayıtların (onay kayıtları, işlem ve trafik kayıtları) 6100 sayılı Hukuk Muhakemeleri Kanunu''nun 193. maddesi kapsamında delil niteliğinde olduğunu kabul eder; karşı ispat hakkı saklıdır.

## Madde 22 – Uygulanacak hukuk ve uyuşmazlıklar

Sözleşme Türk hukukuna tabidir. Uyuşmazlıklarda 6502 sayılı Tüketicinin Korunması Hakkında Kanun''daki parasal sınırlar dahilinde tüketici hakem heyetleri, aşılması hâlinde tüketici mahkemeleri yetkilidir; tüketici sıfatı taşımayan kullanıcılar bakımından İzmir mahkemeleri ve icra daireleri yetkilidir.

## Madde 23 – Elektronik kabul

Kullanıcı, kayıt sırasında Sözleşme''nin tam metnini açabilir ve "Kullanım Sözleşmesi''ni okudum ve kabul ediyorum" kutusunu işaretleyerek kabul eder. Kabul edilen sürüm, metnin SHA-256 özeti, tarih-saat ve platform kayda alınır. Bu kabul; Aydınlatma Metni''nin gösterildiğine ilişkin bilgilendirmeden ve Ticari Elektronik İleti Onayı''ndan ayrı bir işlemdir. Sözleşme''nin bir hükmünün geçersizliği diğer hükümleri etkilemez.',
       'b9051ebd142b99ebcf5bf771e6ce9f3d7218d616d379521e46dbda870d7b23b3', '2026-11-06', 'PUBLISHED', NULL, '2026-11-06T09:00:00.000Z', NULL, '2026-11-06T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-06112026f001');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'kvkk' AND status = 'PUBLISHED'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-06112026f002');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-06112026f002', 'kvkk',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'kvkk'),
       'Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu''nun ("KVKK") 10. maddesi ve Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ uyarınca HizmetCep kullanıcılarını bilgilendirmek için hazırlanmıştır. Bu metin bir bilgilendirmedir; onay veya açık rıza anlamına gelmez. Ayrıntılar Gizlilik Politikası''ndadır.

## 1. Veri sorumlusu

- Unvan: Onur Bütün (Bütün Mühendislik)
- Adres: İzmir/Türkiye
- E-posta: onur@hizmetcep.com
- Destek: destek@hizmetcep.com

## 2. Verilerin saklandığı yer

HizmetCep''in uygulama sunucusu ve ana veritabanı Türkiye''de, İstanbul''daki veri merkezinde (Hosting Türkiye) bulunur. Hesap, profil, adres, ilan, teklif, talep, mesaj, yorum, şikâyet, onay, oturum ve trafik kayıtları bu sunucuda tutulur. Veritabanı yedekleri de aynı yerde, şifreli olarak saklanır. Yalnızca 6. maddede sayılan hizmetler için sınırlı veriler yurt dışına aktarılır.

## 3. İşlenen kişisel veriler

- Kimlik ve iletişim: ad-soyad, telefon numarası, e-posta adresi.
- Google / Apple ile giriş: sağlayıcının izin verdiğiniz ölçüde ilettiği ad ve e-posta adresi (Apple''ın "E-postamı Gizle" adresi dahil), benzersiz sağlayıcı hesap kimliği, hangi sağlayıcıyla girildiği. Google veya Apple şifreniz bize ulaşmaz.
- Hesap: şifre özeti (şifre oluşturduysanız), roller, bildirim tercihleri, hesap durumu.
- Adres ve hizmet bölgesi: il, ilçe, mahalle; hizmet verenler için kategoriler ve ilçeler.
- Hizmet içerikleri: ilan, fotoğraf, teklif, teklif talebi, uygulama içi mesaj, yorum ve puan, profil fotoğrafı.
- Şikâyet ve destek: şikâyet nedeni ve açıklaması, destek talepleri ve e-postaları, geri bildirimler.
- Hukuki işlem: Kullanım Sözleşmesi onay kayıtları, ticari ileti onay ve ret kayıtları, hesap dondurma ve silme talepleri.
- İşlem güvenliği: oturum kayıtları (IP, cihaz/tarayıcı bilgisi), doğrulama kodu kayıtları, bildirim jetonu, uygulamanın ürettiği rastgele cihaz kimliği.
- Trafik kayıtları: işlem sırasındaki IP adresi, kaynak port, işlem türü, tarih-saat.
- Pazarlama (yalnızca onay verdiyseniz): ticari ileti gönderimi için e-posta ve telefon.

Otomatik karar: Platform''da kişiler hakkında hukuki sonuç doğuran otomatik karar verilmez; eşleştirme ve sıralama yalnızca seçtiğiniz kategori ve bölgeye göre yapılır.

Konum takibi yapılmaz; yüklenen fotoğraflardaki konum bilgisi yüklemeden önce silinir. Reklam kimliği (IDFA/AAID) toplanmaz. Özel nitelikli kişisel veri istenmez.

## 4. İşleme amaçları ve hukuki sebepler

- Üyelik, Google/Apple ile giriş, telefon ve e-posta doğrulaması, e-posta ve telefon değişikliklerinin doğrulanması; ilan, teklif, mesaj ve yorum özelliklerinin sunulması; Hizmet Veren profilinin "Bul" aramalarında ve tekliflerde gösterilmesi; ilanların ve Hizmet Verenlerin kategori ve bölgeye göre eşleştirilmesi; seçiminize göre iletişim bilgisinin karşı tarafla paylaşılması; işlem bildirimleri: sözleşmenin kurulması ve ifası (KVKK m.5/2-c).
- Şikâyetlerin ve destek taleplerinin yürütülmesi, hukuka aykırı içeriğin kaldırılması: sözleşmenin ifası, hukuki yükümlülük ve meşru menfaat (m.5/2-c, ç, f).
- Hesap güvenliği, tek cihaz oturum kuralı, kötüye kullanımın önlenmesi, teknik sorunların giderilmesi: meşru menfaat (m.5/2-f).
- 5651 sayılı Kanun gereği trafik kayıtlarının saklanması ve yetkili mercilere sunulması: hukuki yükümlülük (m.5/2-ç).
- Onay ve işlem kayıtlarının tutulması, uyuşmazlıklarda hakların korunması: hukuki yükümlülük; hakkın tesisi, kullanılması veya korunması (m.5/2-ç, e).
- Kampanya ve duyuru içerikli ticari elektronik ileti gönderimi: açık rıza (m.5/1); yalnızca isteğe bağlı Ticari Elektronik İleti Onayı verdiyseniz.

Açık rıza üyelik şartı değildir. Ticari ileti onayı vermemeniz veya geri almanız hizmetten yararlanmanızı etkilemez.

## 5. Toplama yöntemi

Veriler; mobil uygulama ve web sitesinde doldurduğunuz alanlardan, Google veya Apple ile giriş yaptığınızda bu sağlayıcılardan, destek e-postalarından ve otomatik sistem kayıtlarından elektronik ortamda toplanır.

## 6. Aktarım

Yurt içinde: diğer kullanıcılara (hizmetin gerektirdiği ölçüde ve seçiminize göre; hangi bilginin kime görünür olduğu Gizlilik Politikası''nın 8. maddesindedir), sunucu hizmeti sağlayıcısı Hosting Türkiye''ye (veri işleyen), yetkili kamu kurum ve kuruluşları ile adli mercilere (kanuni yükümlülük hâlinde) ve gerektiğinde hukuk ve mali müşavirlere.

Yurt dışına, hizmetin teknik olarak sunulabilmesi için yalnızca şu sağlayıcılara ve yanlarında yazan verilerle sınırlı olarak:

- Google LLC (Firebase) – ABD ve Google veri merkezleri: giriş ve kimlik doğrulama, SMS doğrulama kodu, Google ile Giriş, bildirim gönderimi. Firebase kullanıcı kimliği, telefon, e-posta, giriş bilgisi, doğrulama anındaki cihaz ve IP bilgisi, bildirim jetonu.
- Cloudflare, Inc. (R2) – Avrupa: fotoğrafların saklanması. Yüklenen fotoğraflar (konum bilgisi silinmiş).
- Resend, Inc. – ABD şirketi, gönderim Japonya bölgesi: e-posta gönderimi ve destek e-postalarının alınması. E-posta adresi, ad, e-posta içeriği.
- Apple Inc. – ABD: iOS bildirim iletimi ve Apple ile Giriş. Bildirim jetonu; Apple hesap kimliği, ad, e-posta.
- Netlify, Inc. ve GitHub, Inc. – ABD: web sitesinin barındırılması. Ziyaretçinin IP adresi ve tarayıcı bilgisi.

Bu aktarımlar, KVKK''nın 9. maddesinin 4. fıkrası ve Kişisel Verilerin Yurt Dışına Aktarılmasına İlişkin Usul ve Esaslar Hakkında Yönetmelik uyarınca Kişisel Verileri Koruma Kurulu''nun ilan ettiği standart sözleşmeler imzalanarak yapılır; her sözleşme imzadan itibaren 5 iş günü içinde Kurul''a bildirilir. Sağlayıcılar verileri yalnızca HizmetCep adına ve talimatıyla, hizmetin gerektirdiği ölçüde işler; tüm bağlantılar şifrelidir (HTTPS/TLS). Yurt dışı aktarım için sizden açık rıza istenmez.

## 7. Saklama süresi

Veriler işleme amacı ve mevzuattaki süreler boyunca saklanır, sonra silinir, yok edilir veya anonim hâle getirilir. Trafik kayıtları 5651 sayılı Kanun gereği 1 yıl saklanır; hesap silinse de bu süre dolmadan silinmez. Hesap silme talebi 30 gün sonra uygulanır; silinen veriler yedeklerden en geç 14 gün içinde silinir. Kategori bazında süreler Gizlilik Politikası''ndadır.

## 8. Haklarınız (KVKK m.11)

- kişisel verinizin işlenip işlenmediğini öğrenme ve işlenmişse bilgi talep etme;
- işleme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme;
- yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme;
- eksik veya yanlış işlenmişse düzeltilmesini, kanuni şartlarla silinmesini veya yok edilmesini isteme ve bunun aktarılan kişilere bildirilmesini talep etme;
- münhasıran otomatik sistemlerle analiz sonucu aleyhinize bir sonuç çıkmasına itiraz etme;
- kanuna aykırı işleme nedeniyle uğradığınız zararın giderilmesini talep etme.

## 9. Başvuru

Başvurularınızı, Veri Sorumlusuna Başvuru Usul ve Esasları Hakkında Tebliğ''e uygun olarak kimliğinizi ve talebinizi içeren bir yazıyla, kayıtlı e-posta adresinizden onur@hizmetcep.com adresine iletebilirsiniz. Başvurular en geç 30 gün içinde ücretsiz sonuçlandırılır; işlemin ayrıca maliyet gerektirmesi hâlinde Kurul''un belirlediği tarifedeki ücret alınabilir. Başvurunuzun reddedilmesi, cevabın yetersiz bulunması veya süresinde cevap verilmemesi hâlinde, cevabı öğrendiğiniz tarihten itibaren 30 ve her hâlde başvuru tarihinden itibaren 60 gün içinde Kişisel Verileri Koruma Kurulu''na şikâyette bulunabilirsiniz.',
       '0c8e325a00c2cad8d7fc1c11634d90664109db89efe05a1638e1cd59aa755a80', '2026-11-06', 'PUBLISHED', NULL, '2026-11-06T09:00:00.000Z', NULL, '2026-11-06T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'kvkk')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-06112026f002');

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'privacy' AND status = 'PUBLISHED'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-06112026f003');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-06112026f003', 'privacy',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'privacy'),
       'Bu politika, HizmetCep mobil uygulaması (iOS, Android) ve web sitesi üzerinden işlenen kişisel verileri, kullanılan yazılım bileşenlerini (SDK) ve cihaz tanımlayıcılarını ayrıntılı olarak açıklar. Kısa bilgilendirme KVKK Aydınlatma Metni''nde, web sitesindeki çerezler Çerez Politikası''nda yer alır.

## 1. Veri sorumlusu

- Unvan: Onur Bütün (Bütün Mühendislik)
- Adres: İzmir/Türkiye
- E-posta: onur@hizmetcep.com
- Destek: destek@hizmetcep.com

## 2. Verileriniz nerede tutulur?

Uygulama sunucusu ve ana veritabanı Türkiye''de, İstanbul''daki veri merkezindedir (Hosting Türkiye). Veritabanı her gece yedeklenir; yedekler aynı sunucuda, güçlü şifrelemeyle korunarak 14 gün saklanır ve süresi dolanlar kendiliğinden silinir. Yurt dışına yalnızca 6. maddedeki hizmetler için gerekli veriler aktarılır.

## 3. İşlenen kişisel veriler

- Kimlik ve iletişim: ad-soyad, telefon numarası, e-posta adresi.
- Google / Apple ile giriş: ad, e-posta adresi, benzersiz sağlayıcı hesap kimliği, giriş sağlayıcısı (bkz. madde 5).
- Hesap: şifre (yalnızca geri döndürülemez özeti), roller, bildirim tercihleri, hesap durumu.
- Adres ve hizmet bölgesi: il, ilçe, mahalle; hizmet verenler için kategoriler ve hizmet verilen ilçeler.
- Hizmet içerikleri: ilanlar, fotoğraflar, teklifler, teklif talepleri, uygulama içi mesajlar ve fotoğrafları, yorum ve puanlar, profil fotoğrafı.
- Şikâyet ve destek: şikâyetin nedeni, açıklaması ve sonucu; destek talepleri ve e-postaları; geri bildirimler.
- Hukuki işlem: Kullanım Sözleşmesi''nin kabul edilen sürümü (tarih-saat, sürüm, SHA-256 özeti, platform); ticari ileti onay ve ret kayıtları (tarih-saat, kaynak); hesap dondurma ve silme talepleri.
- İşlem güvenliği: oturum kayıtları (IP adresi, cihaz/tarayıcı bilgisi), doğrulama kodu kayıtları, bildirim jetonu, rastgele cihaz kimliği, yönetici işlem kayıtları.
- Trafik kayıtları: giriş, kayıt, oturum yenileme ve içerik gönderme işlemlerinde IP adresi, kaynak port, işlem türü, tarih-saat.

HizmetCep GPS veya arka planda konum takibi yapmaz ve konum izni istemez. Yüklenen fotoğraflardaki konum ve cihaz bilgisi (EXIF/GPS) yüklemeden önce uygulama tarafından silinir. Özel nitelikli kişisel veri istenmez; ilan, mesaj ve yorumlarda paylaşılmamalıdır.

## 4. Amaçlar ve hukuki sebepler

Amaç ve hukuki sebeplerin tam listesi KVKK Aydınlatma Metni''nin 4. maddesindedir. Özetle: üyelik ve hizmetin sunulması sözleşmenin ifasına (KVKK m.5/2-c), güvenlik ve kötüye kullanımın önlenmesi meşru menfaate (m.5/2-f), trafik kayıtları hukuki yükümlülüğe (m.5/2-ç), onay kayıtları hakkın korunmasına (m.5/2-e), ticari ileti ise yalnızca isteğe bağlı açık rızanıza (m.5/1) dayanır. Açık rıza üyelik şartı değildir.

## 5. Google ile Giriş ve Apple ile Giriş

- Alınan veriler: sağlayıcının sizin izninizle ilettiği ad, e-posta adresi ve benzersiz hesap kimliği. Google veya Apple şifreniz, rehberiniz ya da diğer hesap verileriniz bize iletilmez.
- Apple "E-postamı Gizle": bu seçeneği kullanırsanız Apple''ın size özel yönlendirme adresi kaydedilir; e-postalarımız Apple üzerinden size ulaşır.
- Doğrulama: kimlik doğrulaması Google Firebase Authentication üzerinden yapılır; sunucumuz yalnızca doğrulanmış kimlik belgesini kontrol eder.
- Kritik işlemler: şifresi olmayan Google/Apple hesaplarında hesap silme ve şifre oluşturma gibi işlemlerde şifre yerine aynı sağlayıcıyla yeniden giriş istenir.
- E-posta ve telefon değişikliği: şifre istenmez. E-posta adresi, yeni adrese gönderilen bağlantı tıklanınca değişir ve eski adrese bilgilendirme gönderilir; telefon numarası, yeni numaraya gönderilen SMS koduyla değişir ve diğer cihazlardaki oturumlar kapatılır.
- Bağlantıyı kaldırma: hesabınızı sildiğinizde Firebase kaydınız silinir; Apple ile açılmış hesaplarda Apple''a verdiğiniz yetki geri alınır. Ayrıca Google hesabınızın veya Apple Kimliğinizin ayarlarından HizmetCep erişimini kaldırabilirsiniz.
- Google ve Apple''ın kendi işlemeleri bu şirketlerin gizlilik politikalarına tabidir.

## 6. Hizmet sağlayıcılar ve yurt dışına aktarım

Yurt içi: Hosting Türkiye (İstanbul) – uygulama sunucusu, veritabanı ve yedekler.

Yurt dışı:

- Google LLC (Firebase) – ABD ve Google veri merkezleri: giriş ve kimlik doğrulama, SMS doğrulama kodu, Google ile Giriş, bildirim gönderimi. Firebase kullanıcı kimliği, telefon, e-posta, giriş bilgisi, doğrulama anındaki cihaz ve IP bilgisi, bildirim jetonu.
- Cloudflare, Inc. (R2) – Avrupa: fotoğrafların saklanması. Yüklenen fotoğraflar (konum bilgisi silinmiş).
- Resend, Inc. – ABD şirketi, gönderim Japonya bölgesi: e-posta gönderimi ve destek e-postalarının alınması. E-posta adresi, ad, e-posta içeriği.
- Apple Inc. – ABD: iOS bildirim iletimi ve Apple ile Giriş. Bildirim jetonu; Apple hesap kimliği, ad, e-posta.
- Netlify, Inc. ve GitHub, Inc. – ABD: web sitesinin barındırılması. Ziyaretçinin IP adresi ve tarayıcı bilgisi.

Bu aktarımlar, KVKK''nın 9. maddesinin 4. fıkrası ve Kişisel Verilerin Yurt Dışına Aktarılmasına İlişkin Usul ve Esaslar Hakkında Yönetmelik uyarınca Kişisel Verileri Koruma Kurulu''nun ilan ettiği standart sözleşmeler imzalanarak yapılır; her sözleşme imzadan itibaren 5 iş günü içinde Kurul''a bildirilir. Sağlayıcılar verileri yalnızca HizmetCep adına ve talimatıyla, hizmetin gerektirdiği ölçüde işler; tüm bağlantılar şifrelidir (HTTPS/TLS). Yurt dışı aktarım için sizden açık rıza istenmez.

Bunların dışında veriler; hizmetin gerektirdiği ölçüde diğer kullanıcılarla (madde 8), kanuni yükümlülük hâlinde yetkili kamu kurumları ve adli mercilerle, gerektiğinde hukuk ve mali müşavirlerle paylaşılır. Kişisel veriler satılmaz, kiralanmaz ve reklam amacıyla üçüncü kişilerle paylaşılmaz.

## 7. Mobil tanımlayıcılar ve SDK politikası

Mobil uygulama web çerezi kullanmaz. Hizmetin çalışması için aşağıdaki yazılım bileşenleri ve tanımlayıcılar kullanılır; listede olmayan hiçbir üçüncü taraf SDK''sı yoktur.

Kullanılan SDK''lar:

- Firebase Authentication (Google): giriş, SMS doğrulama kodu, şifre sıfırlama.
- Firebase Cloud Messaging (Google): bildirim gönderimi; iOS''ta Apple APNs üzerinden.
- Google Sign-In (Google): Google ile Giriş.
- Apple ile Giriş (Apple, Firebase üzerinden): Apple ile Giriş.
- Güvenli depolama (cihazın kendi sistemi): oturum anahtarlarının iOS Keychain / Android Keystore''da şifreli saklanması.
- Fotoğraf seçici (cihazın kendi sistemi): fotoğraf eklerken kamera veya galeri erişimi; veri cihazdan üçüncü tarafa gitmez.

Kullanılan tanımlayıcılar:

- Bildirim jetonu (FCM / APNs): bildirimin doğru cihaza iletilmesi. Çıkış yapıldığında, bildirim izni kapatıldığında veya hesap silindiğinde silinir.
- Firebase kurulum kimliği: Firebase''in bildirim jetonunu yönetmesi. Uygulama silindiğinde silinir.
- Rastgele cihaz kimliği: tek cihaz oturum kuralı, hesap güvenliği ve bakım çalışması sırasında yetkili test hesaplarının cihazının tanınması; uygulama üretir, donanım bilgisi içermez. Uygulama silindiğinde silinir.
- Oturum anahtarları: oturumun güvenle sürmesi. Çıkış yapıldığında silinir.

Kullanılmayanlar (kesin beyan):

- Reklam kimliği (iOS IDFA, Android Reklam Kimliği/AAID) toplanmaz ve okunmaz; bu nedenle iOS''ta Uygulama Takip İzni (ATT) istenmez.
- Reklam, analiz, kullanıcı davranışı izleme veya profil çıkarma SDK''sı kullanılmaz.
- Apple ve Google tanımıyla takip (tracking) yapılmaz: verileriniz başka şirketlerin uygulama veya sitelerindeki verilerle birleştirilmez, veri aracılarıyla paylaşılmaz.
- Cihaz parmak izi çıkarma, rehber, mikrofon, konum veya arka plan erişimi yoktur.

Cihaz izinleri: bildirim izni (isteğe bağlı; cihaz ayarlarından kapatılabilir) ve yalnızca fotoğraf eklerken kamera/fotoğraf arşivi izni istenir. İzin vermemek yalnızca ilgili özelliği devre dışı bırakır.

## 8. Diğer kullanıcıların görebildiği bilgiler

Hizmet Veren profili: Platform''a giriş yapmış kullanıcılar, profili tamamlanmış ve hesabı etkin Hizmet Verenlerin adını, il ve ilçesini, profil fotoğrafını, hizmet kategorilerini ve hizmet bölgelerini, tamamladığı iş sayısını, puanını ve yorumlarını görebilir. Profili tamamlanmamış, dondurulmuş, askıya alınmış veya silinmiş hesaplar bu şekilde gösterilmez.

Hizmet Alan bilgileri: açık bir ilan, ilana uyan Hizmet Verenlere ilan içeriği, fotoğrafları, ilçe ve mahalle bilgisi ile Hizmet Alan''ın maskelenmiş adıyla (örneğin "A** Y****") gösterilir; tam ad; ilan akışında iletişim açıldığında, teklif talebi akışında Hizmet Veren teklif verdiğinde karşı tarafa görünür.

Yorumlar: yorum yazarının adı kısaltılmış olarak (örneğin "Ad S.") gösterilir.

Telefon numarası herkese açık profil bilgisi değildir.

- İlan akışında: hizmet alan ile teklif veren arasında iletişim açıldığında hizmet verenin telefonu hizmet alana gösterilir. Hizmet alanın telefonu yalnızca ilanda "Telefonumu göster" seçildiyse gösterilir; "Sadece uygulama içi mesaj" seçildiyse hiçbir ekranda paylaşılmaz.
- Teklif talebi akışında: hizmet veren teklif verdikten sonra, talep süresi dolmadığı sürece iletişim açıktır; hizmet alanın telefonu yalnızca "Telefonumu göster" seçildiyse paylaşılır.
- E-posta adresi diğer kullanıcılarla paylaşılmaz.

## 9. Şikâyet ve içerik kaldırma

Şikâyetler yöneticilerce incelenir; hukuka veya Kullanım Sözleşmesi''ne aykırı içerik kaldırılır ya da hesap hakkında tedbir uygulanır. Kaldırılan içerik, olası hukuki talepler için 12. maddedeki sürelerle kayıtlarda tutulur. Şikâyet edenin kimliği şikâyet edilene bildirilmez.

## 10. Güvenlik tedbirleri

- Şifreler geri döndürülemez biçimde saklanır; tüm bağlantılar HTTPS/TLS ile şifrelidir.
- Veritabanına yalnızca sunucunun içinden, sertifika doğrulamalı şifreli bağlantıyla erişilir; sunucu güvenlik duvarıyla korunur.
- Yedekler şifrelidir; çözme anahtarına yalnızca yetkili yönetici erişebilir.
- Yönetici hesapları iki aşamalı doğrulamayla korunur; yöneticiler yalnızca görevleri için gereken verilere erişir. Uygulama içi mesajları görüntülemek için gerekçe girilmesi zorunludur ve her erişim kaydedilir.
- Bir veri ihlali hâlinde Kurul''a ve etkilenen kişilere KVKK m.12/5 uyarınca en kısa sürede (Kurul''a en geç 72 saat içinde) bildirim yapılır.

Hiçbir sistem için mutlak güvenlik garantisi verilemez.

## 11. Ödeme bilgileri

HizmetCep üzerinden ödeme yapılmaz. Kredi kartı, banka kartı veya banka hesap bilgisi hiçbir aşamada istenmez, işlenmez ve saklanmaz. Hizmet bedeli kullanıcılar arasında, Platform dışında ödenir. İleride ödeme özelliği eklenirse kart verileri yalnızca 6493 sayılı Kanun kapsamında lisanslı bir ödeme kuruluşu tarafından işlenir ve bu politika önceden güncellenir.

## 12. Saklama süreleri

- Doğrulama kodları: 1 gün.
- Oturum kayıtları (IP, cihaz): oturum sona erdikten sonra 30 gün.
- Trafik kayıtları (5651): 1 yıl; hesap silinse de.
- Yasal kimlik arşivi (silinen hesabın ad, telefon, e-postası): silmeden itibaren 1 yıl.
- Hesap, profil ve hizmet içerikleri: hesap açık olduğu sürece.
- Şikâyet kayıtları: sonuçlandırmadan itibaren 2 yıl.
- SMS ve e-posta gönderim kayıtları: 2 yıl.
- Üye olmayanların destek e-postaları: talebin kapanmasından itibaren 2 yıl.
- Ticari ileti onay ve ret kayıtları: iznin sona ermesinden itibaren 3 yıl (ispat için).
- Sözleşme onay, yönetici işlem kayıtları, hesap durumu geçmişi: hesap silindikten sonra 10 yıl; kişisel alanlar maskelenir.
- Sunucu hata kayıtları (kişisel veri içermez): 30 gün.
- Şifreli veritabanı yedekleri: 14 gün.

Süre sonunda veriler silinir, yok edilir veya anonim hâle getirilir.

## 13. Hesabı dondurma ve silme

Hesabınızı Hesap Ayarları''ndan dondurabilir veya silebilirsiniz. Silme için şifreli hesapta şifreniz, Google/Apple hesabında aynı sağlayıcıyla yeniden giriş istenir. Talep 30 gün sonra uygulanır ve bu sürede iptal edilebilir. Silinen veriler ve silmenin kanuni istisnaları Kullanım Sözleşmesi''nin 15. maddesinde ayrıntılı olarak yazılıdır. Silinen veriler yedeklerden en geç 14 gün içinde silinir.

## 14. Yaş sınırı

HizmetCep 18 yaşını doldurmuş kişilere yöneliktir; çocuklardan bilerek veri toplanmaz. 18 yaş altı bir kişinin üye olduğu fark edilirse hesap kapatılır ve verileri silinir.

## 15. Haklarınız ve başvuru

KVKK m.11''deki haklarınız ve başvuru yolları KVKK Aydınlatma Metni''nin 8. ve 9. maddelerindedir. Başvurular onur@hizmetcep.com adresine yapılabilir ve en geç 30 gün içinde ücretsiz sonuçlandırılır.

## 16. Değişiklikler

Politika güncellendiğinde yeni sürüm, sürüm numarası ve yürürlük tarihiyle uygulamada ve web sitesinde yayımlanır. Verilerin yeni bir amaca veya yeni bir yurt dışı sağlayıcıya aktarılması gibi esaslı değişiklikler uygulama içinde ayrıca duyurulur.',
       'a6449284d64a569b403b59b59a0959dc227e485ccb57fdf3cfdea91ea448ef99', '2026-11-06', 'PUBLISHED', NULL, '2026-11-06T09:00:00.000Z', NULL, '2026-11-06T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'privacy')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-06112026f003');
