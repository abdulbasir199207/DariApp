/* ============================================================
   30-content: eingebaute Übungsinhalte (Sätze + Grammatik).
   Persisch: Standard-Schriftsprache (Halbleerzeichen/ZWNJ in می‌ … ها).
   HINWEIS: Bitte von einer Person mit Persisch-Kenntnissen gegenlesen.

   Wortarten (pd = Deutsch, pf = Persisch; je Token ein Buchstabe):
   P Pronomen · N Nomen · V Verb · A Adjektiv · D Adverb/Frage · R Präposition · X Sonstiges
   ============================================================ */

const BLANK_POS = 'NVAD';   // Wortarten, die als Lücke taugen

/** S(id, Kategorie, Stufe, de, fa, Lautschrift, pd, pf, Optionen) – Frage-Sätze mit q:1. */
function S(id, cat, lvl, de, fa, tr, pd, pf, o = {}) {
  const q = !!o.q;
  const tk = s => s.split(' ');
  const dt = tk(de), ft = tk(fa);
  return {
    id, cat, lvl, q,
    deT: dt, faT: ft,
    de: de + (q ? '?' : '.'), fa: fa + (q ? '؟' : '.'), tr,
    pd: pd.split(' '), pf: pf.split(' '),
    bd: o.bd || null, bf: o.bf || null,     // erlaubte Lücken-Positionen (optional)
    alts: o.alts || []                       // weitere zulässige persische Wortfolgen (als Strings)
  };
}

