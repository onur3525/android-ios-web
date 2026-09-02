# İLAN ↔ HİZMET VEREN EŞLEŞTİRMESİ — SORUN VE ÖNERİ

13 Ağustos 2026 · **öneri belgesidir, kod değiştirilmedi**

---

## 1 · SORU

> Müşteri banyo tadilatı yaptırmak istiyor ama kartlardan *İnşaat*
> seçiyor. Ya da doğalgaz işi için *Isıtma Sistemleri* seçiyor.
> Hizmet veren ise yalnız *Banyo Tadilatı* / *Doğalgaz* seçmiş.
> Bu ilan hizmet verene düşmüyor, teklif gelmiyor. Nasıl çözülür?

Sorunun kart gizlemeyle sınırlı olmadığını, **tüm katalogda** var
olduğunu ölçtüm. Aşağıdaki sayılar `lib/data/category_tree.dart` (54
ana kategori · 251 alt hizmet) ve `lib/screens/jobs_screen.dart`
içindeki mevcut kural üzerinde hesaplandı.

---

## 2 · BUGÜNKÜ KURAL

`jobs_screen.dart` → `kategoriUygun(Listing l)`:

```
eşleşir  ⟺  ANA_KATEGORİ(ilan) == ustanın_seçimi
            VEYA  ilan_başlığı == ustanın_seçimi        (tam ad)
```

Kural **tek yönlüdür**: ilanı yukarı (ana kategoriye) çıkarır, ustanın
seçimini çıkarmaz.

### Ölçüm

| Ölçüt | Değer |
|---|---|
| Alt hizmet seçen ustanın, kendi ana kategorisiyle verilmiş ilanı görme oranı | **1 / 251** |
| Ana kategori seçen ustanın ortalama erişimi | 5,6 başlık |
| Alt hizmet seçen ustanın ortalama erişimi | 1,0 başlık |
| Bir seçimin ortalama erişimi (305 seçilebilir kayıt içinde) | **1,8** |

### Senaryolar

| Ustanın seçimi | Müşterinin ilanı | Bugün |
|---|---|---|
| Banyo Tadilatı | Tadilat & Dekorasyon | ✗ |
| Tadilat & Dekorasyon | Banyo Tadilatı | ✗ |
| Doğalgaz Tesisatı | Isıtma Sistemleri | ✗ |
| Koltuk Yıkama | Temizlik Hizmetleri | ✗ |
| Ev Temizliği | Temizlik Hizmetleri | ✗ |
| Su Tesisatı | Tıkanıklık Açma | ✓ |

---

## 3 · ÜÇ AYRI ARIZA

Tek bir düzeltme üçünü birden çözmez; sebepleri farklı.

### A · Yön eksikliği (mantık hatası)

Usta *Ev Temizliği* seçmiş, müşteri *Temizlik Hizmetleri* seçmiş.
İkisi de aynı ağaçta, aynı dalda — ama kural yalnız ilanı yukarı
çıkardığı için eşleşmiyor.

**Bu bir tasarım tercihi değil, kuralın eksik yazılmış olması.**
Veri değişmeden, tek fonksiyonla düzelir.

### B · Aile içi geçiş yok (bilgi eksikliği)

*Banyo Tadilatı* ile *Tadilat & Dekorasyon* katalogda **ayrı ana
kategoriler**. Aynı işi yapan usta ikisini de görmeli ama sistem
bunların akraba olduğunu bilmiyor.

⚠ Kart gizleme bu arızayı **büyüttü**: müşteri artık *Banyo Tadilatı*na
yalnız aramadan ulaşıyor ve *Tadilat* kartını seçmiş usta o ilanı
göremiyor.

Daha önce çıkardığım denetimde **54 kategorinin 41'i 11 aileye**
giriyor. 13 kategori tek başına duruyor (Yalıtım, Çatı, Bahçe, Havuz,
Asansör, Mühendislik, Yazılım, Grafik, Pazarlama, Fotoğraf, Etkinlik,
Evcil Hayvan, Güzellik) — onlarda bu sorun zaten yok.

### C · Müşteri tamamen yanlış aile seçiyor (veri hatası)

Banyo tadilatı için *İnşaat*, doğalgaz için *Isıtma Sistemleri*.
Burada kategori verisi **yanlış**; hiçbir eşleştirme kuralı bunu
kategoriye bakarak düzeltemez. Doğru bilgi ilanın **açıklamasında**
duruyor.

---

## 4 · ÖNERİLEN ÇÖZÜM — DÖRT KATMAN

Katmanlar bağımsızdır; sırayla ve ayrı ayrı devreye alınabilir.

### Katman 1 — Yön düzeltmesi

