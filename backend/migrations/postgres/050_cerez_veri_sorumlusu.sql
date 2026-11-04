-- 050 — ÇEREZ POLİTİKASI: VERİ SORUMLUSU BİLGİLERİ AYDINLATMA METNİYLE AYNI
-- (4 Kas, işletmeci talimatı). sqlite/050 ile BİREBİR.
--
-- Aydınlatma Metni'ndeki (047) veri sorumlusu bölümü:
--   Veri sorumlusu: Onur Bütün (Bütün Mühendislik) · Adres: İzmir/Türkiye ·
--   E-posta: onur@hizmetcep.com
-- Çerez Politikası'nda (036) ad eksik, adres yok ve eski e-posta
-- (onur_butun@hotmail.com) duruyordu; 6. bölümdeki başvuru adresi de
-- güncellenir. Metnin geri kalanı AYNI.
--
-- ⚠ GÜVENLİK KİLİDİ (036/040/047 ile aynı): yalnız yayımdaki sürüm 036'nın
-- yayımladığı metnin AYNISIYSA (sha256) değiştirilir; panelden başka sürüm
-- yayımlanmışsa belgeye DOKUNULMAZ. Eski sürüm silinmez, ARCHIVED olur.
-- Çerez Politikası onay istemez; kullanıcılardan yeniden onay istenmez.

UPDATE legal_versions SET status = 'ARCHIVED'
 WHERE slug = 'cookies' AND status = 'PUBLISHED' AND sha256 = '877ea68b9b87a5e82d59396c2ff608d2d900a15f08a6eed2fdb149caacf41936'
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-04112026d001');

INSERT INTO legal_versions (id, slug, version, body, sha256, effective_date, status, created_by, created_at, published_by, published_at)
SELECT '7b0e6f2a-3c1d-4e5f-9a8b-04112026d001', 'cookies',
       (SELECT COALESCE(MAX(version), 0) + 1 FROM legal_versions WHERE slug = 'cookies'),
       'Bu Çerez Politikası, HizmetCep web sitesini ve web uygulamasını kullanırken tarayıcınızda saklanan çerezler ve benzeri teknolojiler (tarayıcı deposu) hakkında 6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında sizi bilgilendirmek amacıyla hazırlanmıştır.

## 1. Veri Sorumlusu

Veri sorumlusu: Onur Bütün (Bütün Mühendislik)
Adres: İzmir/Türkiye
E-posta: onur@hizmetcep.com

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

KVKK''nın 11. maddesindeki haklarınıza ilişkin taleplerinizi onur@hizmetcep.com adresine iletebilirsiniz. Ayrıntılı bilgi için Aydınlatma Metni''ni inceleyebilirsiniz.

## 7. Güncellemeler

Kullanılan çerez veya depolarda değişiklik olursa bu politika güncellenir ve güncel sürüm web sitesinde yayımlanır.',
       'f640918e57d013cc701294212c54a1c4565662ac43a7c5cc17b95b4bb239efc1', '2026-11-04', 'PUBLISHED', NULL, '2026-11-04T09:00:00.000Z', NULL, '2026-11-04T09:00:00.000Z'
 WHERE EXISTS (SELECT 1 FROM legal_documents WHERE slug = 'cookies')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE id = '7b0e6f2a-3c1d-4e5f-9a8b-04112026d001')
   AND NOT EXISTS (SELECT 1 FROM legal_versions WHERE slug = 'cookies' AND status = 'PUBLISHED');
