// ============================================================================
// DOSYA ADI: lib/core/ai_coach/coach_question_catalog.dart
// AÇIKLAMA: AI Koç ekranının hazır soru-cevap kütüphanesi.
//
// Serbest yazma şimdilik kapalı (sunucu tarafındaki AI kurulumu
// tamamlanana kadar). Kullanıcı bunun yerine kategorilere ayrılmış hazır
// sorulardan birini seçer; cevaplar tamamen YEREL üretilir — ağ yok, kota
// yok, hata riski yok. Bazı cevaplar kullanıcının GERÇEK verisini okur
// (bugünkü ilerleme, kelime havuzu, XP, seri).
//
// Cevaplardaki her bilgi uygulamanın gerçek davranışıyla eşleşmeli —
// bir özellik değişirse ilgili cevabı da burada güncelle.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../database_helper.dart';
import '../../streak_freeze_service.dart';
import '../../xp_shop_service.dart';
import '../coach/ignis_moments_engine.dart';
import '../entitlement/entitlement_repository.dart';

/// Bir hazır sorunun cevabı. [offerPremium] true ise ekran, cevabın altına
/// "Evet, göster / Şimdilik değil" seçeneklerini ekler.
class CoachAnswer {
  final String text;
  final bool offerPremium;

  const CoachAnswer(this.text, {this.offerPremium = false});
}

class CoachQuestion {
  final String text;
  final IconData icon;
  final Future<CoachAnswer> Function() answer;

  const CoachQuestion({required this.text, required this.icon, required this.answer});
}

class CoachCategory {
  final String label;
  final IconData icon;
  final List<CoachQuestion> questions;

  const CoachCategory({required this.label, required this.icon, required this.questions});
}

class CoachQuestionCatalog {
  CoachQuestionCatalog._();

  static Future<CoachAnswer> _static(String text) async => CoachAnswer(text);

