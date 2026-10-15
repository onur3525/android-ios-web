-- 015 — Kullanım Koşulları test sürümü metni (15 Eki, kullanıcı isteği). postgres/015 ile BİREBİR.
--
-- Kullanıcı bu defalık metnin kodla konmasını istedi; sonraki sürümler admin
-- panelinden (Yasal → Kullanım Koşulları → Yeni sürüm → Yayınla) girilir.
-- Kaynak: "HizmetCep Hukuki Metinler Test Taslağı", yalnız BELGE 1 (madde 1–17),
-- metin değiştirilmeden. sha256 = admin ucunun hesapladığıyla aynı (gövde trim).
--
-- ⚠ YALNIZ 'terms' BELGESİ VARSA: boş veritabanında (testler) belge kaydı
-- tohumlamayla migration'dan SONRA oluşur; o zaman hiçbir şey eklenmez.
-- ⚠ Önceki yayındaki sürüm SİLİNMEZ, ARCHIVED olur (admin yayınlamasıyla aynı).
-- Belge onay isteyen bir belge olduğundan kullanıcılar yeni sürümü yeniden onaylar.

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'terms' AND status = 'PUBLISHED'
   AND EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-15102026a001', 'terms',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'terms'),
       'Bu koşullar, test sürümü kullanıcılarına gösterilip kabul ettirildiği tarihten itibaren geçerli olmak üzere hazırlanmıştır.

## 1. Taraflar ve kapsam

Bu koşullar, HizmetCep test sürümünü sunan gerçek kişi işletmeci Onur Bütün ile uygulamayı kullanan kişi arasındaki kullanım şartlarını düzenler. İletişim: onur_butun@hotmail.com. Adres: 1847/2 Sokak, No: 25, Daire: 1, Örnekköy, Karşıyaka / İzmir.

## 2. Platformun niteliği

HizmetCep, hizmet talep eden kişilerle hizmet sunmak isteyen kişileri dijital ortamda buluşturmayı amaçlar. İşletmeci, aksi açıkça belirtilmedikçe, kullanıcılar arasındaki hizmetin doğrudan sağlayıcısı değildir. Bu açıklama, kanundan doğan sorumlulukları ortadan kaldırmaz; platformun hukuki niteliği fiilî işleyiş ve yürürlükteki mevzuata göre değerlendirilir.

## 3. Test erişimi ve bölge

Test sürümü, işletmecinin belirlediği kullanıcılarla sınırlıdır ve ilk aşamada İzmir odaklıdır. Test ortamında hata, kesinti veya değişiklik yaşanabilir. Kullanıcılar gerçek kişilere ait gereksiz ya da hassas bilgileri test amacıyla yüklememelidir.

## 4. Ücret

Test aşamasında HizmetCep ücretsizdir. Bu, gelecekteki tüm özelliklerin daima ücretsiz olacağı taahhüdü değildir. İleride ücretli özellik sunulursa ücret ve kapsam önceden açıkça bildirilir ve gereken durumlarda ayrıca onay alınır.

## 5. Üyelik ve hesap güvenliği

Kullanıcı kayıt sırasında doğru ve güncel bilgi vermeli, telefon/SMS doğrulamasını kendisi tamamlamalı ve hesabını korumalıdır. Hesap başkasına kullandırılamaz; başka kişilerin hesaplarına izinsiz erişilemez.

## 6. Yaş

İşletmeciye, ilk test aşamasında yalnızca 18 yaşını doldurmuş kullanıcıların kabul edilmesi önerilir. Bu kural işletmeci tarafından onaylanıp uygulamada uygulanmadan kesinleşmiş sayılmaz. 18 yaş altı kullanıcılar kabul edilecekse sözleşme ehliyeti, veli/vasinin rolü, çocukların kişisel verileri ve güvenlik ayrıca hukuki incelemeye tabi tutulmalıdır.

## 7. Profil, ilan ve kullanıcı içeriği

Kullanıcı; profil, fotoğraf, ilan, hizmet kategorisi ve mesajlarda paylaştığı içeriğin doğruluğundan ve paylaşma hakkına sahip olmasından sorumludur. Hukuka aykırı, yanıltıcı, tehditkâr, taciz edici, dolandırıcılık amaçlı veya başkalarının haklarını ihlal eden içerikler yasaktır. Başkasına ait fotoğraf veya iletişim bilgileri gerekli izin olmadan yüklenmemelidir.

