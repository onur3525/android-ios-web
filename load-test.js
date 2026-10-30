import http from 'k6/http';
import { check, sleep, group } from 'k6';

// Toplam 5000 Kullanıcılı Test Ayarları (2500 Alan + 2500 Veren)
export const options = {
  stages: [
    { duration: '1m', target: 1000 },  // İlk 1 dakikada 1000 kullanıcıya çık
    { duration: '2m', target: 3000 },  // Sonraki 2 dakikada 3000 kullanıcıya çık
    { duration: '3m', target: 5000 },  // 3 dakika boyunca sistemde tam 5000 kullanıcı tut (Zirve Yük)
    { duration: '1m', target: 0 },     // Son 1 dakikada testi yavaşça bitir
  ],
  thresholds: {
    http_req_duration: ['p(95)<1200'], // İsteklerin %95'i 1.2 saniyeden kısa sürmeli
  },
};

export default function () {
  // Rastgele bir sayı üreterek sanal kullanıcıların yarısını "Hizmet Alan",
  // diğer yarısını "Hizmet Veren" olarak simüle ediyoruz.
  let isServiceProvider = Math.random() < 0.5;

  if (isServiceProvider) {
    // --- 2.500 HİZMET VEREN SENARYOSU ---
    group('Hizmet Veren İşlemleri', function () {
      // Örnek: Hizmet verenin kendisine uygun ilanları listelediği API
      let res = http.get('https://jsonplaceholder.typicode.com/posts?userId=1');
      
      check(res, {
        'Hizmet veren ilan listesi 200 mü?': (r) => r.status === 200,
      });
    });
  } else {
    // --- 2.500 HİZMET ALAN SENARYOSU ---
    group('Hizmet Alan İşlemleri', function () {
      // Örnek: Hizmet alanın ustaları veya kategorileri aradığı API
      let res = http.get('https://jsonplaceholder.typicode.com/comments?postId=1');
      
      check(res, {
        'Hizmet alan arama/kategori 200 mü?': (r) => r.status === 200,
      });
    });
  }

  sleep(1); // Kullanıcı işlem yaptıktan sonra 1 saniye beklesin
}