  static final List<CoachCategory> categories = [
    CoachCategory(
      label: 'Başlarken',
      icon: PhosphorIcons.compassBold,
      questions: [
        CoachQuestion(
          text: 'Ignis nasıl çalışır?',
          icon: PhosphorIcons.sparkleBold,
          answer: () => _static(
            'Ignis, İngilizceyi gerçek kitapların içinden öğretir. Okurken bilmediğin bir kelimeye dokunursun, '
            'anlamını görür ve hafıza havuzuna eklersin. Sonra Arena\'daki pratik modları o kelimeleri, '
            'unutmak üzere olduğun anda tekrar önüne getirir.\n\n'
            'Yani ezber listesi yok: kendi okuduğun cümlelerden, kendi kelime hazineni kuruyorsun.',
          ),
        ),
        CoachQuestion(
          text: 'Nereden başlamalıyım?',
          icon: PhosphorIcons.targetBold,
          answer: () => _static(
            'En verimli başlangıç 3 adım:\n\n'
            '1. Dersler sekmesinden sana uygun bir kitap aç ve birkaç sayfa oku.\n'
            '2. Bilmediğin kelimelere dokunup havuzuna ekle — 5-10 kelime ilk gün için ideal.\n'
            '3. Arena\'da "Zindana Gir"e bas; vakti gelen kelimelerin karışık modlarla karşına çıkar.\n\n'
            'Her gün kısa ama düzenli bir tur, uzun ama seyrek çalışmaktan çok daha etkilidir.',
          ),
        ),
        CoachQuestion(
          text: 'Kelime nasıl eklerim?',
          icon: PhosphorIcons.plusBold,
          answer: () => _static(
            'Kelimeler okurken eklenir: bir kitapta bilmediğin kelimeye dokun, açılan pencerede anlamını gör '
            've havuzuna ekle. Kelime, geçtiği cümleyle birlikte kaydedilir — Boşluk Doldurma modu bu cümleyi '
            'kullanır.\n\n'
            'Eklediğin kelimeler otomatik olarak pratik listene girer. Topladığın bütün kelimeleri Sözlük '
            'ekranında, geldikleri kitaba göre filtreleyerek görebilirsin.',
          ),
        ),
      ],
    ),
    CoachCategory(
      label: 'İlerlemem',
      icon: PhosphorIcons.chartBarBold,
      questions: [
        CoachQuestion(
          text: 'Bugün kaç kelime öğrendim?',
          icon: PhosphorIcons.sparkleBold,
          answer: _todayProgress,
        ),
        CoachQuestion(
          text: 'Kelime havuzumda neler var?',
          icon: PhosphorIcons.cardsBold,
          answer: _wordPool,
        ),
        CoachQuestion(
          text: 'Kaç XP\'im var, nasıl daha çok kazanırım?',
          icon: PhosphorIcons.lightningBold,
          answer: _xp,
        ),
      ],
    ),
    CoachCategory(
      label: 'Öğrenme',
      icon: PhosphorIcons.brainBold,
      questions: [
        CoachQuestion(
          text: 'Tekrar sistemi nasıl çalışıyor?',
          icon: PhosphorIcons.arrowClockwiseBold,
          answer: () => _static(
            'Ignis, aralıklı tekrar denen bilimsel bir yöntem kullanır. Her kelime için "unutmak üzere '
            'olduğun anı" hesaplar ve kelimeyi tam o gün önüne getirir.\n\n'
            '• Doğru bildikçe bir sonraki tekrar daha ileri bir güne atılır.\n'
            '• Yanlış bildiğin kelime ise yaklaşık 10 dakika sonra tekrar karşına çıkar.\n\n'
            'Bu sayede zamanını zaten bildiğin kelimelere değil, gerçekten zorlandıklarına harcarsın.',
          ),
        ),
        CoachQuestion(
          text: 'Hangi pratik modları var?',
          icon: PhosphorIcons.puzzlePieceBold,
          answer: () => _static(
            'Arena\'da şu modlar var:\n\n'
            '• Zindana Gir: vakti gelen kelimelerin, her soruda farklı bir modla karışık gelir.\n'
            '• Hızlı Test: kelimenin doğru anlamını seç.\n'
            '• SRS Hafıza: kartı çevir, ne kadar iyi hatırladığını işaretle.\n'
            '• Eşleştirme: kelimeleri anlamlarıyla eşle, kombo yaptıkça XP katlanır.\n'
            '• Dinle & Yaz: duyduğun kelimeyi yaz.\n'
            '• Boşluk Doldurma: kelimeyi kitaptaki gerçek cümlesinde tamamla.\n\n'
            'Premium ile ayrıca Ters Test, Sadece Dinleme ve Hız Turu açılır.',
          ),
        ),
        CoachQuestion(
          text: 'Bir kelime ne zaman kalıcı hafızaya geçer?',
          icon: PhosphorIcons.trophyBold,
          answer: () => _static(
            'Bir kelimeyi "kalıcı hafıza"ya almak için tek seferlik doğru cevap yetmez. Ignis şu 4 şartın '
            'hepsini bekler:\n\n'
            '• Üst üste 6 doğru cevap\n'
            '• En az 3 farklı günde çalışılmış olması\n'
            '• Tekrar aralığının 3 haftaya ulaşması\n'
            '• En az 2 farklı pratik modunda doğru bilinmesi\n\n'
            'Bu yüzden "kalıcı" dediğimiz kelimeler gerçekten kalıcıdır.',
          ),
        ),
        CoachQuestion(
          text: 'Boss kelimeler nedir?',
          icon: PhosphorIcons.swordBold,
          answer: () => _static(
            'Bir kelimeyi 3 kez veya daha fazla yanlış bilirsen, o kelime "boss"a dönüşür — yanlış sayısı '
            'arttıkça seviyesi de yükselir.\n\n'
            'Boss\'ları Arena\'da düello ederek yenersin; kazanınca 20 XP alırsın ve kelimenin hata sayacı '
            'sıfırlanır. Kaybedersen boss 2 saat dinlenir, sonra tekrar meydan okuyabilirsin.',
          ),
        ),
      ],
    ),
    CoachCategory(
      label: 'Seri & Ödüller',
      icon: PhosphorIcons.fireBold,
      questions: [
        CoachQuestion(
          text: 'Serimi nasıl korurum?',
          icon: PhosphorIcons.shieldCheckBold,
          answer: _streak,
        ),
        CoachQuestion(
          text: 'Rozetler nasıl açılır?',
          icon: PhosphorIcons.crownBold,
          answer: () => _static(
            'Toplam 22 rozet var ve hepsi otomatik açılır — okuduğun sayfa, eklediğin kelime, okuma süresi '
            've alışkanlıklarına göre. Bir pratik seansını bitirdiğinde yeni bir rozet açıldıysa sana hemen '
            'haber veririm.\n\n'
            'Profil sekmesindeki Rozetler kartına dokunursan Başarı Odası açılır; orada hangi rozete ne '
            'kadar kaldığını görebilirsin.',
          ),
        ),
        CoachQuestion(
          text: 'Günlük görevler ve lig nasıl işliyor?',
          icon: PhosphorIcons.trendUpBold,
          answer: () => _static(
            'Sıralama sekmesinde her gün yenilenen görevler var (örneğin "Günün Kelime Avcısı"). Görevi '
            'tamamlayıp ödülünü aldığında ekstra XP kazanırsın.\n\n'
            'Kazandığın her XP seni ligde yukarı taşır. Profilinde bir üstündeki rakibi geçmek için kaç XP '
            'gerektiğini de görebilirsin.',
          ),
        ),
        CoachQuestion(
          text: '2X XP nedir?',
          icon: PhosphorIcons.lightningBold,
          answer: () => _static(
            'Her gün Arena\'daki modlardan biri (Hızlı Test, SRS Hafıza, Eşleştirme veya Dinle & Yaz) '
            '"2X XP" rozetiyle işaretlenir. O gün o modda kazandığın XP ikiye katlanır.\n\n'
            'Hangi modun şanslı olduğu her gün değişir — Arena\'ya girince ilk ona göz at!',
          ),
        ),
      ],
    ),
    CoachCategory(
      label: 'Okuma',
      icon: PhosphorIcons.bookOpenBold,
      questions: [
        CoachQuestion(
          text: 'Kendi kitabımı ekleyebilir miyim?',
          icon: PhosphorIcons.filePlusBold,
          answer: () => _static(
            'Evet! Dersler sekmesindeki "Kitap Ekle" ile cihazından PDF veya TXT dosyası seçebilirsin. '
            'Kitap sayfalara bölünür ve hazır kitaplar gibi okunur; kelime avı da aynı şekilde çalışır.\n\n'
            'İpucu: seviyene uygun, ilgini çeken bir metin seçmek motivasyonu çok artırır.',
          ),
        ),
        CoachQuestion(
          text: 'Okurken nasıl XP kazanırım?',
          icon: PhosphorIcons.lightningBold,
          answer: () => _static(
            'Okuma seansı bitince XP kazanırsın:\n\n'
            '• Okuduğun her sayfa için 10 XP\n'
            '• Havuzuna eklediğin her kelime için 15 XP\n\n'
            'Seansın sayılması için en az 25 saniye okuman ya da en az 1 kelime eklemen yeterli.',
          ),
        ),
      ],
    ),
    CoachCategory(
      label: 'Ayarlar',
      icon: PhosphorIcons.gearSixBold,
      questions: [
        CoachQuestion(
          text: 'Alışkanlık takibini nerede bulurum?',
          icon: PhosphorIcons.targetBold,
          answer: () => _static(
            'Alışkanlıklar sayfasına birkaç yerden ulaşabilirsin:\n\n'
            '• Ana Sayfa\'nın en üstündeki 🔥 seri sayacına dokun.\n'
            '• Ana Sayfa\'daki kaydırılabilir kartların sonuncusu: "Alışkanlıklarım".\n'
            '• Ana Sayfa\'daki Günlük Seri kartında "Tüm Alışkanlıkları Gör".\n'
            '• Profil\'deki Gelişim panelinde Haftalık Aktivite ya da Seri kartına dokun.\n\n'
            'Orada günlük hedeflerini işaretleyebilir, kendi alışkanlıklarını ekleyebilirsin.',
          ),
        ),
        CoachQuestion(
          text: 'Hatırlatma bildirimlerini nasıl açarım?',
          icon: PhosphorIcons.bellRingingBold,
          answer: () => _static(
            'Profil sekmesinde sağ üstteki dişli simgesine dokun, Bildirimler bölümünde iki seçenek var:\n\n'
            '• Günlük Hatırlatma: seçtiğin saatte pratik hatırlatması.\n'
            '• Seri Kaybı Uyarısı: akşam 21:30\'da, serini kaybetmeden önce uyarı.',
          ),
        ),
        CoachQuestion(
          text: 'Açık temaya nasıl geçerim?',
          icon: PhosphorIcons.circleHalfBold,
          answer: () => _static(
            'Profil sekmesinde sağ üstteki dişli simgesine dokun. Görünüm bölümünden koyu "Zindan" ile açık '
            '"Parşömen" teması arasında geçiş yapabilirsin.',
          ),
        ),
        CoachQuestion(
          text: 'Hesap açmak ne işe yarar?',
          icon: PhosphorIcons.userBold,
          answer: () => _static(
            'Hesap açmak zorunlu değil — Ignis\'i hesapsız da tamamen kullanabilirsin. İlerlemen bu cihazda '
            'saklanır.\n\n'
            'Hesap açarsan Premium üyeliğin hesabına bağlanır; başka bir cihazda aynı hesapla giriş '
            'yaptığında Premium\'un seni orada da bulur. Hesap işlemleri Profil > dişli simgesi > Hesap ve '
            'Veri bölümünde.',
          ),
        ),
      ],
    ),
    CoachCategory(
      label: 'Premium',
      icon: PhosphorIcons.crownBold,
      questions: [
        CoachQuestion(
          text: 'Premium bana ne kazandırır?',
          icon: PhosphorIcons.crownBold,
          answer: _premium,
        ),
        CoachQuestion(
          text: 'Satın alımımı nasıl geri yüklerim?',
          icon: PhosphorIcons.arrowClockwiseBold,
          answer: () => _static(
            'Telefon değiştirdiysen ya da uygulamayı yeniden yüklediysen: Profil sekmesinde sağ üstteki '
            'dişli simgesine dokun, Hesap ve Veri bölümünden "Satın Alımları Geri Yükle"yi seç. Aynı mağaza '
            'hesabıyla yaptığın satın alım birkaç saniye içinde geri gelir.',
          ),
        ),
      ],
    ),
  ];

