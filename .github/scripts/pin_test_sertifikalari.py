#!/usr/bin/env python3
"""Sertifika sabitleme testi için GEÇİCİ test sertifikaları üretir (29 Eki).

Yalnız CI'da, geçici bir dizine yazar; hiçbir anahtar depoya işlenmez.
Üretilenler (hepsi `localhost` adına):
  dogru.*          — pinlenen, geçerli sertifika
  yabanci.*        — PİNLENMEYEN, geçerli sertifika (başka anahtar)
  suresi_dolmus.*  — pinlenen ama süresi DOLMUŞ sertifika
Standart çıktıya CERT_PINS değeri yazılır: dogru ve suresi_dolmus SPKI pinleri.
"""
import base64
import datetime as dt
import hashlib
import sys
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID


def uret(dizin: Path, ad: str, baslangic: dt.datetime, bitis: dt.datetime) -> str:
    anahtar = ec.generate_private_key(ec.SECP256R1())
    isim = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "localhost")])
    sertifika = (
        x509.CertificateBuilder()
        .subject_name(isim)
        .issuer_name(isim)
        .public_key(anahtar.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(baslangic)
        .not_valid_after(bitis)
        .add_extension(x509.SubjectAlternativeName([x509.DNSName("localhost")]), critical=False)
        .sign(anahtar, hashes.SHA256())
    )
    (dizin / f"{ad}.key").write_bytes(anahtar.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    (dizin / f"{ad}.pem").write_bytes(sertifika.public_bytes(serialization.Encoding.PEM))
    spki = anahtar.public_key().public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    return "sha256/" + base64.b64encode(hashlib.sha256(spki).digest()).decode()


def main() -> None:
    dizin = Path(sys.argv[1])
    dizin.mkdir(parents=True, exist_ok=True)
    simdi = dt.datetime.now(dt.timezone.utc)
    gun = dt.timedelta(days=1)
    dogru = uret(dizin, "dogru", simdi - gun, simdi + 30 * gun)
    uret(dizin, "yabanci", simdi - gun, simdi + 30 * gun)
    dolmus = uret(dizin, "suresi_dolmus", simdi - 60 * gun, simdi - 30 * gun)
    print(f"{dogru},{dolmus}")


if __name__ == "__main__":
    main()