```
eşleşir  ⟺  ad(ilan) == ad(seçim)
            VEYA ( ANA(ilan) == ANA(seçim)
                   VE (seçim ana kategoridir VEYA ilan ana kategoridir) )
```

Yani **taraflardan biri geniş seçim yaptıysa** eşleşir. İki farklı alt
hizmet birbirine açılmaz (*Buzdolabı Tamiri* ustası *Fırın Tamiri*
ilanını görmez) — kapsam gereksiz yere şişmez.

| Etki | Değer |
|---|---|
| Alt hizmet ustasının kendi ana kategorisini görmesi | 1/251 → **251/251** |
| Ortalama erişim | 1,8 → **2,6** |

· Risk: **düşük** · Veri değişikliği: **yok** · Yeni ürün kuralı: **yok**

### Katman 2 — Kapsama haritası *(hizmet veren tarafında)*

> **13 Ağustos ekleme.** Ürün sahibinin önerisi: sorunu yalnız hizmet
> veren tarafında çöz. *Tadilat & Dekorasyon* seçen usta, İnşaat
> kategorisinden gelen işleri de alsın; bunu tüm katalogda uygula.
> Ölçüp değerlendirdim — **çalışır, ama bir koşulla.**

#### Kural

> Hizmet veren bir **ANA KATEGORİ** seçtiyse, o kategorinin
> **ailesindeki** diğer kategorilerin ilanları da ona düşer.
> **ALT HİZMET** seçtiyse kapsam genişlemez.

Bu ayrım kritik. Ölçüm:

| Kurgu | Ortalama erişim | En geniş seçim |
|---|---|---|
| Bugün | 1,8 | 12 |
| Katman 1 (yalnız yön) | 2,6 | 12 |
| Aile bağı **her** seçimde | **19,4** | 30 |
| Aile bağı **yalnız ana kategori** seçiminde | **4,6** | 28 |

"Her seçimde" kurgusunda *Buzdolabı Tamiri* seçen usta 30 farklı
başlığın ilanını alıyor — kendi işiyle ilgisi olmayan yüzlerce ilan.
"Yalnız ana kategori" kurgusunda ise seçim bir **tercihe** dönüşüyor:

- geniş kart seçtin → aileden de iş alırsın
- belirli hizmeti seçtin → yalnız onu alırsın

Hizmet veren kapsamı kendisi belirlemiş olur; sürpriz olmaz.

#### Aileler 11 → 13'e çıkarıldı

İlk denetimdeki iki büyük aile fazla genişti; ölçüm gösterdi ki
*Çilingir* ustasına *PVC Pencere Montajı* ilanı düşüyordu. İkisi
bölündü:

| Aile | Üyeler |
|---|---|
| Isıtma & gaz | Kombi Servisi · Isıtma Sistemleri · Doğalgaz · Su Tesisatı |
| Tadilat & yapı | Tadilat & Dekorasyon · Banyo Tadilat · Mutfak Tadilat · İnşaat |
| Cihaz tamiri | Beyaz Eşya · Elektronik Cihaz · Klima Servisi |
| Mobilya & ahşap | Mobilya · Marangozluk |
| **Doğrama & cam** | PVC & Alüminyum · Demir Doğrama · Cam Balkon |
| **Kapı & kilit** | Kapı Montaj · Çilingir |
| **Zemin kaplama** | Fayans & Seramik · Zemin Kaplama |
| **Yüzey & dekor** | Boya & Badana · Alçı & Sıva · Duvar Kağıdı |
| Temizlik | Temizlik · Halı Yıkama · Koltuk & Döşeme · İlaçlama |
| Taşıma | Nakliyat · Kurye |
| Otomotiv | Oto Çekici · Oto Servis · Araç Temizlik |
| Eğitim & ders | Özel Ders · Yabancı Dil · Sürücü · Spor · Müzik |
| Elektrik & zayıf akım | Elektrik Tesisatı · Güvenlik · İnternet & Ağ · Uydu & Anten |

13 kategori hiçbir aileye girmiyor (Yalıtım, Çatı, Bahçe, Havuz,
Asansör, Mühendislik, Yazılım, Grafik, Pazarlama, Fotoğraf, Etkinlik,
Evcil Hayvan, Güzellik) — onlarda bu sorun zaten yok, kapsamları
değişmez.

#### Doğrulanmış örnekler

| Ustanın seçimi | İlan | Bugün | Öneri |
|---|---|---|---|
| Tadilat & Dekorasyon | Kaba İnşaat | ✗ | **✓** |
| Kombi Servisi | Doğalgaz Tesisatı | ✗ | **✓** |
| Özel Ders | Gitar Dersi | ✗ | **✓** |
| Kapı Montaj | Kapı Açma | ✗ | **✓** |
| Çilingir | PVC Pencere Montajı | ✗ | ✗ *(doğru)* |
| Boya & Badana | Parke Döşeme | ✗ | ✗ *(doğru)* |

