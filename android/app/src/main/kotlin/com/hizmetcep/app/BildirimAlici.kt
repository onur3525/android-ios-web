package com.hizmetcep.app

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build

/**
 * ── HİZMETCEP SİSTEM BİLDİRİMİ (Android) — TEK GÖRÜNÜM ──
 *
 * 21 Eki (kullanıcı bulgusu): aynı bildirim Samsung'da renkli HizmetCep
 * logosuyla, Xiaomi'de yalnız tek renkli küçük simgeyle görünüyordu.
 * Sebep rol değil markaydı: FCM'nin kendi çizdiği bildirimde "büyük simge"
 * (renkli logo) VERİLEMEZ; Samsung uygulama simgesini kendisi ekler,
 * diğer markalar eklemez.
 *
 * Artık sunucu Android cihazlara yalnız VERİ gönderir (backend/src/fcm.js,
 * `hcYerel=1`) ve bildirimi BURADA, her markada aynı biçimde çizeriz:
 *   · küçük simge: ic_stat_hizmetcep (tek renk, marka mavisi) — Android kuralı
 *   · büyük simge: renkli HizmetCep uygulama logosu
 *     (⚠ Samsung'da EKLENMEZ: One UI uygulama simgesini zaten gösterir;
 *      eklenirse logo iki kez görünürdü.)
 *   · başlık + metin, dokununca ilgili ekran (MainActivity → Dart)
 *
 * Bu alıcı FlutterFire'ın kendi alıcısıyla YAN YANA çalışır (ikisi de aynı
 * FCM yayınını alır); Dart tarafındaki akış (önde tazeleme, arka plan
 * işleyicisi) DEĞİŞMEDİ.
 *
 * ⚠ Uygulama ÖNDEYKEN sistem bildirimi çizilmez — önceki davranışla aynı
 * (FCM de önde bildirim göstermiyordu; liste ve rozet Dart'ta tazelenir).
 */
class BildirimAlici : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val e = intent.extras ?: return
        if (e.getString(ANAHTAR_YEREL) != "1") return
        if (uygulamaOndeMi(context)) return
        val baslik = e.getString("baslik") ?: return
        val veri = HashMap<String, String>()
        for (k in AKTARILAN) e.getString(k)?.let { veri[k] = it }
        BildirimCizici.goster(context, baslik, e.getString("govde") ?: "", veri)
    }

    private fun uygulamaOndeMi(context: Context): Boolean {
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (km?.isKeyguardLocked == true) return false
        return MainActivity.onde
    }

    companion object {
        const val ANAHTAR_YEREL = "hcYerel"

        /** Dokununca Dart'a geçen alanlar (push_kapisi.dart ile aynı). */
        val AKTARILAN = listOf("type", "bildirimId", "hedef", "id", "baslik", "govde")
    }
}

object BildirimCizici {
    private const val KANAL = "hizmetcep_bildirimler"

    /** MainActivity'nin dokunulan bildirimi tanıdığı işaret. */
    const val ACILIS = "hcBildirimAcilisi"

    fun goster(context: Context, baslik: String, govde: String, veri: Map<String, String>) {
        try {
            if (Build.VERSION.SDK_INT >= 33 &&
                context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(KANAL) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(KANAL, "Bildirimler", NotificationManager.IMPORTANCE_HIGH)
                )
            }
            val kod = (veri["bildirimId"] ?: "$baslik$govde${System.currentTimeMillis()}").hashCode()
            val ac = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(ACILIS, true)
                for ((k, v) in veri) putExtra(k, v)
            }
            val bayrak = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
            val pi = PendingIntent.getActivity(context, kod, ac, bayrak)

            @Suppress("DEPRECATION")
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, KANAL)
            else Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_ALL)
            b.setSmallIcon(R.drawable.ic_stat_hizmetcep)
                .setColor(
                    if (Build.VERSION.SDK_INT >= 23) context.getColor(R.color.hc_blue)
                    else @Suppress("DEPRECATION") context.resources.getColor(R.color.hc_blue)
                )
                .setContentTitle(baslik)
                .setContentText(govde)
                .setStyle(Notification.BigTextStyle().bigText(govde))
                .setAutoCancel(true)
                .setContentIntent(pi)
            if (!Build.MANUFACTURER.equals("samsung", ignoreCase = true)) {
                renkliLogo(context)?.let { b.setLargeIcon(it) }
            }
            nm.notify(kod, b.build())
        } catch (_: Exception) {
            // Bildirim çizilemezse uygulama içi kayıt yine durur.
        }
    }

    /** Uygulama simgesi (adaptive dahil) → bitmap. */
    private fun renkliLogo(context: Context): Bitmap? = try {
        val d = context.packageManager.getApplicationIcon(context.applicationInfo)
        val boyut = 256
        val bmp = Bitmap.createBitmap(boyut, boyut, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, boyut, boyut)
        d.draw(Canvas(bmp))
        bmp
    } catch (_: Exception) {
        null
    }
}