const SENTENCES = [
  S('s01', 'Alltag', 1, 'Ich bin müde', 'من خسته‌ام', 'man khaste-am', 'P X A', 'P A'),
  S('s02', 'Alltag', 1, 'Das ist ein Buch', 'این یک کتاب است', 'in yek ketâb ast', 'P X X N', 'P X N X'),
  S('s03', 'Essen', 1, 'Das Wasser ist kalt', 'آب سرد است', 'âb sard ast', 'X N X A', 'N A X'),
  S('s04', 'Alltag', 1, 'Ich habe ein Buch', 'من یک کتاب دارم', 'man yek ketâb dâram', 'P V X N', 'P X N V'),
  S('s05', 'Alltag', 1, 'Wir gehen nach Hause', 'ما به خانه می‌رویم', 'mâ be khâne mi-ravim', 'P V R N', 'P R N V'),
  S('s06', 'Essen', 1, 'Du trinkst Tee', 'تو چای می‌نوشی', 'to châi mi-nushi', 'P V N', 'P N V'),
  S('s07', 'Essen', 1, 'Er isst Brot', 'او نان می‌خورد', 'u nân mi-khorad', 'P V N', 'P N V'),
  S('s08', 'Alltag', 1, 'Sie liest ein Buch', 'او یک کتاب می‌خواند', 'u yek ketâb mi-khânad', 'P V X N', 'P X N V'),
  S('s09', 'Familie', 1, 'Die Mutter kocht das Essen', 'مادر غذا می‌پزد', 'mâdar ghazâ mi-pazad', 'X N V X N', 'N N V'),
  S('s10', 'Familie', 1, 'Mein Vater arbeitet', 'پدرم کار می‌کند', 'pedaram kâr mi-konad', 'X N V', 'N N V'),
  S('s11', 'Familie', 1, 'Ich liebe meine Familie', 'من خانواده‌ام را دوست دارم', 'man khânevâde-am râ dust dâram', 'P V X N', 'P N R N V', { bf: [1] }),
  S('s12', 'Fragen', 1, 'Wo ist das Haus', 'خانه کجاست', 'khâne kojâst', 'D X X N', 'N D', { q: 1 }),
  S('s13', 'Fragen', 1, 'Wie heißt du', 'نام تو چیست', 'nâm-e to chist', 'D V P', 'N P X', { q: 1, bd: [0] , bf: [0] }),
  S('s14', 'Vorstellen', 1, 'Mein Name ist Ali', 'نام من علی است', 'nâm-e man Ali ast', 'X N X N', 'N P N X', { bf: [0] }),
  S('s15', 'Vorstellen', 1, 'Ich komme aus Deutschland', 'من از آلمان می‌آیم', 'man az âlmân mi-âyam', 'P V R N', 'P R N V'),
  S('s16', 'Vorstellen', 1, 'Ich lerne Persisch', 'من فارسی یاد می‌گیرم', 'man fârsi yâd mi-giram', 'P V N', 'P N N V', { bf: [1, 3] }),
  S('s17', 'Alltag', 1, 'Das Kind spielt im Garten', 'کودک در باغ بازی می‌کند', 'kudak dar bâgh bâzi mi-konad', 'X N V R N', 'N R N N V', { bf: [0, 2] }),
  S('s18', 'Essen', 1, 'Wir trinken zusammen Tee', 'ما با هم چای می‌نوشیم', 'mâ bâ ham châi mi-nushim', 'P V D N', 'P R P N V', { bf: [3, 4] }),
  S('s19', 'Alltag', 1, 'Ich sehe einen Freund', 'من یک دوست را می‌بینم', 'man yek dust râ mi-binam', 'P V X N', 'P X N R V'),
  S('s20', 'Essen', 1, 'Das Essen ist gut', 'غذا خوب است', 'ghazâ khub ast', 'X N X A', 'N A X'),
  S('s21', 'Wetter', 1, 'Heute ist es heiß', 'امروز هوا گرم است', 'emruz havâ garm ast', 'D X X A', 'D N A X'),
  S('s22', 'Alltag', 2, 'Wir wohnen in einer Stadt', 'ما در یک شهر زندگی می‌کنیم', 'mâ dar yek shahr zendegi mi-konim', 'P V R X N', 'P R X N N V', { bf: [3, 4] }),
  S('s23', 'Essen', 1, 'Ich möchte Wasser', 'من آب می‌خواهم', 'man âb mi-khâham', 'P V N', 'P N V'),
  S('s24', 'Fragen', 1, 'Hast du Hunger', 'تو گرسنه‌ای', 'to gorosne-i', 'V P N', 'P A', { q: 1 }),
  S('s25', 'Schule', 1, 'Die Schule ist groß', 'مدرسه بزرگ است', 'madrese bozorg ast', 'X N X A', 'N A X'),
  S('s26', 'Schule', 1, 'Er geht zur Schule', 'او به مدرسه می‌رود', 'u be madrese mi-ravad', 'P V R N', 'P R N V'),
  S('s27', 'Zeit', 2, 'Ich habe gestern ein Buch gelesen', 'من دیروز یک کتاب خواندم', 'man diruz yek ketâb khândam', 'P V D X N V', 'P D X N V', { bd: [2, 4, 5] }),
  S('s28', 'Zeit', 2, 'Wir sind gestern nach Hause gegangen', 'ما دیروز به خانه رفتیم', 'mâ diruz be khâne raftim', 'P V D R N V', 'P D R N V', { bd: [2, 4, 5] }),
  S('s29', 'Essen', 2, 'Er hat Brot gegessen', 'او نان خورد', 'u nân khord', 'P V N V', 'P N V', { bd: [2, 3] }),
  S('s30', 'Zeit', 2, 'Ich werde morgen kommen', 'من فردا خواهم آمد', 'man fardâ khâham âmad', 'P V D V', 'P D V V', { bd: [2, 3], bf: [1, 3] }),
  S('s31', 'Essen', 2, 'Ich esse kein Fleisch', 'من گوشت نمی‌خورم', 'man gusht nemi-khoram', 'P V X N', 'P N V'),
  S('s32', 'Alltag', 2, 'Das ist kein Haus', 'این خانه نیست', 'in khâne nist', 'P X X N', 'P N V', { bf: [1] }),
  S('s33', 'Alltag', 2, 'Die Bücher sind auf dem Tisch', 'کتاب‌ها روی میز هستند', 'ketâb-hâ ruye miz hastand', 'X N V R X N', 'N R N V', { bd: [1, 5] }),
  S('s34', 'Alltag', 2, 'Der Mann liest die Zeitung', 'مرد روزنامه را می‌خواند', 'mard ruznâme râ mi-khânad', 'X N V X N', 'N N R V'),
  S('s35', 'Familie', 2, 'Sie sind meine Freunde', 'آن‌ها دوستان من هستند', 'ânhâ dustân-e man hastand', 'P V X N', 'P N P V', { bd: [3] , bf: [1] }),
  S('s36', 'Familie', 2, 'Ich habe zwei Brüder', 'من دو برادر دارم', 'man do barâdar dâram', 'P V X N', 'P X N V'),
  S('s37', 'Fragen', 2, 'Wo wohnst du', 'تو کجا زندگی می‌کنی', 'to kojâ zendegi mi-koni', 'D V P', 'P D N V', { q: 1, bf: [1, 2] }),
  S('s38', 'Fragen', 2, 'Was machst du', 'تو چه کار می‌کنی', 'to che kâr mi-koni', 'D V P', 'P D N V', { q: 1, bf: [1, 2] }),
  S('s39', 'Alltag', 2, 'Ich verstehe dich nicht', 'من تو را نمی‌فهمم', 'man to râ nemi-fahmam', 'P V P X', 'P P R V'),
  S('s40', 'Alltag', 2, 'Sie hat ein schönes Haus', 'او خانه‌ای زیبا دارد', 'u khâne-i zibâ dârad', 'P V X A N', 'P N A V'),
  S('s41', 'Zeit', 2, 'Morgen gehe ich zur Arbeit', 'فردا من به سر کار می‌روم', 'fardâ man be sar-e kâr mi-ravam', 'D V P R N', 'D P R N N V', { bd: [0, 4], bf: [0, 4, 5] }),
  S('s42', 'Schule', 2, 'Der Lehrer spricht Persisch', 'معلم فارسی صحبت می‌کند', 'mo\'allem fârsi sohbat mi-konad', 'X N V N', 'N N N V', { bf: [0, 1] }),
  S('s43', 'Familie', 2, 'Meine Schwester trinkt Milch', 'خواهرم شیر می‌نوشد', 'khâharam shir mi-nushad', 'X N V N', 'N N V'),
  S('s44', 'Schule', 2, 'Wir lernen zusammen', 'ما با هم درس می‌خوانیم', 'mâ bâ ham dars mi-khânim', 'P V D', 'P R P N V', { bf: [3, 4] }),
  S('s45', 'Vorstellen', 1, 'Ich bin Student', 'من دانشجو هستم', 'man dâneshju hastam', 'P X N', 'P N X'),
  S('s46', 'Fragen', 2, 'Wie alt bist du', 'تو چند ساله‌ای', 'to chand sâle-i', 'D A X P', 'P D A', { q: 1, bd: [1] }),
  S('s47', 'Wetter', 2, 'Heute regnet es', 'امروز باران می‌بارد', 'emruz bârân mi-bârad', 'D V X', 'D N V', { bf: [1, 2] }),
  S('s48', 'Wetter', 2, 'Im Winter ist es kalt', 'در زمستان هوا سرد است', 'dar zemestân havâ sard ast', 'R N X X A', 'R N N A X', { bd: [1, 4], bf: [1, 3] }),
  S('s49', 'Reisen', 2, 'Wir fahren mit dem Bus', 'ما با اتوبوس می‌رویم', 'mâ bâ otobus mi-ravim', 'P V R X N', 'P R N V'),
  S('s50', 'Reisen', 2, 'Der Zug kommt um acht Uhr', 'قطار ساعت هشت می‌آید', 'ghatâr sâ\'at-e hasht mi-âyad', 'X N V R X N', 'N N X V', { bd: [1, 2], bf: [0, 3] })
];

