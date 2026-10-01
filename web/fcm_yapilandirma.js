// ═══════════════════════════════════════════════════════════════
// FIREBASE WEB PUSH YAPILANDIRMASI — yalnız GENEL (gizli olmayan) değerler
//
// Firebase web uygulaması: 1:262578778971:web:9e7e25bb909ab7720b207e
// (Firebase Console → Proje ayarları → Web). `apiKey`/`appId` boş
// bırakılırsa web push KAPALI kalır; uygulama etkilenmez.
// ⚠ `measurementId` (Google Analytics) BİLEREK eklenmedi: uygulamada
// analitik yok; eklenirse kullanıcı izni/KVKK değerlendirmesi gerekir.
//
// ⚠ BURAYA ASLA GİZLİ ANAHTAR YAZILMAZ: VAPID ÖZEL anahtarı ve servis
// hesabı anahtarı yalnız sunucuda durur. `vapidKey` GENEL anahtardır.
// ═══════════════════════════════════════════════════════════════
self.HC_FCM_YAPILANDIRMA = {
  firebase: {
    apiKey: 'AIzaSyCr9t1Ywo6G5Dep944wEvs_QVeUlu2pG8g',
    appId: '1:262578778971:web:9e7e25bb909ab7720b207e',
    projectId: 'hizmetcep-fe036',
    messagingSenderId: '262578778971',
    authDomain: 'hizmetcep-fe036.firebaseapp.com',
    storageBucket: 'hizmetcep-fe036.firebasestorage.app',
  },
  vapidKey: 'BC7LYvpu6ESlnwkmliH_7Wviz9-Q55LIxLvsBNIZ3hzDqFNfEhYOvA-FJanr83JVTVj4uYb8WfNhJ5zKV82l2No',
};