  // --------------------------------------------------------------------------
  // Gerçek veriye dayalı cevaplar
  // --------------------------------------------------------------------------

  static Future<CoachAnswer> _todayProgress() async {
    final status = await IgnisMomentsEngine.instance.getDailyStatusSnapshot();
    if (!status.hasActivityToday) {
      return const CoachAnswer(
        'Bugün henüz bir pratik seansı görünmüyor. Arena\'da kısa bir tur atarsan ilerlemeni burada '
        'hemen görebilirsin — 2-3 dakika bile fark yaratır!',
      );
    }
    final buffer = StringBuffer()
      ..write('Bugün ${status.newWordsToday} yeni kelime öğrendin ve ${status.reviewsToday} tekrar yaptın. ');
    if (status.dueTomorrow > 0) {
      buffer.write('Yarın ${status.dueTomorrow} kelimenin tekrar vakti geliyor.');
    }
    if (status.weeklyProjection > 0) {
      buffer.write('\n\nBu tempoyla bir haftada yaklaşık ${status.weeklyProjection} kelime öğrenmiş olacaksın 🔥');
    }
    return CoachAnswer(buffer.toString().trim());
  }

  static Future<CoachAnswer> _wordPool() async {
    final db = DatabaseHelper.instance;
    final total = (await db.getFlashcards()).length;
    if (total == 0) {
      return const CoachAnswer(
        'Havuzun şu an boş. Bir kitap açıp bilmediğin kelimelere dokunarak ilk kelimelerini ekleyebilirsin — '
        'Arena\'daki bütün modlar bu havuzdan beslenir.',
      );
    }
    final mastered = await db.getMasteredCount();
    final dueToday = await db.getDueTodayCount();
    final dueLine = dueToday > 0
        ? 'Bugün tekrar vakti gelmiş $dueToday kelime seni bekliyor — Arena\'da "Zindana Gir" ile hepsini halledebilirsin.'
        : 'Bugün tekrar vakti gelmiş kelimen yok, harika! Yeni kelimeler ekleyerek havuzunu büyütebilirsin.';
    return CoachAnswer(
      'Havuzunda toplam $total kelime var; bunların $mastered tanesi kalıcı hafızada.\n\n$dueLine',
    );
  }