#### Üç zorunlu emniyet

1. **Hizmet veren kapatabilmeli.** Profilde tek anahtar: *"Yakın
   kategorilerden de iş göster"*. Varsayılan açık olabilir ama karar
   ustanın olmalı.
2. **İlan işaretlenmeli.** Kapsamadan gelen ilanın üzerinde küçük bir
   *"Yakın kategori"* etiketi dursun; usta neden düştüğünü bilsin.
3. **Ana kategori seçen ustanın erişimi 3–28 arasında değişiyor**
   (ortanca 19). Bu, ailelerin boyutundan geliyor. Canlıda "teklif
   almayan ilan oranı" ve "ustanın gördüğü ilan sayısı" izlenmeli;
   gerekirse aileler yeniden bölünmeli.

---

### Katman 2 — ESKİ ÖNERİ: aile haritası ayrı bölümde

`kKategoriAilesi` adında yeni bir sabit: 11 aile, 41 kategori.
Aynı ailedeki kategoriler birbirinin ilanını görür.

⚠ **Önerim: aile eşleşmesi ANA LİSTEYE KARIŞTIRILMASIN.** Ölçtüm:
aileyi doğrudan eşleştirmeye katarsak ortalama erişim 1,8 → **19,4**
oluyor; bazı seçimlerde 305 başlığın 30'u tek seçimle geliyor. Bu,
alakasız iş kalabalığı demek ve teklif kalitesini düşürür.

Doğru kurgu, ekranda **zaten var olan desenin aynısı**: bugün seçili
ilçelerde 1 saattir yeni ilan yoksa kapsam il geneline genişliyor.
Aynı mantık kategoriye uygulanır —

> Katman 1'e göre eşleşen **açık ilan yoksa**, aynı ailedeki ilanlar
> *"Yakın kategoriler"* başlığı altında ayrıca listelenir.

Böylece ana liste dar ve isabetli kalır, usta boş ekranla kalmaz.

· Risk: **orta** · Yeni veri: aile haritası · Ürün kuralı: **yeni**

⚠ Bu iki kurgu birbirinin alternatifidir. Ürün sahibinin önerdiği
"hizmet veren tarafında kapsama" (yukarıdaki) **ana listeye karışır**;
bu eski öneri ise **ayrı bölümde** gösterir. Ölçüm, ana kategori
şartıyla birlikte birincisini de güvenli buluyor (ortalama 4,6);
seçim ürün kararıdır.

### Katman 3 — İlan açıklamasından doğrulama (arıza C)

Müşteri kategoriyi seçip açıklamayı yazdıktan sonra, açıklama
`SearchService` + `arama_es_anlamlilari.dart` ile taranır. Metin
belirgin biçimde **başka bir kategoriyi** işaret ediyorsa, ilan
yayınlanmadan önce tek satırlık bir soru çıkar:

> "Bu ilan **Banyo Tadilatı** hizmetine benziyor. Kategoriyi
> değiştirmek ister misiniz?"  → *Değiştir* / *Devam et*

Zorlama yok, karar müşterinin. Sözlük zaten var (251 kayıt); yeni veri
üretmeye gerek yok.

· Risk: **düşük–orta** · En büyük kazanç burada: yanlış kategoriyi
**kaynağında** düzeltir, sonradan telafi etmeye çalışmaz.

### Katman 4 — Teklifsiz ilan için emniyet supabı

İlan **N saat** boyunca hiç teklif almadıysa:

1. kapsamı otomatik olarak aileye genişlet (Katman 2 mantığı), ve
2. müşteriye bildirim: *"İlanınıza henüz teklif gelmedi. Kategoriyi
   düzenlemek ister misiniz?"*

İlan ömrü 30 saat olduğu için N = 6–8 saat mantıklı görünüyor; kesin
değeri siz belirlersiniz.

· Risk: **orta** · Ürün kuralı: **yeni** · Bildirim + zamanlayıcı gerektirir

---

## 5 · UYGULAMA SIRASI

| # | Katman | Nerede | Yeni veri | Risk |
|---|---|---|---|---|
| 1 | Yön düzeltmesi | Flutter + backend | yok | düşük |
| 2 | **Kapsama haritası** (ana kategori seçimine bağlı) | Flutter + backend | 13 aile | orta |
| 3 | Açıklamadan kategori önerisi | Flutter | yok | düşük–orta |
| 4 | Teklifsiz ilanda genişleme | backend (zamanlayıcı + bildirim) | yok | orta |

