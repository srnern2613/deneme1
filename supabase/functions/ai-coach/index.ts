// ============================================================================
// DOSYA ADI: supabase/functions/ai-coach/index.ts
// AÇIKLAMA: Ejderha Rotası V2 — Faz 7. AI Koç için ince Serverless Lite
// proxy'si (Supabase Edge Function, Deno runtime).
//
// Bu fonksiyonun TEK görevi: uygulamadan gelen mesajı alıp LLM API'ye
// iletmek ve yanıtı geri döndürmek. Gizli LLM API anahtarı YALNIZCA burada,
// bu fonksiyonun ortam değişkeni (secret) olarak durur — hiçbir zaman
// Flutter uygulamasına gömülmez.
//
// KURULUM (kullanıcı tarafında, bir kere yapılır):
//   1. Supabase CLI kur: https://supabase.com/docs/guides/cli
//   2. supabase login && supabase link --project-ref <PROJE_REF>
//   3. Gizli anahtarı tanımla:
//        supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxxx
//   4. Fonksiyonu deploy et:
//        supabase functions deploy ai-coach --no-verify-jwt
//   5. Deploy sonrası verilen URL'yi lib/core/ai_coach/ai_coach_config.dart
//      içindeki edgeFunctionUrl'e, Supabase Dashboard > Settings > API
//      altındaki "anon public" anahtarını da supabaseAnonKey'e yapıştır.
//
// GÜVENLİK NOTU: Mimari "Local-First + Serverless Lite" olduğu için bu
// fonksiyon kullanıcı kimlik doğrulaması yapmaz (anonim cihaz kimliği
// modeli — RevenueCat/PaywallTrigger ile aynı ruhta). Kötüye kullanımı
// sınırlamak için ücretsiz kullanıcı kotası istemci tarafında
// (ai_coach_repository.dart) takip edilir; burada da ayrıca makul bir
// mesaj uzunluğu sınırı uygulanır.
// ============================================================================

// @ts-ignore: Deno ortamında çalışır, yerel TS analizinde çözümlenemeyebilir.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY') ?? '';
const ANTHROPIC_MODEL = Deno.env.get('ANTHROPIC_MODEL') ?? 'claude-3-5-haiku-latest';
const MAX_MESSAGE_LENGTH = 2000;

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Ignis: Draconic Lingua'nın ejderha maskotu — AI Koç'un kişiliği. Kullanıcı
// zindanda kelime avlayan bir maceracı, Ignis onun rehberi/koçu.
const SYSTEM_PROMPT = `Sen Ignis'sin: Draconic Lingua adlı zindan temalı İngilizce öğrenme uygulamasının ejderha maskotu ve kişisel dil koçusun.
Görevin: kullanıcının İngilizce kelime dağarcığını, telaffuzunu ve okuma alışkanlığını geliştirmesine yardımcı olmak.
Üslubun: sıcak, cesaretlendirici, kısa ve öz — bir "zindan rehberi" enerjisiyle ama asla abartılı roleplay'e boğmadan.
Kurallar:
- Her zaman Türkçe yanıt ver (kullanıcı açıkça İngilizce istemedikçe).
- Yanıtların 2-4 cümleyi geçmesin; uygulama içi sohbet balonunda gösteriliyor.
- Kullanıcı bir kelimenin anlamını/telaffuzunu/kullanımını sorarsa net ve doğru bilgi ver, örnek cümle ekle.
- Kullanıcı motivasyon/çalışma stratejisi sorarsa somut, uygulanabilir bir öneri ver.
- Asla tıbbi, hukuki veya finansal tavsiye verme; konu dışına çıkma, nazikçe konuya dön.`;

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Yalnızca POST desteklenir.' }, 405);
  }

  if (!ANTHROPIC_API_KEY) {
    return jsonResponse({ error: 'Sunucu yapılandırması eksik: ANTHROPIC_API_KEY tanımlı değil.' }, 500);
  }

  let body: { message?: string; history?: ChatMessage[] };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Geçersiz JSON gövdesi.' }, 400);
  }

  const message = (body.message ?? '').toString().trim();
  if (!message) {
    return jsonResponse({ error: 'Mesaj boş olamaz.' }, 400);
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return jsonResponse({ error: `Mesaj çok uzun (maks ${MAX_MESSAGE_LENGTH} karakter).` }, 400);
  }

  const history: ChatMessage[] = Array.isArray(body.history) ? body.history.slice(-10) : [];
  const messages = [
    ...history
      .filter((m) => m && typeof m.content === 'string' && (m.role === 'user' || m.role === 'assistant'))
      .map((m) => ({ role: m.role, content: m.content })),
    { role: 'user', content: message },
  ];

  try {
    const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: 400,
        system: SYSTEM_PROMPT,
        messages,
      }),
    });

    if (!anthropicResponse.ok) {
      const errText = await anthropicResponse.text();
      console.error('Anthropic API hatası:', anthropicResponse.status, errText);
      return jsonResponse({ error: 'AI Koç şu anda yanıt veremiyor.' }, 502);
    }

    const data = await anthropicResponse.json();
    const reply = (data?.content?.[0]?.text ?? '').toString().trim();

    return jsonResponse({ reply });
  } catch (e) {
    console.error('Edge Function beklenmeyen hata:', e);
    return jsonResponse({ error: 'Beklenmeyen bir hata oluştu.' }, 500);
  }
});

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