  static Future<CoachAnswer> _xp() async {
    final totalXp = await XpShopService.instance.getTotalXp();
    return CoachAnswer(
      'Şu an $totalXp XP\'n var. XP kazanmanın yolları:\n\n'
      '• Arena\'da her doğru cevap (moda göre değişir)\n'
      '• Kitap okumak: sayfa başına 10, eklenen kelime başına 15 XP\n'
      '• Boss kelime yenmek: 20 XP\n'
      '• Sıralama sekmesindeki günlük görevler\n\n'
      'En hızlı yol: günün 2X XP modunu yakalamak — o modda kazandığın her XP ikiye katlanır.',
    );
  }

  static Future<CoachAnswer> _streak() async {
    final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
    final streakDays = streakResult['streakDays'] as int? ?? 0;
    final hasShield = streakResult['hasFreezeShield'] == true;
    final isPremium = EntitlementRepository.instance.isPremium;

    final String shieldNote;
    if (isPremium) {
      shieldNote = 'Premium olduğun için Seri Kalkanın sınırsız — bir gün ara versen bile serin kırılmaz 🛡️';
    } else if (hasShield) {
      shieldNote = 'Ayrıca bir hediye Seri Kalkanın var: bir gün atlarsan otomatik devreye girer ve serini '
          'korur. Tek kullanımlık olduğunu unutma.';
    } else {
      shieldNote = 'Hediye Seri Kalkanını kullandın. Premium\'da kalkan hiç tükenmez, yoğun günlerde bile '
          'serin güvende kalır.';
    }

    final head = streakDays <= 1
        ? 'Serin yeni başlıyor! Her gün Ignis\'e uğrayıp kısa bir tur atman seriyi büyütmeye yeter.'
        : 'Şu an $streakDays günlük bir serin var! Devam ettirmek için her gün Ignis\'e uğrayıp kısa bir tur '
            'atman yeterli.';
    return CoachAnswer('$head\n\n$shieldNote');
  }