Katman 1 ile Katman 2 birlikte çalışır: 1 aynı ağaç içindeki yönü
düzeltir, 2 aileler arası köprüyü kurar. Katman 2 tek başına
uygulanırsa *Ev Temizliği* seçen usta *Temizlik Hizmetleri* ilanını
yine göremez.

---

## 6 · ⚠ İKİ TARAFLI İŞ

Bugünkü eşleştirme kuralı **hem Flutter'da hem backend'de** var.
Flutter'daki `kategoriUygun` yalnız elindeki listeyi süzer; gerçek
veriyle çalışırken listeyi **sunucu** seçer.

**Yalnız Flutter düzeltilirse sorun devam eder.** Hangi katman
onaylanırsa onaylansın, aynı kural iki yerde birden yazılmalı ve tek
bir sözleşme testiyle karşılaştırılmalıdır.

---

## 7 · KARAR BEKLEYEN NOKTALAR

1. Hangi katmanlar uygulanacak?
2. Katman 2'de kapsama **ana listeye mi karışsın** (ürün sahibinin
   önerisi) yoksa **ayrı bölümde** mi dursun? Ölçüm, "yalnız ana
   kategori seçiminde genişle" şartıyla ana listeye karışmasını da
   güvenli buluyor (ortalama erişim 4,6).
3. **Alt hizmet seçen usta dar kalsın** kuralı onaylanıyor mu? Bu
   kural olmazsa erişim 4,6 yerine 19,4 oluyor.
4. 13 ailelik kapsama haritasının içeriği onaylanıyor mu? Özellikle
   ikiye bölünen *Doğrama & cam / Kapı & kilit* ve *Zemin kaplama /
   Yüzey & dekor* ayrımları.
5. Hizmet verene *"Yakın kategorilerden de iş göster"* anahtarı
   konulsun mu, varsayılanı açık mı olsun?
6. Katman 4'te "teklifsiz" eşiği kaç saat?

---

## 8 · BU BELGENİN DAYANAĞI

- Kural okuması: `lib/screens/jobs_screen.dart` → `kategoriUygun`
- Katalog: `lib/data/category_tree.dart` (54 / 251)
- Sayılar, katalogun tamamı üzerinde çalıştırılan eşleştirme
  benzetimiyle üretildi (305 seçilebilir kayıt × 305 ilan başlığı).
- ⚠ Bunlar **katalog üzerinden** hesaplanmış kapsam sayılarıdır;
  gerçek kullanıcı davranışı ölçülmedi. Canlıya çıkınca "teklif
  almayan ilan oranı" izlenmeli ve eşikler ona göre ayarlanmalıdır.

---

## 9 · KARAR VE UYGULAMA (13 Ağustos)

Ürün sahibi kararı:

1. **Katman 1 + Katman 2 uygulandı.**
2. ⚠ **KESİN KURAL — kullanıcıya hiçbir şey gösterilmez.** "Yakın
   kategori" etiketi, başlığı, açıklaması, ayrı bölümü ve ayarı
   YOKTUR; hizmet verene soru sorulmaz. Kavram yalnız iç işleyiştir.
3. **Sıralama:** hizmet verenin kendi seçtiği kategorilerden gelen
   ilanlar ÖNCE, aileden gelenler ARKADAN. Kullanıcının seçtiği
   sıralama ölçütü (yeni / teklifsiz / eski …) bu iki grubun İÇİNDE
   uygulanır.
4. Katman 3 ve 4 **şimdilik yapılmadı** — canlı veri görülünce
   yeniden değerlendirilecek.

### Nerede duruyor

| Dosya | İş |
|---|---|
| `lib/domain/eslestirme.dart` | 13 aile + iki kademeli kural, saf fonksiyonlar |
| `lib/screens/jobs_screen.dart` | kuralı çağırır, önceliğe göre sıralar |
| `test/eslestirme_test.dart` | kuralı ve "kullanıcıya gösterilmez" şartını kilitler |

### Ölçülen etki

| Ölçüt | Önce | Sonra |
|---|---|---|
| Alt hizmet seçenin kendi ana kategorisini görmesi | 1/251 | **251/251** |
| Ortalama erişim (305 başlık içinde) | 1,8 | **4,6** |
| İki farklı alt hizmetin birbirine açılması | — | **yok** |

### ⚠ Backend hâlâ bekliyor

`lib/domain/eslestirme.dart` saf fonksiyonlardan oluşur ve backend'de
birebir yeniden yazılabilir. **Yazılana kadar gerçek veriyle çalışan
kurulumda sorun devam eder** — listeyi sunucu seçer.
