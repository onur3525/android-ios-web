-- 023 — KVKK Aydınlatma Metni (16 Eki, kullanıcı isteği). sqlite/023 ile BİREBİR.
--
-- Kullanıcı "HizmetCep Kişisel Verilerin İşlenmesi Hakkında Aydınlatma
-- Metni" (16.10.2026) belgesinin Aydınlatma Metni'ne eklenmesini istedi;
-- kayıt ekranındaki "Aydınlatma Metni" bağlantısı bu belgeyi ('kvkk') açar.
-- Metin değiştirilmeden; yalnız başlık, tarih satırı (yürürlük alanına
-- taşındı) ve en alttaki "HizmetCep • Aydınlatma Metni • Taslak" satırı
-- metne girmez. Başlıklar diğer yasal metinlerle aynı biçimde (##).
-- sha256 = admin ucunun hesapladığıyla aynı (gövde trim).
--
-- ⚠ YALNIZ 'kvkk' BELGESİ VARSA: boş veritabanında (testler) belge kaydı
-- tohumlamayla migration'dan SONRA oluşur; o zaman hiçbir şey eklenmez.
-- ⚠ Önceki yayındaki sürüm SİLİNMEZ, ARCHIVED olur (admin yayınlamasıyla aynı).

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'kvkk' AND status = 'PUBLISHED'
   AND EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'kvkk');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-16102026a004', 'kvkk',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'kvkk'),
       'Bu metin, 6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) kapsamında HizmetCep kullanıcılarını kişisel verilerinin işlenmesi hakkında bilgilendirmek amacıyla hazırlanmıştır. Yayımdan önce fiilî veri işleme süreçleriyle karşılaştırılmalıdır.

## 1. Veri Sorumlusu ve İletişim Bilgileri

Veri sorumlusu: Onur Bütün
Adres: 1847/2 Sokak No: 25, Daire: 1, Örnekköy, Karşıyaka/İzmir
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
       'c295c1bf218d25ea5faeae1330d29d0bd8a83887570a289699232d8a1eb94010', '2026-10-16', 'PUBLISHED', NULL, '2026-10-16T08:30:00.000Z', NULL, '2026-10-16T08:30:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'kvkk');
