# gradle-wrapper.jar — Neden Yok, Nasıl Eklenir

## Durum

`android/gradle/wrapper/gradle-wrapper.jar` bu pakette **YOKTUR**.

`gradle-wrapper.properties` mevcuttur ve Gradle **8.13**'ü işaret eder.

## Neden

Bu dosya derlenmiş Java bytecode içerir (`GradleWrapperMain.class` ve
8 sınıf daha). Paketi hazırlayan ortamda:

- `javac` ve `jar` komutları yok → derlenemez
- Ağ erişimi kapalı (`403 host_not_allowed`) → indirilemez

Sahte veya elle üretilmiş JAR konulmadı; bozuk bir JAR eksik olandan
daha kötüdür.

## Çözüm — üç yoldan BİRİ

### A) Flutter SDK ile (önerilen)

```bash
cd <proje kökü>
flutter create --platforms=android .
```

Eksik platform dosyalarını tamamlar; mevcut `lib/`, `assets/`,
`AndroidManifest.xml` ve `build.gradle` **ezilmez**.

### B) Gradle kuruluysa

```bash
cd android
gradle wrapper --gradle-version 8.13
```

### C) Doğrudan indirme

```bash
cd android
curl -L -o gradle/wrapper/gradle-wrapper.jar \
  https://raw.githubusercontent.com/gradle/gradle/v8.13.0/gradle/wrapper/gradle-wrapper.jar
```

## JAR olmadan da build alınabilir

`gradlew` yalnız bir başlatıcıdır. Sistemde Gradle 8.13 kuruluysa:

```bash
cd android
gradle assembleDebug        # ./gradlew yerine doğrudan gradle
```

Flutter da wrapper'ı zorunlu tutmaz; `flutter build apk` sistem
Gradle'ını bulursa onunla ilerler.

## Bulut derleyicilerde sorun çıkmaz

| Ortam | Davranış |
|---|---|
FlutLab | Kendi Flutter/Gradle kurulumunu kullanır |
GitHub Actions | Workflow JAR'ı otomatik indirir |
Codemagic | Kendi Gradle'ını kullanır |

Daha önce FlutLab'da yapılan derleme **başarılı** olmuştu; wrapper JAR
eksikliği hata vermedi.

## Doğrulama (JAR eklendikten sonra)

```bash
test -s gradle/wrapper/gradle-wrapper.jar && echo "dosya var, boş değil"
unzip -t gradle/wrapper/gradle-wrapper.jar
unzip -l gradle/wrapper/gradle-wrapper.jar | grep GradleWrapperMain
./gradlew --version
```
