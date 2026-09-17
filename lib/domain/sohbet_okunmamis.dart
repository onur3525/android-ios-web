import '../data/models/chat.dart';

/// ── ⚠ İLAN AKIŞINDA OKUNMAMIŞ MESAJ — TEK SAYIM ──
///
/// ⚠ KULLANICI İSTEĞİ (12 Eyl): "İki taraf birbirine mesaj
/// gönderdiğinde sadece bildirim ile değil, mesaj kartları üzerinde
/// de mesaj geldiğini gösteren bir şeyler konulmalı."
///
/// Bul akışında bu sayım zaten vardı (`okunmamisMesajSayisi`,
/// `domain/teklif_talebi_asamasi.dart`) ve üç kartta kullanılıyordu.
/// İlan akışında (teklif üzerinden yürüyen sohbet) HİÇ YOKTU: iki
/// taraf da yalnız bildirimden haberdar oluyordu.
///
/// ⚠ AYNI KURAL, AYRI FONKSİYON: iki akış farklı mesaj modeli
/// kullanıyor (`ChatMessage` / `TeklifMesaj`) ve ortak bir arayüzleri
/// yok. Tek bir fonksiyonda birleştirmek için modellerden birini
/// ötekine uydurmak gerekirdi — o, gösterim için veri modelini
/// bozmak olurdu. Kural aynı, gövde ayrı.
///
/// ⚠ KENDİ MESAJIN SAYILMAZ: "okunmamış" karşı tarafın gönderip
/// senin görmediğin mesajdır.
///
/// ⚠ OKUNDU İŞARETİ SOHBET AÇILINCA KONUR (`ChatController.openThread`
/// → `markRead`); bu fonksiyon yalnız OKUR, durumu değiştirmez.
///
/// [mesajlar] `null` ya da boşsa 0 döner — sohbet hiç başlamamıştır.
int okunmamisSohbetMesaji(List<ChatMessage>? mesajlar, String benimId) =>
    mesajlar
        ?.where((m) => m.senderId != benimId && m.status != MessageStatus.read)
        .length ??
    0;
