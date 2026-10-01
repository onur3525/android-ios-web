// ═══════════════════════════════════════════════════════════════
// FIREBASE MESSAGING SERVİS ÇALIŞANI — web push (arka plan / kapalı sekme)
// fcm_web.js tarafından base-href'e GÖRELİ kaydedilir.
// ═══════════════════════════════════════════════════════════════

// ⚠ Tıklama işleyicisi Firebase'den ÖNCE kaydedilir: bildirime
// dokunulunca açık uygulama sekmesi öne getirilir (yoksa açılır) ve
// bildirim verisi uygulamaya iletilir; yönlendirmeyi uygulama yapar
// (güvenli hedef tablosu: lib/ui/push_kapisi.dart).
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.stopImmediatePropagation();
  const ham = e.notification.data || {};
  const veri = (ham.FCM_MSG && ham.FCM_MSG.data) || ham.data || {};
  const taban = self.registration.scope.replace(/firebase-cloud-messaging-push-scope\/?$/, '');
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((liste) => {
    for (const c of liste) {
      if (c.url.startsWith(taban)) {
        c.postMessage({ hcPushAcildi: veri });
        return c.focus();
      }
    }
    return self.clients.openWindow(`${taban}?hc_push=${encodeURIComponent(JSON.stringify(veri))}`);
  }));
});

importScripts('fcm_yapilandirma.js');
const cfg = self.HC_FCM_YAPILANDIRMA;
if (cfg && cfg.firebase && cfg.firebase.appId && cfg.firebase.apiKey) {
  importScripts(
    'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js',
  );
  firebase.initializeApp(cfg.firebase);
  // `notification` içeren mesajları Firebase arka planda kendisi gösterir.
  firebase.messaging();
}
