-- 020 — Gizlilik Politikası metni (15 Eki, kullanıcı isteği). postgres/020 ile BİREBİR.
--
-- Kullanıcı metnin kodla Gizlilik Politikası'na eklenmesini istedi (015 ile
-- aynı yöntem); sonraki sürümler admin panelinden (Yasal → Gizlilik
-- Politikası → Yeni sürüm → Yayınla) girilir.
-- Kaynak: "HizmetCep Hukuki Metinler Yayın Öncesi Taslak", yalnız BELGE 1
-- (madde 1–12), metin değiştirilmeden; yalnız sürüm/yürürlük satırı alana
-- taşındı (sürüm ve yürürlük tarihi ekranda alanlardan gösterilir).
-- sha256 = admin ucunun hesapladığıyla aynı (gövde trim).
--
-- ⚠ YALNIZ 'privacy' BELGESİ VARSA: boş veritabanında (testler) belge kaydı
-- tohumlamayla migration'dan SONRA oluşur; o zaman hiçbir şey eklenmez.
-- ⚠ Önceki yayındaki sürüm SİLİNMEZ, ARCHIVED olur (admin yayınlamasıyla aynı).
-- Belge onay isteyen bir belge olduğundan kullanıcılar yeni sürümü yeniden onaylar.

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'privacy' AND status = 'PUBLISHED'
   AND EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'privacy');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-15102026a002', 'privacy',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'privacy'),
       '## 1. Veri sorumlusu

HizmetCep''in işletmecisi ve kişisel veriler bakımından veri sorumlusu, bu belgede belirtilen kapsamda Onur Bütün''dür. Adres: 1847/2 Sokak, No: 25, Daire: 1, Örnekköy, Karşıyaka / İzmir. E-posta: onur_butun@hotmail.com. Bu bilgilerin yayımdan önce doğrulanması gerekir.

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

İlgili kişiler 6698 sayılı Kanun''un 11. maddesindeki hakları için onur_butun@hotmail.com adresine veya yukarıdaki posta adresine başvurabilir. Başvurular mevzuattaki usul ve sürelerde değerlendirilir; gerekli kimlik doğrulaması yapılabilir. Başvuru kanalları ve usulü yayımdan önce doğrulanmalıdır.

## 12. Güncellemeler

Hizmet veya mevzuat değişikliklerinde politika güncellenebilir. Önemli değişiklikler kullanıcıya uygun yöntemle bildirilir; gerektiğinde yeniden onay veya ayrı açık rıza alınır. Güncel sürüm ve yürürlük tarihi gösterilmelidir.',
       'fdae443595b9f08c54f3bd6da1b9a4fcb51ce481c07e617ddbb422c02c55000d', '2026-10-15', 'PUBLISHED', NULL, '2026-10-15T18:20:00.000Z', NULL, '2026-10-15T18:20:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'privacy');
