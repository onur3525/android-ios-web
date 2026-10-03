# HizmetCep backend — durumsuz, yatay ölçeklenebilir kapsayıcı.
# Aynı imajdan N örnek çalıştırılır; ayarlar yalnız ortam değişkeninden.
# Derleme DEPO KÖKÜNDEN: docker build -f backend/Dockerfile .
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app/backend
COPY backend/package.json backend/package-lock.json* ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && npm cache clean --force
COPY backend/src ./src
COPY backend/migrations ./migrations
COPY backend/scripts ./scripts
# Yönetim paneli (statik) aynı imajda, /admin altında sunulur.
COPY admin /app/admin
# Admin önizlemesi için uygulama paketindeki katalog görselleri (salt okunur).
COPY assets/categories /app/assets/categories
COPY assets/svg/categories /app/assets/svg/categories
# Başlangıç verisi aktarımı (npm run seed) Flutter veri dosyalarını okur.
COPY lib/data /app/lib/data
COPY lib/screens/category_ui.dart /app/lib/screens/category_ui.dart
USER node
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
CMD ["node", "--no-warnings", "src/server.js"]
