// ═══════════════════════════════════════════════════════════════
// WEB PUSH KÖPRÜSÜ (Flutter ⇄ Firebase JS) — lib/core/push/push_platform_web.dart
//
// Servis çalışanı base-href'e GÖRELİ kaydedilir:
//   /android-ios-web/firebase-messaging-sw.js
//   kapsam: /android-ios-web/firebase-cloud-messaging-push-scope
// Flutter'ın kendi servis çalışanının (kapsam ./) yerine GEÇMEZ.
// Jeton uygulama tarafında yalnız bellekte tutulur.
// ═══════════════════════════════════════════════════════════════
const SURUM = '10.12.2';
const cfg = self.HC_FCM_YAPILANDIRMA;
let messaging = null;
let kayit = null;
let api = null;

window.hcFcm = {
  async baslat(olay) {
    try {
      if (!cfg || !cfg.firebase.appId || !cfg.firebase.apiKey) return false;
      if (!('serviceWorker' in navigator) || !('Notification' in window)) return false;
      const app = await import(`https://www.gstatic.com/firebasejs/${SURUM}/firebase-app.js`);
      api = await import(`https://www.gstatic.com/firebasejs/${SURUM}/firebase-messaging.js`);
      if (!(await api.isSupported())) return false;
      messaging = api.getMessaging(app.initializeApp(cfg.firebase, 'hc-fcm'));
      const taban = document.baseURI;
      kayit = await navigator.serviceWorker.register(new URL('firebase-messaging-sw.js', taban), {
        scope: new URL('firebase-cloud-messaging-push-scope', taban).pathname,
      });
      api.onMessage(messaging, (p) => olay('mesaj', JSON.stringify({
        ...(p.data || {}), _baslik: p.notification?.title, _govde: p.notification?.body,
      })));
      navigator.serviceWorker.addEventListener('message', (e) => {
        if (e.data && e.data.hcPushAcildi) olay('acildi', JSON.stringify(e.data.hcPushAcildi));
      });
      return true;
    } catch (e) {
      console.warn('HC_FCM baslatilamadi', e && e.name);
      return false;
    }
  },
  async izinVeToken() {
    if (!messaging) return null;
    try {
      const izin = await Notification.requestPermission();
      if (izin !== 'granted') return null;
      return await api.getToken(messaging, { vapidKey: cfg.vapidKey, serviceWorkerRegistration: kayit });
    } catch (e) {
      console.warn('HC_FCM jeton alinamadi', e && e.name);
      return null;
    }
  },
  async tokenSil() {
    try { if (messaging) await api.deleteToken(messaging); } catch (_) { /* yoksay */ }
  },
};
