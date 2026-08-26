package com.hizmetcep.app

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.view.WindowManager
import android.util.Log
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * ÖDEME DÖNÜŞÜ — DERİN BAĞLANTI KÖPRÜSÜ (Android)
 *
 * Dart tarafı ile sözleşme:
 *   MethodChannel("hizmetcep/deeplinks")        → getInitialLink
 *   EventChannel ("hizmetcep/deeplinks/events") → sonraki bağlantılar
 *
 * Yakalanan durumlar:
 *   • Uygulama KAPALIYKEN  → açılış intent'i, getInitialLink ile TEK SEFER
 *   • ARKA PLANDAYKEN      → onNewIntent (manifest'te launchMode=singleTop)
 *   • ÖN PLANDAYKEN        → onNewIntent
 *
 * GÜVENLİK:
 *   • Yalnız `hizmetcep://payment...` kabul edilir; başka şema/host yok sayılır.
 *   • URI'deki "success"/"status" gibi alanlara GÜVENİLMEZ ve Dart'a
 *     ayrıca iletilmez; yalnız bağlantının kendisi taşınır. Ödemenin
 *     sonucunu her zaman backend `confirmTopup` belirler.
 *   • Aynı bağlantı iki kez iletilmez (duplicate callback koruması).
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "HizmetCepDeepLink"
        private const val METHOD_CHANNEL = "hizmetcep/deeplinks"
        private const val EVENT_CHANNEL = "hizmetcep/deeplinks/events"

        /**
         * KART TOKENİZASYON KANALI
         *
         * Dart tarafı (`card_tokenization_bridge.dart`) bu kanala
         * `ping` ve `tokenize` çağrıları yapar.
         *
         * ⚠ ŞU AN ADAPTÖR BAĞLI DEĞİL: ödeme sağlayıcısı seçilmediği
         * için `ping` false döner ve Dart tarafı
         * `UnconfiguredCardTokenizer` kullanır.
         *
         * Sağlayıcı seçildiğinde yapılacak: `tokenize` içinde sağlayıcının
         * Android SDK'sı çağrılır ve tek kullanımlık `paymentToken`
         * döndürülür. Dart tarafında HİÇBİR dosya değişmez.
         */
        private const val CARD_TOKENIZER_CHANNEL = "hizmetcep/card_tokenizer"

        /**
         * SPLASH KANALI
         *
         * Dart, açılış kararı (oturum + config) hazır olduğunda
         * `bootReady` çağırır. Native splash o ana kadar ekranda
         * kalır; böylece kullanıcı İKİNCİ bir Flutter splash'ı
         * GÖRMEZ — ilk görünen Flutter karesi doğrudan hedef ekrandır.
         */
        private const val SPLASH_CHANNEL = "hizmetcep/splash"

        /**
         * EKRAN KORUMASI KÖPRÜSÜ
         *
         * Dart tarafı hassas ekrana girerken açar, çıkarken kapatır.
         */
        private const val SECURE_CHANNEL = "hizmetcep/ekran_korumasi"

        /** CİHAZ BÜTÜNLÜĞÜ KÖPRÜSÜ — root / hata ayıklayıcı / öykünücü. */
        private const val INTEGRITY_CHANNEL = "hizmetcep/cihaz_butunlugu"

        /** Splash'ın ekranda kalacağı EN KISA süre (ms). */
        private const val SPLASH_MIN_MS = 2000L

        /**
         * Splash'ın ekranda kalabileceği EN UZUN süre (ms) — FAIL-SAFE.
         *
         * ⚠ KRİTİK: splash'ın görünürlüğü `bootReady` sinyaline
         * SINIRSIZ bağlanamaz. Dart tarafında beklenmeyen bir hata
         * oluşur, MethodChannel kurulmaz veya sinyal kaçarsa koşul
         * sonsuza dek `true` döner ve uygulama splash'ta KİLİTLENİR
         * (gerçek cihazda görülen hata buydu).
         *
         * Bu üst sınır dolduğunda splash KOŞULSUZ bırakılır; kalan
         * yükleme/karar durumu Flutter içinde güvenle yönetilir.
         */
        private const val SPLASH_MAX_MS = 5000L

        /** Sağlayıcı SDK adaptörü bağlandığında `true` yapılır. */
        private const val CARD_TOKENIZER_READY = false
        private const val SCHEME = "hizmetcep"
        private const val HOST_PAYMENT = "payment"
    }

    /** Dart açılış kararını verdi mi? */
    @Volatile
    private var bootReady = false

    // ── AÇILIŞ ÖLÇÜMÜ (YALNIZ DEBUG) ──
    //
    // ⚠ Davranış DEĞİŞMEZ: yalnız log yazılır. Splash koşulu, süreler
    // ve sıralama aynen korunur.
    //
    // Etiket ve biçim Dart tarafıyla AYNIDIR:
    //     HC_BOOT +0000ms NATIVE_ON_CREATE
    // Böylece tek `grep HC_BOOT` ile iki taraf birlikte okunur.
    //
    // ⚠ İKİ AYRI SIFIR NOKTASI: burada sıfır `onCreate`, Dart'ta
    // `main()` girişidir. Korelasyon şu çiftle kurulur (aynı an):
    //     NATIVE_BOOT_READY_RECEIVED  ↔  NATIVE_BOOT_READY_SENT
    private var minLoglandi = false
    private var maxLoglandi = false
    private var birakmaLoglandi = false

    /** Bu derleme debuggable mı? (`BuildConfig` AGP 8'de üretilmeyebilir.) */
    private val debugDerleme: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    private fun bootLog(olay: String) {
        if (!debugDerleme) return
        val ms = SystemClock.uptimeMillis() - basladi
        Log.i("HC_BOOT", "HC_BOOT +" + ms.toString().padStart(4, '0') + "ms " + olay)
    }

    /** Activity'nin oluşturulma anı — en kısa splash süresi buradan sayılır. */
    private var basladi = 0L

    /** Açılışa neden olan bağlantı; Dart bir kez okur ve tüketir. */
    private var initialLink: String? = null
    private var initialLinkConsumed = false

    private var eventSink: EventChannel.EventSink? = null

    /** Duplicate koruması: iletilen bağlantılar. */
    private val delivered = mutableSetOf<String>()

    /**
     * TEK GÖRÜNÜR SPLASH
     *
     * `installSplashScreen()` API 21+ ile API 31+ arasında aynı yüzeyi
     * verir. Splash, ŞU İKİ KOŞUL SAĞLANANA KADAR ekranda tutulur:
     *   1) en az `SPLASH_MIN_MS` geçmiş olmalı,
     *   2) Dart açılış kararını bildirmiş olmalı (`bootReady`).
     *
     * ⚠ UI THREAD BLOKLANMAZ: `Thread.sleep` KULLANILMAZ. Koşul her
     * karede sorulur; bu sırada Flutter motoru ve açılış işleri arka
     * planda çalışmaya devam eder.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        basladi = SystemClock.uptimeMillis()
        bootLog("NATIVE_ON_CREATE")
        splash.setKeepOnScreenCondition {
            val gecen = SystemClock.uptimeMillis() - basladi
            // ⚠ Koşul HER KAREDE sorulur; olaylar TEK KEZ loglanır.
            if (gecen >= SPLASH_MIN_MS && !minLoglandi) {
                minLoglandi = true
                bootLog("NATIVE_SPLASH_MIN_REACHED bootReady=" + bootReady)
            }
            val tut = when {
                // FAIL-SAFE: üst sınırda splash KOŞULSUZ bırakılır.
                gecen >= SPLASH_MAX_MS -> {
                    if (!bootReady) {
                        if (!maxLoglandi) {
                            maxLoglandi = true
                            bootLog("NATIVE_SPLASH_MAX_TIMEOUT bootReady=false")
                        }
                        Log.w(
                            TAG,
                            "Splash fail-safe: ${SPLASH_MAX_MS}ms doldu, " +
                                "bootReady gelmedi — splash bırakılıyor",
                        )
                    }
                    false
                }
                // En kısa süre dolmadan bırakılmaz.
                gecen < SPLASH_MIN_MS -> true
                // Süre doldu: karar hazırsa hemen bırak.
                else -> !bootReady
            }
            if (!tut && !birakmaLoglandi) {
                birakmaLoglandi = true
                bootLog("NATIVE_SPLASH_RELEASED bootReady=" + bootReady)
            }
            tut
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SPLASH KÖPRÜSÜ ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPLASH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bootReady" -> {
                        bootReady = true
                        bootLog("NATIVE_BOOT_READY_RECEIVED")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── EKRAN KORUMASI (FLAG_SECURE) ──
        //
        // Açıkken:
        //   • ekran görüntüsü ve ekran kaydı ENGELLENİR
        //   • son uygulamalar listesinde ekranın ÖNİZLEMESİ çizilmez
        //
        // Cüzdan, kart formu ve iletişim bilgisi ekranlarında açılır;
        // kart numarası ve telefon numarası bu yüzeylerde görünür.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ac" -> {
                        runOnUiThread {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    "kapat" -> {
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── CİHAZ BÜTÜNLÜĞÜ ──
        //
        // ⚠ BU BİR GÜVENLİK DUVARI DEĞİLDİR. Root'lu cihazda bu
        // denetimlerin hepsi atlatılabilir; amaç saldırganı durdurmak
        // değil, RİSKLİ ORTAMI fark edip kullanıcıyı uyarmak ve
        // hassas işlemleri kısıtlayabilmektir.
        //
        // ⚠ TEK BAŞINA ENGELLEME YAPILMAZ: yanlış pozitif, dürüst
        // kullanıcıyı uygulamadan tamamen dışlar.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, INTEGRITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "durum" -> result.success(
                    mapOf(
                        "root" to rootIzleriVar(),
                        "hataAyiklanabilir" to hataAyiklanabilirMi(),
                        "hataAyiklayiciBagli" to android.os.Debug.isDebuggerConnected(),
                        "oykunucu" to oykunucuMu(),
                        "imzaOzeti" to imzaOzeti(),
                    )
                )
                else -> result.notImplemented()
            }
        }

        // Açılış intent'i motor kurulmadan önce gelmiş olabilir.
        initialLink = extractPaymentLink(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        // TEK SEFER: ikinci çağrıda null döner.
                        if (initialLinkConsumed) {
                            result.success(null)
                        } else {
                            initialLinkConsumed = true
                            val link = initialLink
                            if (link != null) delivered.add(link)
                            result.success(link)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── KART TOKENİZASYON KÖPRÜSÜ ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CARD_TOKENIZER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dart açılışta sorar: adaptör hazır mı?
                    "ping" -> result.success(CARD_TOKENIZER_READY)

                    "tokenize" -> {
                        if (!CARD_TOKENIZER_READY) {
                            // Sahte token ÜRETİLMEZ; açık hata döner.
                            result.error(
                                "PROVIDER_NOT_CONFIGURED",
                                "Ödeme sağlayıcısı SDK adaptörü bağlanmadı.",
                                null,
                            )
                        } else {
                            // DIŞ SERVİS ENTEGRASYONU BEKLİYOR:
                            // sağlayıcının Android SDK çağrısı buraya gelir.
                            // Beklenen dönüş: mapOf("paymentToken" to ...,
                            //   "masked" to ..., "brand" to ...)
                            result.error(
                                "NOT_IMPLEMENTED",
                                "Sağlayıcı SDK adaptörü henüz uygulanmadı.",
                                null,
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }

                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })
    }

    /**
     * Uygulama ARKA PLANDA veya ÖN PLANDA iken gelen bağlantı.
     * manifest'te launchMode=singleTop olduğu için yeni bir Activity
     * örneği açılmaz; mevcut örnek bu geri çağrıyı alır.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // setIntent: sonradan getIntent() güncel bağlantıyı versin.
        setIntent(intent)

        val link = extractPaymentLink(intent) ?: return
        if (!delivered.add(link)) {
            // Aynı bağlantı daha önce iletildi — yok sayılır.
            Log.i(TAG, "Yinelenen ödeme dönüşü yok sayıldı")
            return
        }
        val sink = eventSink
        if (sink == null) {
            // Dart henüz dinlemiyorsa bağlantı KAYBOLMASIN: açılış
            // bağlantısı olarak saklanır ve getInitialLink ile okunur.
            initialLink = link
            initialLinkConsumed = false
            Log.i(TAG, "Dinleyici yok — bağlantı açılış bağlantısı olarak saklandı")
            return
        }
        sink.success(link)
    }

    /**
     * Intent'ten geçerli ödeme dönüş bağlantısını çıkarır.
     * Geçersiz/eksik durumlarda null döner ve nedeni loglanır
     * (sessizce yutulmaz).
     */
    private fun extractPaymentLink(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_VIEW) return null
        val uri: Uri = intent.data ?: return null

        if (!uri.scheme.equals(SCHEME, ignoreCase = true)) {
            Log.w(TAG, "Beklenmeyen şema yok sayıldı: ${uri.scheme}")
            return null
        }
        val isPayment = uri.host.equals(HOST_PAYMENT, ignoreCase = true) ||
            uri.pathSegments.contains(HOST_PAYMENT)
        if (!isPayment) {
            Log.w(TAG, "Ödeme dışı derin bağlantı yok sayıldı: ${uri.host}")
            return null
        }

        val session = uri.getQueryParameter("session")
            ?: uri.getQueryParameter("sessionId")
        if (session.isNullOrBlank()) {
            // Session yoksa doğrulama yapılamaz — sessizce geçilmez.
            Log.e(TAG, "Ödeme dönüşünde session kimliği YOK — bağlantı yok sayıldı")
            return null
        }
        // NOT: success/status gibi alanlar bilinçli olarak OKUNMAZ.
        return uri.toString()
    }
    /**
     * ROOT İZLERİ — dosya varlığı ve yaygın araç paketleri.
     *
     * ⚠ Kesin sonuç DEĞİLDİR: gizleme araçları bu izleri saklar.
     * Yine de yaygın durumların çoğunu yakalar.
     */
    private fun rootIzleriVar(): Boolean {
        val yollar = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su",
            "/data/local/su", "/su/bin/su", "/magisk"
        )
        for (y in yollar) {
            if (java.io.File(y).exists()) return true
        }
        // `test-keys` ile imzalı sistem derlemesi resmi sürüm değildir.
        return android.os.Build.TAGS?.contains("test-keys") == true
    }

    /** Uygulama hata ayıklanabilir mi (release'te FALSE olmalı). */
    private fun hataAyiklanabilirMi(): Boolean =
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    /** Öykünücü belirtileri. */
    private fun oykunucuMu(): Boolean {
        val b = android.os.Build.FINGERPRINT ?: ""
        return b.startsWith("generic") || b.contains("vbox") ||
            b.contains("emulator") ||
            android.os.Build.MODEL?.contains("Emulator") == true ||
            android.os.Build.MODEL?.contains("Android SDK built for") == true ||
            android.os.Build.MANUFACTURER?.contains("Genymotion") == true
    }

    /**
     * İMZA ÖZETİ — paketin hangi anahtarla imzalandığı.
     *
     * ⚠ Dart tarafı bunu BEKLENEN özetle karşılaştırır. Beklenen özet
     * derleme zamanında verilir; verilmezse denetim yapılmaz.
     * Yeniden paketlenmiş (repackaged) APK burada farklı özet döner.
     */
    private fun imzaOzeti(): String? = try {
        val pm = packageManager
        val imzalar: Array<android.content.pm.Signature> =
            if (android.os.Build.VERSION.SDK_INT >= 28) {
                pm.getPackageInfo(
                    packageName,
                    android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES
                ).signingInfo?.apkContentsSigners ?: emptyArray()
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(
                    packageName,
                    @Suppress("DEPRECATION")
                    android.content.pm.PackageManager.GET_SIGNATURES
                ).signatures ?: emptyArray()
            }
        if (imzalar.isEmpty()) null
        else {
            val md = java.security.MessageDigest.getInstance("SHA-256")
            android.util.Base64.encodeToString(
                md.digest(imzalar[0].toByteArray()),
                android.util.Base64.NO_WRAP
            )
        }
    } catch (e: Exception) {
        null
    }

}
