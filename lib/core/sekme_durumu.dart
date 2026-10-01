// Sekme durumu (yalnız web): tarayıcının SEKMEYE ÖZEL deposu
// (sessionStorage). Sekme kapanınca silinir; başka sekme göremez.
// Mobil/VM'de hiçbir şey yapmaz.
export 'sekme_durumu_yok.dart' if (dart.library.js_interop) 'sekme_durumu_web.dart';
