# Kilit dosyaları (tekrarlanabilir derleme)

Depoda henüz `backend/package-lock.json` ve `pubspec.lock` **yok**. Bu ortamda
üretilemediler: npm kayıt defteri, pub.dev ve Flutter SDK indirme adresleri
ağ politikasınca kapalı (HTTP 403). Elle yazılmış ya da tahmini kilit dosyası
eklenmedi — yanlış bir kilit, olmamasından daha kötüdür.

Bir kez, ağa açık bir makinede üretip depoya eklenmeli:

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
