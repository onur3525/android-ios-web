# Kilit dosyaları (tekrarlanabilir derleme)

Depoda henüz `backend/package-lock.json` ve `pubspec.lock` **yok**. Bu ortamda
üretilemediler: npm kayıt defteri, pub.dev ve Flutter SDK indirme adresleri
ağ politikasınca kapalı (HTTP 403). Elle yazılmış ya da tahmini kilit dosyası
eklenmedi — yanlış bir kilit, olmamasından daha kötüdür.

Bir kez, ağa açık bir makinede üretip depoya eklenmeli. (14 Eki denetimi:
bu ortamda `registry.npmjs.org` DNS ile çözülemedi — ENOTFOUND; yine
üretilemedi.)

**En kolay yol (backend):** `.github/workflows/backend.yml` kilit yoksa
`npm install` ile kayıt defterinden GERÇEKTEN çözülen `package-lock.json`'u
`backend-package-lock` adlı ürün (artifact) olarak saklar. Actions →
ilgili koşu → Artifacts'tan indirip `backend/package-lock.json` olarak
işleyin.

Ya da elle:

## Backend

```bash
cd backend
npm install --package-lock-only --ignore-scripts   # yalnız çözümleme; node_modules kurmaz
git add package-lock.json
```

`pg` sürümü `package.json`'da tam sürümle sabit (`8.13.1`); kilit, alt
bağımlılıkları da sabitler. Kilit eklendikten sonra:

- `backend/Dockerfile` kilit dosyası yoksa **derlemeyi durdurur** (`npm ci`).
  Yalnız yerel deneme için: `docker build --build-arg KILITSIZ=1 ...`
- Sürüm yükseltme: `npm install pg@<sürüm> --package-lock-only`, testler, sonra commit.

## Flutter

**En kolay yol:** `.github/workflows/flutter-ci.yml` (analyze-test işi) kilit
depoda yoksa `flutter pub get` ile pub.dev'den çözülen `pubspec.lock`'u ve
onu üreten Flutter/Dart sürümünü (`flutter-surumu.json`) `flutter-pubspec-lock`
ürünü olarak saklar. Actions → koşu → Artifacts'tan indirip depo köküne
`pubspec.lock` olarak işleyin. (14 Eki: bu ortamda Flutter SDK yok;
`pub.dev` ve `storage.googleapis.com` ağ politikasınca 403.)

Ya da elle:

```bash
flutter pub get          # pubspec.lock üretir
git add pubspec.lock
```

- `codemagic.yaml` içindeki `release-hardened` akışı zaten
  `flutter pub get --enforce-lockfile` çalıştırır: kilit yoksa ya da
  `pubspec.yaml` ile uyuşmazsa sürüm derlemesi **bilerek düşer**.
- GitHub Actions akışları (depoda, ZIP'te değil) sürüm derlemesinde aynı
  bayrağı kullanmalı: `flutter pub get --enforce-lockfile`.

## Doğrulama

- Backend: `npm ci --omit=dev` hatasız biter, `npm test` geçer.
- Flutter: `flutter pub get --enforce-lockfile && flutter analyze && flutter test`.