  static Future<CoachAnswer> _premium() async {
    if (EntitlementRepository.instance.isPremium) {
      return const CoachAnswer(
        'Sen zaten Premium\'sun 👑 Şunların hepsi açık:\n\n'
        '• Ters Test, Sadece Dinleme ve Hız Turu modları\n'
        '• Sınırsız Seri Kalkanı\n'
        '• Detaylı Ignis içgörüleri\n'
        '• Özel avatar çerçeveleri\n\n'
        'Desteğin için teşekkürler — birlikte daha çok kelime avlayacağız!',
      );
    }
    return const CoachAnswer(
      'Premium, Ignis\'le öğrenmeyi bir üst seviyeye taşır:\n\n'
      '⚔️ 3 ileri pratik modu — Ters Test (Türkçeden İngilizceye), Sadece Dinleme ve 60 saniyelik Hız Turu. '
      '"Zindana Gir" oturumların da bu modlarla zenginleşir. Bir kelimeyi farklı açılardan çalıştıkça '
      'beynin onu çok daha kalıcı öğrenir.\n\n'
      '🛡️ Sınırsız Seri Kalkanı — ücretsiz sürümde tek bir hediye kalkanın var. Premium\'da hiç tükenmez; '
      'yoğun bir günde bile emeğin sıfırlanmaz.\n\n'
      '📈 Detaylı Ignis içgörüleri — haftalık projeksiyonun ve ustalaşma analizin.\n\n'
      '🖼️ 5 özel avatar çerçevesi.\n\n'
      '🔗 Üyeliğin hesabına bağlı; başka bir cihazda giriş yaptığında da seninle.\n\n'
      'Kısacası: daha hızlı, daha kalıcı ve serini hiç kaybetmeden öğrenirsin.\n\n'
      'Premium seçeneklerine göz atmak ister misin?',
      offerPremium: true,
    );
  }
}
