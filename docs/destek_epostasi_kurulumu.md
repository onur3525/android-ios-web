# Destek e-postaları → Admin › Gelen Talepler

Kullanıcılar uygulamadaki Destek Merkezi'nden destek adresine e-posta yazar.
Bu adrese gelen her e-posta Admin › Gelen Talepler'de bir talep olarak açılır;
yönetici yanıtı e-postayı gönderen adrese gider, kişinin bu e-postaya yanıtı
aynı talebe eklenir (konudaki "Talep No").

Akış: destek@hizmetcep.com → Resend Receiving → `POST /webhooks/resend/inbound`
(Svix imzası doğrulanır) → e-postanın tamamı Resend API'sinden okunur → talep.

## Kurulum (bir kez)

1. **Resend › Domains › hizmetcep.com › Receiving'i etkinleştir.** Resend bir
   MX kaydı verir (ad: `@` ya da boş, değer: Resend'in gösterdiği adres,
   öncelik: Resend'in gösterdiği sayı).
2. **Netlify › hizmetcep.com › DNS** bölümüne bu MX kaydını ekle.
   ⚠ hizmetcep.com'a gelen BÜTÜN e-postalar Resend'e gider; bu alan adında
   başka bir posta kutusu kullanılmamalıdır.
3. **Resend › Webhooks › Add endpoint**
   - Adres: `https://<backend adresi>/webhooks/resend/inbound`
     (bugün: `https://hizmetcep-backend.onrender.com/webhooks/resend/inbound`)
   - Olay: yalnız `email.received`
4. Oluşan webhook'un **Signing secret** değerini (`whsec_…`) kopyala.
5. **Admin › Entegrasyonlar** › E-posta (resend) satırı › **Gelen e-posta
   anahtarı** › değeri yapıştır. Değer şifreli saklanır, bir daha gösterilmez;
   API anahtarı değiştirilince silinmez.
6. **Admin › Destek Bilgisi** e-posta adresi `destek@hizmetcep.com` olmalı.
   Uygulamada gösterilen adres ve yanıt e-postalarının "Yanıtla" adresi budur.
7. Deneme: kişisel bir adresten destek@hizmetcep.com'a e-posta gönder;
   birkaç saniye içinde Gelen Talepler'de görünmeli.

## Davranış

- Aynı e-posta iki kez bildirilse de ikinci kayıt açılmaz.
- Gönderen kayıtlı bir kullanıcının e-postasıysa talep o kullanıcıya bağlanır.
- Otomatik yanıtlar (Auto-Submitted), mailer-daemon ve kendi gönderen
  adresimizden gelenler kayda girmez; gönderen başına saatte en fazla 20 talep.
- Kapatılmış talebe e-postayla yanıt gelirse talep yeniden "Yanıt bekliyor" olur.
- Anahtar girilmemişse webhook 503 döner; Resend daha sonra yeniden dener.
