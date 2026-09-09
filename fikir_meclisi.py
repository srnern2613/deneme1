import urllib.request
import json
import datetime
import os

# --- AYARLAR ---
API_KEY = "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"
OBSIDIAN_KLASORU = r"C:\Users\srner\Documents\VocabRPG_Brain"
# ----------------

MODEL_ADI = "nex-agi/nex-n2.5-mini:free"

def dosya_oku(dosya_yolu):
    if os.path.exists(dosya_yolu):
        with open(dosya_yolu, "r", encoding="utf-8") as f:
            return f.read()
    return "Henüz bir geçmiş hafıza yok. Bu ilk toplantı."

def hafizayi_guncelle(hafiza_yolu, yeni_ozet):
    mevcut_hafiza = dosya_oku(hafiza_yolu)
    guncel_metin = f"{mevcut_hafiza}\n\n- {yeni_ozet}"
    with open(hafiza_yolu, "w", encoding="utf-8") as f:
        f.write(guncel_metin)

def ajan_fikri_al(rol_talimati, kullanici_istegi):
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    data = {
        "model": MODEL_ADI,
        "messages": [
            {"role": "system", "content": rol_talimati},
            {"role": "user", "content": kullanici_istegi}
        ]
    }
    
    req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result['choices'][0]['message']['content']
    except Exception as e:
        return f"Hata: {str(e)}"

def ana_toplanti_baslat():
    print("🚀 Fikir Meclisi v2 (Metin İçi Etiketli & Hafızalı Ajan) Toplanıyor...\n")
    
    fikir_meclisi_klasor = os.path.join(OBSIDIAN_KLASORU, "🤖 00_AI_Fikir_Meclisi")
    os.makedirs(fikir_meclisi_klasor, exist_ok=True)
    
    hafiza_dosyasi = os.path.join(fikir_meclisi_klasor, "🤖_Proje_Hafizasi.md")
    gecmis_hafiza = dosya_oku(hafiza_dosyasi)
    
    konu = input("Hangi özelliği, ekranı veya stratejiyi tartışmak istiyorsun?: ")
    
    strateji_talimati = f"""
    Sen kıdemli bir Mobil Ürün Yöneticisi ve Büyüme (Growth) Uzmanısın.
    PROJE: VocabRPG (İngilizce kitap okuma ve RPG oyunlaştırma uygulaması). Derin siyah, estetik ve pozitif dile sahip. Hedefimiz ücretsiz kullanıcıyı kaçırmadan Premium (ücretli) üyelik dönüşümünü patlatmak.
    
    GEÇMİŞ PROJE HAFIZASI:
    {gecmis_hafiza}
    
    KURALLAR:
    1. KESİNLİKLE KOD YAZMA.
    2. Global mobil pazarlamada, abonelik modellerinde ve UX psikolojisinde kanıtlanmış güncel stratejileri bil ve kullan.
    3. Bahsettiğin özelliğin dünyada başarılı bir karşılığı, sayısal verisi veya vaka analizi varsa kısaca belirt. Yoksa veya fayda sağlamayacaksa o konuyu hiç açma.
    4. Akademik olma; kahve masasında anlatır gibi net, maddeler halinde ve doğrudan uygulanabilir öneriler ver.
    5. RAPOR İÇİ KATEGORİZASYON VE ETİKETLEME: Metin içerisindeki her ana başlığın veya önemli önerinin yanına ilgili olduğu alanı belirten Obsidian etiketleri ekle (Örn: `### 1. Boş Durum Ekranı #ux #arayuz` veya `### 3. Premium Kancası #growth #monetizasyon`). Böylece metni okurken hangi önerinin hangi kategoriye ait olduğu anında görünsün.
    """
    
    print("\n🧠 Ajan küresel pazarlama taktiklerini, hafızayı ve metin içi etiketleri işliyor...")
    rapor_icerigi = ajan_fikri_al(strateji_talimati, konu)
    
    zaman = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    tarih_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    dosya_adi = f"FMRaporu_{zaman}.md"
    dosya_yolu = os.path.join(fikir_meclisi_klasor, dosya_adi)
    
    yaml_header = f"""---
tarih: "{tarih_str}"
proje: "VocabRPG"
kategori: "[[01_Urun_Stratejisi]]"
tags: [vocab-rpg, strateji, ux, growth, premium]
---

"""
    
    try:
        with open(dosya_yolu, "w", encoding="utf-8") as f:
            f.write(yaml_header)
            f.write(f"# 🎯 Ürün & Büyüme Raporu\n**Konu:** {konu}\n**Tarih:** {tarih_str}\n\n---\n")
            f.write(rapor_icerigi)
        
        hafizayi_guncelle(hafiza_dosyasi, f"Konu: {konu} -> Tartışıldı ve karara bağlandı.")
        
        print(f"\n✅ BAŞARILI! Metin içi etiketlenmiş rapor Obsidian'a yazıldı:\n{dosya_adi}")
    except Exception as e:
        print(f"\n❌ Hata: {e}")

if __name__ == "__main__":
    ana_toplanti_baslat()