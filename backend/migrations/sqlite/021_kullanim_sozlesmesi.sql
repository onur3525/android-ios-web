-- 021 — Kullanım Sözleşmesi metni (16 Eki, kullanıcı isteği). postgres/021 ile BİREBİR.
--
-- Kullanıcı kayıtta zorunlu onaylanan sözleşmeyi ("HizmetCep Kullanım
-- Sözleşmesi", taslak sürüm 1.2, 16.10.2026) ekletti. Kayıt ekranının
-- bağladığı ve kayıtta onaylanan belge 'terms'tür; metin onun yeni sürümü
-- olarak yayınlanır (015/020 ile aynı yöntem). Kaynak belgedeki yalnız
-- "BÖLÜM A — KULLANIM SÖZLEŞMESİ" (madde 1–21), metin değiştirilmeden;
-- başlık, taslak notu ve "BÖLÜM B" uygulama talimatı metne girmez.
-- sha256 = admin ucunun hesapladığıyla aynı (gövde trim).
-- Belgenin adı da "Kullanım Sözleşmesi" olur (yeni ad belgeden).
--
-- ⚠ YALNIZ 'terms' BELGESİ VARSA: boş veritabanında (testler) belge kaydı
-- tohumlamayla migration'dan SONRA oluşur; o zaman hiçbir şey eklenmez.
-- ⚠ Önceki yayındaki sürüm SİLİNMEZ, ARCHIVED olur (admin yayınlamasıyla aynı).
-- Belge onay isteyen bir belge olduğundan mevcut kullanıcılar yeni sürümü yeniden onaylar.

UPDATE legal_documents SET title = 'Kullanım Sözleşmesi' WHERE slug = 'terms';

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'terms' AND status = 'PUBLISHED'
   AND EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-16102026a003', 'terms',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'terms'),
       '## 1. Taraflar ve tanımlar

İşbu Kullanım Sözleşmesi (“Sözleşme”), HizmetCep isimli dijital platformu işleten Onur Bütün (“İşletmeci”) ile HizmetCep’e kayıt olan veya platformu kullanan gerçek kişi (“Kullanıcı”) arasında, Kullanıcı’nın elektronik ortamda Sözleşme’yi kabul etmesiyle yürürlüğe girer.

İşletmeci iletişim bilgileri: Onur Bütün, 1847/2 Sokak No: 25, Daire: 1, Örnekköy, Karşıyaka/İzmir. E-posta: onur_butun@hotmail.com.

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
       '4343d06fb46bf8fe93d49f79b0f6aaa313fb67f81b13faff76d9e6661cd19e4d', '2026-10-16', 'PUBLISHED', NULL, '2026-10-16T01:30:00.000Z', NULL, '2026-10-16T01:30:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms');