## 8. Kullanıcılar arası hizmet

Hizmet Alan ve Hizmet Veren; işin kapsamı, fiyatı, zamanı, ödeme, gerekli izinler ve hizmetin yerine getirilmesine ilişkin hususları kendi aralarında netleştirmelidir. Kullanıcılar diğer tarafın kimliğini, yetkinliğini ve koşullarını değerlendirmelidir. İşletmecinin kanuni sorumlulukları saklıdır.

## 9. İletişim bilgileri ve mesajlar

Telefon ve e-posta bilgilerinin paylaşılması, ilgili işlemde tarafların onayına bağlı olacak şekilde tasarlanmıştır; gerçek davranış kod ve arayüz üzerinden doğrulanmalıdır. Kullanıcılar diğer kişilerin iletişim bilgilerini izinsiz yayımlayamaz veya başka amaçla kullanamaz. Yetkili yönetici, şikâyet, güvenlik, kötüye kullanım incelemesi veya hukuki yükümlülükler için mesajlara gerekli ölçüde erişebilir; erişim yetkileri sınırlandırılmalıdır.

## 10. Yasaklanan davranışlar

Sahte profil, dolandırıcılık, spam, tehdit, taciz, yasa dışı hizmet teklifi, güvenlik önlemlerini aşma, zararlı yazılım yükleme, başkasının hesabına erişme ve kişisel verileri izinsiz toplama veya dağıtma yasaktır.

## 11. Şikâyet ve hesap kısıtlamaları

Şikâyetler uygulamadaki kanallar veya e-posta üzerinden iletilebilir. Makul güvenlik veya hukuka aykırılık gerekçesi varsa içerik incelemeye alınabilir, görünürlüğü sınırlandırılabilir veya hesap geçici olarak kısıtlanabilir ya da sonlandırılabilir. İşlemler ölçülü yürütülür; kanuni haklar saklıdır.

## 12. Fikrî mülkiyet

HizmetCep yazılımı, markası, tasarımı ve işletmeciye ait içerikler üzerindeki haklar ilgili hak sahiplerine aittir. Kullanıcı, yüklediği içeriğin haklarını saklı tutar; içeriğin platformda gösterilmesi ve hizmetin işletilmesi için gerekli sınırlı kullanım iznini verir.

## 13. Erişilebilirlik ve sorumluluk

Test sürümü geçici olarak durabilir veya değiştirilebilir; kesintisiz ve hatasız hizmet garantisi verilmez. Bu hüküm, emredici mevzuattan doğan hakları veya kanunen sınırlandırılamayan sorumlulukları ortadan kaldırmaz.

## 14. Hesap silme

Kullanıcı uygulamadaki hesap silme işleviyle talepte bulunabilir. Hesap ve ilişkili kişisel veriler teknik olarak mümkün olduğu ölçüde silinir veya anonimleştirilir. Kanunen saklanması gereken kayıtlar ve devam eden uyuşmazlıklar için gerekli veriler sınırlı süreyle tutulabilir. Yedek kopyaların silinme süresi teknik olarak belirlenip kullanıcıya açıklanmalıdır.

## 15. Kişisel veriler

Kişisel veri işleme ayrıntıları KVKK Aydınlatma Metni ve Gizlilik Politikası''nda açıklanır. Kullanım koşullarının kabulü, gerekli olduğu hâllerde açık rıza yerine geçmez.

## 16. Güncelleme ve hukuk

Koşullar mevzuat veya hizmet değişiklikleri nedeniyle güncellenebilir. Önemli değişiklikler kullanıcıya bildirilir ve gerektiğinde yeniden onay alınır. Türkiye Cumhuriyeti hukuku uygulanır; görevli merciler ve zorunlu başvuru yolları mevzuata göre belirlenir.

## 17. İletişim

Onur Bütün, 1847/2 Sokak, No: 25, Daire: 1, Örnekköy, Karşıyaka / İzmir. E-posta: onur_butun@hotmail.com.',
       '24f85d855a960c3522c717419ff9185f5480109f711bc53cdf1c3764ca4ab551', '2026-10-15', 'PUBLISHED', NULL, '2026-10-15T12:50:00.000Z', NULL, '2026-10-15T12:50:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'terms');