/** G(id, Sprache, Thema, Frage, [richtig, falsch…], Erklärung, persische Erklärung) */
function G(id, lang, topic, q, a, e, x = '') { return { id, lang, topic, q, a, e, x }; }

const GRAMMAR = [
  /* ----- Persisch (Erklärungen auf Deutsch) ----- */
  G('g01', 'fa', 'Pronomen', 'Welches persische Wort bedeutet „wir"?', ['ما', 'شما', 'آن‌ها', 'من'], 'Singular: من (ich), تو (du), او (er/sie/es). Plural: ما (wir), شما (ihr/Sie), آن‌ها (sie).'),
  G('g02', 'fa', 'Pronomen', 'Wie heißt „ihr / Sie (höflich)" auf Persisch?', ['شما', 'ما', 'تو', 'او'], 'شما ist die Plural- und zugleich die Höflichkeitsform. تو benutzt man nur unter Vertrauten.'),
  G('g03', 'fa', 'Pronomen', '___ دانشجو هستم. (Ich bin Student.)', ['من', 'تو', 'او', 'ما'], 'Das Verb هستم (-am) gehört zu من (ich).'),
  G('g04', 'fa', 'Pronomen', 'Was bedeutet das Pronomen او?', ['er, sie oder es', 'nur „er"', 'nur „sie"', 'wir'], 'Persisch kennt kein grammatisches Geschlecht: او steht für er und sie.'),
  G('g05', 'fa', 'Verb „sein"', 'من دانشجو ___ . (Ich bin Student.)', ['هستم', 'هستی', 'است', 'هستند'], 'هستم, هستی, است, هستیم, هستید, هستند – die Endung zeigt die Person.'),
  G('g06', 'fa', 'Verb „sein"', 'او خسته ___ . (Er ist müde.)', ['است', 'هستم', 'هستیم', 'هستید'], 'Für er/sie/es steht است (Schrift: خسته است).'),
  G('g07', 'fa', 'Verb „sein"', 'آن‌ها دوست ___ . (Sie sind Freunde.)', ['هستند', 'هستم', 'است', 'هستی'], 'Die 3. Person Plural endet auf -ند: هستند.'),
  G('g08', 'fa', 'Verb „sein"', 'ما خوشحال ___ . (Wir sind froh.)', ['هستیم', 'هستم', 'هستند', 'است'], 'Die 1. Person Plural endet auf -یم: هستیم.'),
  G('g09', 'fa', 'Gegenwart', 'Wie bildet man die Gegenwart im Persischen?', ['می‌ + Verbstamm + Personalendung', 'Hilfsverb + Infinitiv', 'Infinitiv + هستم', 'Nur den Verbstamm'], 'Beispiel: می‌ + رو + م = می‌روم (ich gehe). Das Präfix می‌ markiert die Dauer/Gegenwart.'),
  G('g10', 'fa', 'Gegenwart', 'من آب ___ . (trinken)', ['می‌نوشم', 'می‌نوشی', 'می‌نوشد', 'می‌نوشیم'], 'Endungen in der Gegenwart: -م, -ی, -د, -یم, -ید, -ند.'),
  G('g11', 'fa', 'Gegenwart', 'او نان ___ . (essen)', ['می‌خورد', 'می‌خورم', 'می‌خوری', 'می‌خورند'], 'او (3. Person Singular) bekommt die Endung -د.'),
  G('g12', 'fa', 'Gegenwart', 'ما به مدرسه ___ . (gehen)', ['می‌رویم', 'می‌روم', 'می‌رود', 'می‌روند'], 'ما (wir) verlangt die Endung -یم.'),
  G('g13', 'fa', 'Gegenwart', 'تو کتاب ___ . (lesen)', ['می‌خوانی', 'می‌خوانم', 'می‌خواند', 'می‌خوانید'], 'تو (du) verlangt die Endung -ی.'),
  G('g14', 'fa', 'Vergangenheit', 'Wie bildet man die einfache Vergangenheit?', ['Vergangenheitsstamm + Personalendung', 'می‌ + Verbstamm', 'خواهـ + Stamm', 'Stamm + ـی'], 'Beispiel: رفت + م = رفتم (ich ging). In der 3. Person Singular steht nur der Stamm: رفت.'),
  G('g15', 'fa', 'Vergangenheit', 'دیروز من نان ___ . (aß)', ['خوردم', 'می‌خورم', 'خوردی', 'خورد'], 'Vergangenheitsstamm خورد + م (ich).'),
  G('g16', 'fa', 'Vergangenheit', 'او دیروز به خانه ___ . (ging)', ['رفت', 'رفتم', 'می‌رود', 'رفتند'], 'Die 3. Person Singular hat keine Endung: رفت.'),
  G('g17', 'fa', 'Vergangenheit', 'ما کتاب ___ . (lasen)', ['خواندیم', 'خواندم', 'می‌خوانیم', 'خواند'], 'Vergangenheitsstamm خواند + یم (wir).'),
  G('g18', 'fa', 'Verneinung', 'Wie verneint man ein Verb?', ['Mit der Vorsilbe ن direkt vor dem Verb (می‌ → نمی‌)', 'Mit dem Wort نه am Satzende', 'Mit بدون vor dem Verb', 'Gar nicht – nur durch die Betonung'], 'Beispiel: می‌خورم → نمی‌خورم (ich esse nicht). In der Vergangenheit: خوردم → نخوردم.'),
  G('g19', 'fa', 'Verneinung', 'من گوشت ___ . (Ich esse kein Fleisch.)', ['نمی‌خورم', 'می‌خورم', 'خوردم', 'نمی‌خوری'], 'ن + می‌خورم = نمی‌خورم.'),
  G('g20', 'fa', 'Verneinung', 'Was bedeutet او نمی‌آید?', ['Er/sie kommt nicht', 'Er/sie kam', 'Er/sie kommt', 'Wir kommen nicht'], 'نمی‌آید = Verneinung von می‌آید (er/sie kommt).'),
  G('g21', 'fa', 'Wortstellung', 'Wie lautet die normale Satzstellung im Persischen?', ['Subjekt – Objekt – Verb', 'Subjekt – Verb – Objekt', 'Verb – Subjekt – Objekt', 'Objekt – Verb – Subjekt'], 'Das Verb steht normalerweise am Satzende: من چای می‌نوشم (ich Tee trinke).'),
  G('g22', 'fa', 'Wortstellung', 'Welcher Satz ist richtig? „Ich trinke Tee."', ['من چای می‌نوشم', 'من می‌نوشم چای', 'می‌نوشم چای من', 'می‌نوشم من چای'], 'Subjekt – Objekt – Verb.'),
  G('g23', 'fa', 'Wortstellung', 'Welcher Satz ist richtig? „Er geht zur Schule."', ['او به مدرسه می‌رود', 'می‌رود به مدرسه او', 'مدرسه به می‌رود او', 'به او مدرسه می‌رود'], 'Das Verb می‌رود steht am Ende.'),
  G('g24', 'fa', 'Plural', 'Wie lautet der Plural von کتاب (Buch)?', ['کتاب‌ها', 'کتابان', 'کتابات', 'کتابین'], 'Standard-Pluralendung ist ‌ها (mit Halbleerzeichen). Bei Lebewesen auch ـان: دوستان.'),
  G('g25', 'fa', 'Plural', 'Wie steht das Nomen nach einer Zahl? „zwei Bücher"', ['im Singular: دو کتاب', 'im Plural: دو کتاب‌ها', 'mit ـان: دو کتابان', 'mit را: دو کتاب را'], 'Nach Zahlwörtern bleibt das Nomen im Singular: دو کتاب, سه برادر.'),
  G('g26', 'fa', 'Unbestimmt & را', 'Was drückt das angehängte ـی in خانه‌ای aus?', ['unbestimmt: „ein Haus"', 'Plural', 'Vergangenheit', 'eine Frage'], 'Das Suffix ـی macht ein Nomen unbestimmt: خانه‌ای (ein Haus), کتابی (ein Buch).'),
  G('g27', 'fa', 'Unbestimmt & را', 'Wozu dient را?', ['Es markiert das bestimmte direkte Objekt', 'Es bedeutet „und"', 'Es ist die Verneinung', 'Es bildet den Plural'], 'Beispiel: مرد را می‌بینم (Ich sehe den Mann). را steht direkt hinter dem Objekt.'),
  G('g28', 'fa', 'Unbestimmt & را', 'Welcher Satz ist richtig? „Ich sehe den Mann."', ['من مرد را می‌بینم', 'من را مرد می‌بینم', 'من مرد می‌بینم را', 'را من مرد می‌بینم'], 'را folgt dem bestimmten Objekt, das Verb steht am Ende.'),
  G('g29', 'fa', 'Fragewörter', 'Was bedeutet کجا?', ['wo / wohin', 'wann', 'warum', 'wer'], 'کجا = wo/wohin, کی = wann, چرا = warum, چه کسی = wer, چه = was.'),
  G('g30', 'fa', 'Fragewörter', 'Wie heißt „wann?" auf Persisch?', ['کی', 'کجا', 'چرا', 'چه'], 'کی = wann.'),
  G('g31', 'fa', 'Fragewörter', 'Wie heißt „warum?" auf Persisch?', ['چرا', 'کی', 'کجا', 'چند'], 'چرا = warum. چند = wie viele.'),
  G('g32', 'fa', 'Fragewörter', 'Was bedeutet چه کسی?', ['wer', 'was', 'wo', 'wie viel'], 'چه کسی = wer. چه = was.'),
  G('g33', 'fa', 'Besitz', 'Was bedeutet کتابم?', ['mein Buch', 'dein Buch', 'sein Buch', 'unser Buch'], 'Besitz-Suffixe: ‌م (mein), ‌ت (dein), ‌ش (sein/ihr), ‌مان (unser), ‌تان (euer), ‌شان (ihr).'),
  G('g34', 'fa', 'Besitz', 'Wie sagt man „dein Haus"?', ['خانه‌ات', 'خانه‌ام', 'خانه‌اش', 'خانه‌مان'], 'Das Suffix für „dein" ist ‌ت – nach Vokalen mit ا: خانه‌ات.'),
  G('g35', 'fa', 'Besitz', 'Was bedeutet پدرش?', ['sein/ihr Vater', 'mein Vater', 'dein Vater', 'unser Vater'], 'Das Suffix ‌ش steht für „sein/ihr".'),
  G('g36', 'fa', 'Ezafe', 'Wofür steht das Ezafe (-e), z. B. in ketâb-e bozorg?', ['Es verbindet ein Nomen mit Adjektiv oder Besitzer; man schreibt es meist nicht', 'Es verbindet zwei Sätze und wird immer geschrieben', 'Es verbindet Verb und Objekt', 'Es drückt die Verneinung aus'], 'Beispiele: کتابِ بزرگ (großes Buch), کتابِ علی (Alis Buch). Gesprochen -e, geschrieben meist gar nicht.'),

  /* ----- Deutsch (Erklärungen auf Deutsch + Persisch) ----- */
  G('d01', 'de', 'Artikel', '___ Haus', ['das', 'der', 'die'], 'Das Haus – sächlich (خنثی).', 'اسم‌های خنثی «das» می‌گیرند: das Haus.'),
  G('d02', 'de', 'Artikel', '___ Mutter', ['die', 'der', 'das'], 'Die Mutter – weiblich (مؤنث).', 'اسم‌های مؤنث «die» می‌گیرند: die Mutter.'),
  G('d03', 'de', 'Artikel', '___ Vater', ['der', 'die', 'das'], 'Der Vater – männlich (مذکر).', 'اسم‌های مذکر «der» می‌گیرند: der Vater.'),
  G('d04', 'de', 'Artikel', '___ Wasser', ['das', 'der', 'die'], 'Das Wasser – sächlich.', 'das Wasser = آب.'),
  G('d05', 'de', 'Artikel', '___ Brot', ['das', 'der', 'die'], 'Das Brot – sächlich.', 'das Brot = نان.'),
  G('d06', 'de', 'Artikel', '___ Tisch', ['der', 'die', 'das'], 'Der Tisch – männlich.', 'der Tisch = میز.'),
  G('d07', 'de', 'Artikel', '___ Kind', ['das', 'der', 'die'], 'Das Kind – sächlich.', 'das Kind = کودک.'),
  G('d08', 'de', 'Artikel', '___ Straße', ['die', 'der', 'das'], 'Die Straße – weiblich.', 'die Straße = خیابان.'),
  G('d09', 'de', 'Artikel', '___ Auto', ['das', 'der', 'die'], 'Das Auto – sächlich.', 'das Auto = ماشین.'),
  G('d10', 'de', 'Verb-Endungen', 'Ich ___ nach Hause. (gehen)', ['gehe', 'gehst', 'geht', 'gehen'], 'ich → -e: ich gehe.', 'برای «ich» پسوند -e می‌آید.'),
  G('d11', 'de', 'Verb-Endungen', 'Du ___ Tee. (trinken)', ['trinkst', 'trinke', 'trinkt', 'trinken'], 'du → -st: du trinkst.', 'برای «du» پسوند -st می‌آید.'),
  G('d12', 'de', 'Verb-Endungen', 'Er ___ Brot. (essen)', ['isst', 'esse', 'esst', 'essen'], 'essen ist unregelmäßig: ich esse, du isst, er isst.', 'فعل essen بی‌قاعده است: er isst.'),
  G('d13', 'de', 'Verb-Endungen', 'Wir ___ Persisch. (lernen)', ['lernen', 'lerne', 'lernst', 'lernt'], 'wir → -en: wir lernen.', 'برای «wir» پسوند -en می‌آید.'),
  G('d14', 'de', 'Verb-Endungen', 'Ihr ___ gut. (arbeiten)', ['arbeitet', 'arbeite', 'arbeitest', 'arbeiten'], 'ihr → -t: ihr arbeitet.', 'برای «ihr» پسوند -t می‌آید.'),
  G('d15', 'de', 'Verb-Endungen', 'Sie ___ ein Buch. (lesen – sie, eine Frau)', ['liest', 'lese', 'lies', 'lest'], 'lesen ändert den Vokal: er/sie liest.', 'فعل lesen تغییر مصوت دارد: sie liest.'),
  G('d16', 'de', 'sein & haben', 'Ich ___ müde. (sein)', ['bin', 'bist', 'ist', 'sind'], 'sein: ich bin, du bist, er ist, wir sind, ihr seid, sie sind.', 'فعل sein: ich bin.'),
  G('d17', 'de', 'sein & haben', 'Wir ___ Freunde. (sein)', ['sind', 'seid', 'ist', 'bin'], 'wir sind.', 'برای «wir» می‌گوییم: wir sind.'),
  G('d18', 'de', 'sein & haben', 'Ich ___ ein Buch. (haben)', ['habe', 'hast', 'hat', 'haben'], 'haben: ich habe, du hast, er hat, wir haben.', 'فعل haben: ich habe.'),
  G('d19', 'de', 'Wortstellung', 'Welcher Satz ist richtig?', ['Heute trinke ich Tee.', 'Heute ich trinke Tee.', 'Ich Tee trinke heute.', 'Trinke Tee ich heute.'], 'Das konjugierte Verb steht im Aussagesatz immer an zweiter Stelle.', 'در جملهٔ خبری فعل صرف‌شده همیشه در جایگاه دوم می‌آید.'),
  G('d20', 'de', 'Wortstellung', 'An welcher Stelle steht das konjugierte Verb im Aussagesatz?', ['an zweiter Stelle', 'am Satzende', 'am Satzanfang', 'an dritter Stelle'], 'Position 2: Ich | trinke | Tee. / Heute | trinke | ich Tee.', 'فعل در جایگاه دوم است (برخلاف فارسی که فعل آخر می‌آید).'),
  G('d21', 'de', 'Perfekt', 'Gestern habe ich ein Buch ___. (lesen)', ['gelesen', 'gelest', 'lesen', 'geliest'], 'Perfekt: haben + Partizip II. lesen → gelesen.', 'گذشتهٔ نقلی: haben + اسم مفعول (gelesen).'),
  G('d22', 'de', 'Perfekt', 'Wir sind nach Hause ___. (gehen)', ['gegangen', 'gegeht', 'gehen', 'gegehen'], 'Bewegungsverben bilden das Perfekt mit sein: wir sind gegangen.', 'افعال حرکتی با sein ساخته می‌شوند: wir sind gegangen.'),
  G('d23', 'de', 'Perfekt', 'Er hat Brot ___. (essen)', ['gegessen', 'geessen', 'gegesst', 'essen'], 'essen → gegessen (unregelmäßig).', 'essen → gegessen.'),
  G('d24', 'de', 'Verneinung', 'Ich habe ___ Auto.', ['kein', 'nicht', 'keine', 'nichts'], '„kein" verneint Nomen mit unbestimmtem Artikel: ein Auto → kein Auto.', 'برای نفی اسم با ein از kein استفاده می‌کنیم.'),
  G('d25', 'de', 'Verneinung', 'Ich komme ___.', ['nicht', 'kein', 'keine', 'nie'], '„nicht" verneint Verben und Adjektive.', 'برای نفی فعل از nicht استفاده می‌کنیم.'),
  G('d26', 'de', 'Plural', 'Plural von „das Buch":', ['die Bücher', 'die Buchs', 'die Buchen', 'die Büchers'], 'das Buch → die Bücher (Umlaut + -er).', 'جمع: die Bücher.'),
  G('d27', 'de', 'Plural', 'Plural von „der Tisch":', ['die Tische', 'die Tischer', 'die Tischen', 'die Tischs'], 'der Tisch → die Tische.', 'جمع: die Tische.'),
  G('d28', 'de', 'Plural', 'Plural von „die Frau":', ['die Frauen', 'die Fraue', 'die Fräuer', 'die Fraus'], 'die Frau → die Frauen.', 'جمع: die Frauen.'),
  G('d29', 'de', 'Akkusativ', 'Ich sehe ___ Mann.', ['den', 'der', 'dem', 'des'], 'Der Akkusativ verändert nur „der": der Mann → den Mann.', 'در حالت مفعولی فقط der به den تبدیل می‌شود.'),
  G('d30', 'de', 'Akkusativ', 'Ich habe ___ Hund.', ['einen', 'ein', 'einem', 'eine'], 'ein Hund → (Akkusativ) einen Hund.', 'در حالت مفعولی: einen Hund.')
];

const GRAMMAR_TOPICS = {
  fa: [...new Set(GRAMMAR.filter(g => g.lang === 'fa').map(g => g.topic))],
  de: [...new Set(GRAMMAR.filter(g => g.lang === 'de').map(g => g.topic))]
};
