// Sözleşme/aydınlatma metinleri — uygulama içinde metin olarak gösterilir
// (PDF kullanılmaz). İçerik sırayla eklenir; henüz eklenmemiş metinler için
// kLegalTexts anahtarı bulunmaz ve ekranda "yakında" notu gösterilir.

/// Bir metnin tek bir bölümü: opsiyonel başlık + paragraflar.
/// Paragraf içinde `**...**` ile yazılan kısımlar kalın gösterilir.
class LegalSection {
  final String? heading;
  final List<String> paragraphs;
  const LegalSection({this.heading, this.paragraphs = const []});
}

/// Başlık → bölümler eşlemesi. Anahtar, Sözleşmeler listesindeki başlıkla aynı.
const Map<String, List<LegalSection>> kLegalTexts = {
  'Açık Rıza Metni': [
    LegalSection(
      heading: '1. Genel açıklama',
      paragraphs: [
        'Bu Açık Rıza Metni, Gezgah tarafından sunulan bazı opsiyonel veya '
            'kullanıcı tercihine bağlı özellikler kapsamında kişisel '
            'verilerinizin işlenmesine ve/veya aktarılmasına ilişkin açık rıza '
            'beyanlarını içerir. Açık rıza vermek zorunda değilsiniz. Açık rıza '
            'vermemeniz, ilgili opsiyonel özelliğin kullanılamamasına veya '
            'sınırlı çalışmasına yol açabilir; ancak temel uygulama '
            'kullanımınız mümkün olduğu ölçüde devam eder.',
        'Açık rızanızı dilediğiniz zaman uygulama içi ayarlardan veya Gezgah '
            'ile iletişime geçerek geri alabilirsiniz. Rızanın geri alınması, '
            'geri alma tarihinden önce rızaya dayanılarak yapılan işlemleri '
            'hukuka aykırı hale getirmez.',
        '**Uygulama notu:** Açık rıza kutuları önceden işaretli olmamalı; KVKK '
            'Aydınlatma Metni ile aynı kutuda sunulmamalı; her rıza konusu ayrı '
            've anlaşılır şekilde gösterilmelidir.',
      ],
    ),
    LegalSection(
      heading: '2. Konum tabanlı keşif açık rızası',
      paragraphs: [
        'Yakınımdaki mekanları, etkinlikleri, park/mesire alanlarını ve '
            'plajları görebilmem; bana uzaklık bilgisi sunulması; harita ve yol '
            'tarifi deneyiminin kişiselleştirilmesi amacıyla konum verilerimin '
            'Gezgah tarafından işlenmesine açık rıza veriyorum.',
        'Bu izni cihaz ayarlarımdan veya uygulama ayarlarından her zaman '
            'kapatabileceğimi biliyorum.',
      ],
    ),
    LegalSection(
      heading: '3. Kedy yapay zeka açık rızası',
      paragraphs: [
        'Kedy yapay zeka asistanına yazdığım veya söylediğim sorguların, mekan '
            'önerisi ve sohbet deneyimi sunulması, hizmet kalitesinin '
            'iyileştirilmesi, güvenlik kontrolleri ve ürün geliştirme '
            'amaçlarıyla Gezgah tarafından işlenmesine açık rıza veriyorum.',
        'Kedy altyapısında üçüncü taraf yapay zeka veya bulut hizmet '
            'sağlayıcıları kullanılabileceğini; yurt dışı aktarım söz konusuysa '
            'bunun ayrıca bilgilendirme ve hukuki şartlara tabi olduğunu '
            'biliyorum. Kedy\u2019ye özel nitelikli kişisel veri, gizli bilgi, '
            'ödeme bilgisi, şifre veya üçüncü kişilere ait kişisel veri '
            'yazmamam gerektiğini kabul ediyorum.',
      ],
    ),
    LegalSection(
      heading: '4. Pazarlama ve kişiselleştirilmiş öneri açık rızası',
      paragraphs: [
        'Gezgah\u2019ın kullanım tercihlerim, favorilerim, arama geçmişim, '
            'mekan/etkinlik görüntüleme davranışım ve konum tercihlerim '
            'doğrultusunda bana kampanya, sponsorlu mekan, etkinlik, fırsat, '
            'öneri ve reklam içerikleri sunabilmesi amacıyla kişisel '
            'verilerimin işlenmesine açık rıza veriyorum.',
        'Bu rıza ticari elektronik ileti onayından ayrıdır. Ticari bildirim '
            'almak istemiyorsam bildirim ve ticari ileti izinlerimi ayrıca '
            'kapatabileceğimi biliyorum.',
      ],
    ),
    LegalSection(
      heading:
          '5. Değerlendirme ve puanların yayınlanmasına ilişkin rıza/bilgilendirme',
      paragraphs: [
        'Uygulama üzerinden yaptığım değerlendirme ve puanların ilgili '
            'işletmeye Gezgah Pro üzerinden gösterilebileceğini biliyorum. '
            'Gezgah\u2019ın ileride değerlendirme sistemini kullanıcı '
            'uygulamasında aktif etmesi halinde, değerlendirmelerimin kullanıcı '
            'adım, rumuzum veya anonimleştirilmiş bilgilerle yayınlanabileceği '
            'konusunda ayrıca bilgilendirileceğimi; yayına alınan '
            'değerlendirmem için kaldırma/düzeltme talebinde bulunabileceğimi '
            'kabul ediyorum.',
      ],
    ),
    LegalSection(
      heading: '6. Yurt dışı aktarım rızası - gerekiyorsa kullanılacak ayrı metin',
      paragraphs: [
        '**Kritik not:** Bu bölüm yalnızca teknik altyapıda yurt dışına veri '
            'aktarımı varsa ve KVKK kapsamında uygun aktarım mekanizmaları '
            'dışında açık rızaya başvurulması gerekiyorsa kullanılmalıdır. '
            'Gerekmiyorsa uygulama ekranına eklenmemelidir.',
        'Gezgah\u2019ın kullandığı [bulut/barındırma/yapay '
            'zeka/analitik/bildirim/harita] hizmet sağlayıcılarının yurt '
            'dışında bulunması veya sunucularının yurt dışında yer alması '
            'nedeniyle, ilgili kişisel verilerimin hizmetin sunulması, '
            'güvenlik, analitik, yapay zeka çıktısı üretimi ve teknik altyapı '
            'amaçlarıyla yurt dışındaki hizmet sağlayıcılara aktarılmasına açık '
            'rıza veriyorum.',
      ],
    ),
    LegalSection(
      heading: '7. Önerilen uygulama içi onay kutuları',
      paragraphs: [
        'Bu bölüm PDF\u2019de tablo olarak sunulduğu için talebiniz '
            'doğrultusunda çıkarılmıştır.',
      ],
    ),
  ],
  'Gizlilik Politikası': [
    LegalSection(
      heading: '1. Genel yaklaşım',
      paragraphs: [
        'Gezgah, kullanıcıların kişisel verilerinin güvenliğine ve gizliliğine '
            'önem verir. Bu Gizlilik Politikası, Gezgah uygulamasını '
            'kullanırken hangi bilgilerin toplanabileceğini, bu bilgilerin '
            'hangi amaçlarla kullanılabileceğini, kimlerle paylaşılabileceğini '
            've kullanıcıların tercihlerini nasıl yönetebileceğini açıklar.',
        'Bu politika, KVKK Aydınlatma Metni\u2019nin yerine geçmez. KVKK '
            'kapsamındaki ayrıntılı veri işleme bilgileri için ayrıca '
            '\u201cGezgah KVKK Aydınlatma Metni\u201d incelenmelidir.',
      ],
    ),
    LegalSection(
      heading: '2. Toplanan bilgiler',
      paragraphs: [
        'Gezgah; hesap oluşturma, mekan keşfi, yemek/mekan araması, sesli '
            'arama, favori ekleme, bildirim alma, değerlendirme yapma, '
            'rezervasyon talebi oluşturma, depozito/ön ödeme yapma, Kedy yapay '
            'zeka asistanını kullanma ve destek talebi gönderme süreçlerinde '
            'çeşitli bilgiler toplayabilir.',
      ],
    ),
    LegalSection(
      heading: '3. Bilgilerin kullanım amaçları',
      paragraphs: [
        '• Hesabın oluşturulması ve yönetilmesi.',
        '• Mekan, menü, etkinlik, park, mesire alanı ve plaj keşif '
            'özelliklerinin sunulması.',
        '• Arama, sesli arama, filtreleme, favoriler ve kişiselleştirilmiş '
            'öneri deneyiminin sağlanması.',
        '• Konum tabanlı yakınlık, harita ve yol tarifi özelliklerinin '
            'çalıştırılması.',
        '• Kedy yapay zeka asistanı ile mekan önerisi ve sohbet deneyimi '
            'sunulması.',
        '• Rezervasyon taleplerinin işletmelere iletilmesi; onay, ret, iptal ve '
            'iletişim süreçlerinin yürütülmesi.',
        '• Depozito/ön ödeme, işlem ücreti, iade ve muhasebe süreçlerinin '
            'yürütülmesi.',
        '• Kullanıcı destek taleplerinin cevaplanması, hata giderme ve hizmet '
            'kalitesinin artırılması.',
        '• Güvenlik, dolandırıcılık, spam ve kötüye kullanımın önlenmesi.',
        '• Kullanıcı onayları doğrultusunda kampanya, etkinlik, sponsorlu '
            'içerik ve pazarlama bildirimlerinin gönderilmesi.',
      ],
    ),
    LegalSection(
      heading: '4. Konum verisi',
      paragraphs: [
        'Konum verisi; kullanıcının yakınındaki mekanları, parkları, plajları '
            've etkinlikleri göstermek; kullanıcıya uzaklık bilgisi sunmak; '
            'harita ve yol tarifi deneyimini iyileştirmek için kullanılabilir. '
            'Kullanıcı cihaz ayarlarından konum iznini kapatabilir. Konum izni '
            'kapalı olduğunda bazı özellikler sınırlı çalışabilir; ancak '
            'kullanıcı genel mekan arama ve kategori görüntüleme gibi temel '
            'özelliklerden yararlanabilir.',
      ],
    ),
    LegalSection(
      heading: '5. Mikrofon erişimi',
      paragraphs: [
        'Mikrofon erişimi yalnızca kullanıcı sesli arama özelliğini '
            'başlattığında kullanılır. Gezgah mikrofon erişimini arka planda '
            'sürekli dinleme amacıyla kullanmaz. Sesli komutlar arama sorgusuna '
            'dönüştürülerek mekan veya yemek araması için işlenebilir. Kullanıcı '
            'cihaz ayarlarından mikrofon iznini kapatabilir.',
      ],
    ),
    LegalSection(
      heading: '6. Bildirimler ve reklam tercihleri',
      paragraphs: [
        'Gezgah kullanıcıya rezervasyon durumu, güvenlik bildirimi, sistem '
            'duyurusu, favori/etkinlik hatırlatması, kampanya, sponsorlu mekan '
            'veya reklam bildirimi gönderebilir. Ticari nitelikli bildirimler '
            'kullanıcının onayına ve tercih ayarlarına tabidir. Kullanıcı '
            'uygulama ayarlarından veya cihaz ayarlarından bildirim izinlerini '
            'değiştirebilir.',
      ],
    ),
    LegalSection(
      heading: '7. Kedy yapay zeka verileri',
      paragraphs: [
        'Kedy\u2019ye yazılan veya söylenen sorgular; mekan önerisi üretmek, '
            'sohbet deneyimini sağlamak, kaliteyi artırmak, güvenlik kontrolleri '
            'yapmak ve ürün geliştirmek amacıyla işlenebilir. Kullanıcı '
            'Kedy\u2019ye özel nitelikli kişisel veri, sağlık verisi, finansal '
            'bilgi, şifre, kimlik görüntüsü, başkasına ait kişisel veri veya '
            'gizli bilgi yazmamalıdır.',
        'Kedy altyapısında üçüncü taraf yapay zeka veya bulut hizmetleri '
            'kullanılabilir. Böyle bir kullanım varsa ilgili sağlayıcılar, veri '
            'aktarım modeli ve yurt dışı aktarım durumu KVKK Aydınlatma '
            'Metni\u2019nde ayrıca belirtilmelidir.',
      ],
    ),
    LegalSection(
      heading: '8. İşletmelerle bilgi paylaşımı',
      paragraphs: [
        'Kullanıcı rezervasyon talebi oluşturduğunda; talebin yürütülmesi için '
            'ad, soyad, telefon, rezervasyon tarihi/saati, kişi sayısı, talep '
            'notu ve rezervasyon durumu gibi bilgiler ilgili işletme sahibine '
            'veya işletmenin yetkili hesabına iletilebilir.',
        'İşletme rezervasyonu teyit etmek, kullanıcıyla iletişime geçmek, '
            'değişiklik bildirmek veya operasyonel hazırlık yapmak için '
            'kullanıcıyla iletişime geçebilir.',
      ],
    ),
    LegalSection(
      heading: '9. Üçüncü taraf hizmet sağlayıcıları',
      paragraphs: [
        'Gezgah; barındırma, sunucu, veri tabanı, e-posta, SMS, push bildirim, '
            'harita, analitik, hata izleme, ödeme kuruluşu, müşteri destek '
            'yazılımı, güvenlik ve yapay zeka altyapısı gibi hizmetler için '
            'üçüncü taraf sağlayıcılarla çalışabilir. Bu sağlayıcılar kişisel '
            'verileri yalnızca Gezgah\u2019ın talimatları, sözleşme hükümleri ve '
            'hukuki gereklilikler çerçevesinde işleyebilir.',
      ],
    ),
    LegalSection(
      heading: '10. Ödeme güvenliği',
      paragraphs: [
        'Depozito veya ön ödeme işlemlerinde kart bilgileri Gezgah\u2019ın '
            'anlaşmalı ödeme kuruluşu tarafından güvenli ödeme altyapısı '
            'üzerinden işlenir. Gezgah kart numarası, CVV veya benzeri hassas '
            'ödeme bilgilerini doğrudan saklamamalıdır. Gezgah ödeme işlem '
            'referansı, tutar, işlem durumu, iade bilgisi ve muhasebe '
            'kayıtlarını saklayabilir.',
      ],
    ),
    LegalSection(
      heading: '11. Güvenlik',
      paragraphs: [
        'Gezgah, kişisel verileri yetkisiz erişim, kayıp, kötüye kullanım, '
            'değiştirme veya ifşaya karşı korumak için makul teknik ve idari '
            'tedbirleri alır. Hiçbir dijital sistem mutlak güvenlik garantisi '
            'veremez; bu nedenle kullanıcıların güçlü şifre kullanması, hesap '
            'bilgilerini paylaşmaması ve şüpheli işlemleri Gezgah\u2019a '
            'bildirmesi önemlidir.',
      ],
    ),
    LegalSection(
      heading: '12. Çocukların gizliliği',
      paragraphs: [
        'Gezgah genel kullanıcı kitlesine yönelik bir keşif platformudur. 18 '
            'yaşından küçük kullanıcıların uygulamayı veli veya yasal temsilci '
            'gözetiminde kullanması gerekir. Gezgah bilerek ve isteyerek '
            'çocuklardan ödeme veya rezervasyon işlemi kabul etmeyi hedeflemez. '
            'Çocuğa ait verinin veli izni olmadan işlendiği düşünülüyorsa Gezgah '
            'ile iletişime geçilebilir.',
      ],
    ),
    LegalSection(
      heading: '13. Politika değişiklikleri',
      paragraphs: [
        'Gezgah, bu Gizlilik Politikası\u2019nı uygulama özellikleri, veri '
            'işleme faaliyetleri, mevzuat veya üçüncü taraf sağlayıcı '
            'değişiklikleri nedeniyle güncelleyebilir. Önemli değişiklikler '
            'uygulama içinden veya uygun iletişim kanallarıyla duyurulur.',
      ],
    ),
  ],
  'Kullanıcı Sözleşmesi': [
    LegalSection(
      heading: '1. Taraflar ve kabul',
      paragraphs: [
        'İşbu Kullanıcı Sözleşmesi (\u201cSözleşme\u201d), [ŞİRKET/ŞAHIS '
            'İŞLETMESİ ÜNVANI] (\u201cGezgah\u201d, \u201cŞirket\u201d, '
            '\u201cbiz\u201d) ile Gezgah mobil uygulamasını, web sitesini ve '
            'bunlara bağlı hizmetleri kullanan gerçek kişiler '
            '(\u201cKullanıcı\u201d, \u201csiz\u201d) arasında düzenlenmiştir. '
            'Kullanıcı; uygulamaya üye olarak, uygulamayı kullanarak, '
            'rezervasyon talebi oluşturarak veya Gezgah hizmetlerinden '
            'yararlanarak bu Sözleşme hükümlerini kabul eder.',
        'Kullanıcı 18 yaşından küçükse uygulamayı veli veya yasal '
            'temsilcisinin gözetimi ve onayıyla kullanmalıdır. Rezervasyon, '
            'depozito, ödeme veya hukuki işlem doğuran işlemler yalnızca fiil '
            'ehliyetine sahip kullanıcılar tarafından yapılmalıdır.',
      ],
    ),
    LegalSection(
      heading: '3. Hizmetin kapsamı',
      paragraphs: [
        'Gezgah; kullanıcıların mekanları keşfetmesini, fotoğraflarını '
            'incelemesini, mekan özelliklerini görmesini, menülere, sosyal '
            'medya adreslerine, telefon numaralarına, çalışma saatlerine, '
            'konum/uzaklık bilgilerine, yol tarifine, etkinlik bilgilerine ve '
            'mekan açıklamalarına ulaşmasını sağlayan dijital bir keşif '
            'platformudur. Kullanıcılar mekanları ve etkinlikleri favorilerine '
            'ekleyebilir, ana ekranda yemek veya mekan araması yapabilir, '
            'Gezgah\u2019ın oluşturduğu kategorilerden işletmelere ulaşabilir '
            've mikrofon özelliğiyle sesli arama yapabilir.',
        'Gezgah ayrıca park, mesire alanı, plaj, koy ve benzeri keşif '
            'noktalarını harita ve liste görünümüyle sunabilir. Bu alanlara '
            'ilişkin özellikler Gezgah ekibinin saha çalışması, manuel '
            'incelemesi, işletme/belediye/kamuya açık kaynak bilgileri veya '
            'mevcut dijital kaynaklar doğrultusunda oluşturulabilir.',
        'Gezgah\u2019ın anlaşmalı işletmeleri bakımından kullanıcı, işletmeye '
            'rezervasyon talebi gönderebilir. Rezervasyon talebinin işletmeye '
            'iletilmesi, rezervasyonun kesinleştiği anlamına gelmez. '
            'Kesinleşme için işletme onayı ve varsa depozito/ön ödeme adımının '
            'tamamlanması gerekir.',
      ],
    ),
    LegalSection(
      heading: '4. Üyelik, hesap güvenliği ve doğruluk yükümlülüğü',
      paragraphs: [
        'Kullanıcı üyelik sırasında doğru, güncel ve kendisine ait bilgileri '
            'vermekle yükümlüdür. Kullanıcı hesabının güvenliğinden ve hesabı '
            'üzerinden yapılan işlemlerden sorumludur. Şüpheli kullanım, sahte '
            'bilgi, yetkisiz erişim, spam, hileli rezervasyon, başkasına ait '
            'verilerin kullanılması veya uygulama güvenliğini tehdit eden '
            'davranışların tespiti halinde Gezgah hesabı geçici olarak askıya '
            'alabilir, doğrulama talep edebilir veya hesabı kapatabilir.',
        'Gezgah; güvenlik, dolandırıcılık önleme, sistem bütünlüğü, hukuki '
            'yükümlülükler ve kullanıcı deneyimini koruma amacıyla hesap '
            'doğrulaması, telefon/e-posta teyidi veya ek bilgi talep edebilir.',
      ],
    ),
    LegalSection(
      heading: '5. Mekan bilgileri, menüler ve çalışma saatleri',
      paragraphs: [
        'Uygulamada yer alan mekan özellikleri, menüler, fiyatlar, sosyal '
            'medya adresleri, telefon numaraları, çalışma saatleri, '
            'fotoğraflar, etkinlik bilgileri ve açıklamalar; işletme '
            'tarafından, işletmenin Gezgah ekibine ilettiği bilgiler '
            'doğrultusunda veya Gezgah ekibinin saha ve içerik çalışmalarıyla '
            'girilebilir. İşletme sahibi bu bilgilerin değiştirilmesini Gezgah '
            'ekibinden talep edebilir.',
        'Menü fiyatları, çalışma saatleri, kampanyalar, doluluk durumu, ürün '
            'bulunabilirliği, etkinlik içerikleri, alkol/alkolsüz seçenekler, '
            'vale/otopark durumu ve benzeri bilgiler anlık olarak değişebilir. '
            'Gezgah bilgilerin güncel ve doğru kalması için makul özeni '
            'gösterir; ancak işletmenin son dakika değişikliklerinden, hatalı '
            'bildirimlerinden, üçüncü taraf sistemlerden veya kamuya açık '
            'kaynaklardaki hatalardan sorumlu tutulamaz.',
        'Gezgah\u2019ın kendi QR menü sistemi üzerinden yayınlanan menülerde '
            'Gezgah, kendisine iletilen veya ekibi tarafından sisteme girilen '
            'bilgilerin uygulamada teknik olarak doğru gösterilmesi için makul '
            'özen gösterir. Bununla birlikte menü içeriği, fiyat, ürün '
            'açıklaması, alerjen bilgisi, stok bilgisi, porsiyon ve kampanya '
            'koşulları bakımından nihai sorumluluk ilgili işletmeye aittir. '
            'İşletmenin kendi sistemi, üçüncü taraf QR menüsü veya harici web '
            'bağlantısı üzerinden sunduğu bilgiler için Gezgah doğruluk '
            'garantisi vermez.',
      ],
    ),
    LegalSection(
      heading: '6. Mekan özellikleri ve filtreler',
      paragraphs: [
        'Gezgah\u2019ta otopark, dijital menü, Wi-Fi, çalışma alanı, çocuk '
            'alanı, alkol, alkolsüz seçenek, vale, çevre otoparkı, mescit, '
            'engelsiz erişim, nargile, evcil hayvan uygunluğu, ısıtıcı, '
            'soğutucu, toplu etkinlik, rezervasyon, yabancı dil ve benzeri '
            'filtreler bulunabilir. Bu özellikler işletme tarafından '
            '\u201cvar\u201d, \u201cyok\u201d, \u201cuygundur\u201d veya '
            'benzeri seçeneklerle bildirilmiş; ya da Gezgah ekibi tarafından '
            'gözlem/inceleme yoluyla eklenmiş olabilir.',
        'Filtreler kullanıcıya keşif kolaylığı sağlamak içindir. Özelliklerin '
            'fiili durumu işletme uygulamalarına, sezon şartlarına, tadilata, '
            'kapasiteye, mevzuata veya işletme kararlarına göre değişebilir. '
            'Kullanıcı, kendisi için kritik olan özellikleri işletmeyle '
            'doğrudan teyit etmelidir.',
      ],
    ),
    LegalSection(
      heading: '7. Fotoğraf, video ve görsel içerikler',
      paragraphs: [
        'Mekan fotoğrafları veya videoları Gezgah ekibi tarafından çekilebilir, '
            'işletme sahibi tarafından iletilebilir veya işletmenin izniyle '
            'yayınlanabilir. Gezgah; uygulama deneyimini, kalite standardını, '
            'marka bütünlüğünü, hukuki uygunluğu ve kullanıcı güvenliğini '
            'korumak amacıyla görselleri yayına alıp almama, düzenleme, kırpma, '
            'kaldırma, güncelleme veya yeniden sıralama hakkına sahiptir.',
        'Gezgah\u2019ta yayınlanan fotoğraf, logo, video, metin, tasarım, '
            'ikon, kategori kurgusu ve benzeri içerikler Gezgah\u2019a veya '
            'ilgili hak sahiplerine aittir. Kullanıcı bu içerikleri '
            'Gezgah\u2019ın yazılı izni olmadan kopyalayamaz, ticari amaçla '
            'kullanamaz, çoğaltamaz, yeniden yayınlayamaz veya başka '
            'platformlara aktaramaz.',
      ],
    ),
    LegalSection(
      heading: '8. Doğrulanmış ve manuel eklenen mekanlar',
      paragraphs: [
        'Doğrulanmış mekanlar, Gezgah ekibi tarafından eklenen, incelenen veya '
            'işletme ile temas kurularak doğrulanan mekanları ifade eder. '
            'Manuel eklenen mekanlar ise kullanıcılara keşif önerisi sunmak '
            'amacıyla sisteme eklenmiş olabilir ve tüm bilgileri işletme '
            'tarafından doğrulanmamış olabilir.',
        'Gezgah; herhangi bir işletmeyi yayına alma, yayından kaldırma, geçici '
            'olarak gizleme, kategori değiştirme, sponsorlu gösterimden çıkarma '
            'veya kullanıcıya göstermeme hakkını saklı tutar. Bu hak kalite, '
            'güvenlik, hukuki uygunluk, kullanıcı deneyimi, işletme talebi, '
            'marka politikası, teknik gereklilik veya ticari karar nedeniyle '
            'kullanılabilir.',
      ],
    ),
    LegalSection(
      heading: '9. Harita, konum ve yol tarifi',
      paragraphs: [
        'Gezgah, kullanıcıların harita üzerinden mekan, park, mesire alanı, '
            'plaj ve etkinlik bulmasını sağlayabilir. Uzaklık, rota, yol tarifi '
            've konum bilgileri cihaz konumu, harita sağlayıcısı, GPS '
            'doğruluğu, internet bağlantısı, işletme adres bilgisi ve teknik '
            'koşullara göre değişebilir.',
        'Gezgah harita üzerindeki konumların, kullanıcıya olan uzaklıkların, '
            'yol tariflerinin veya ulaşım sürelerinin mutlak doğruluğunu '
            'garanti etmez. Kullanıcı, özellikle rezervasyon, etkinlik, mesafe '
            'veya zaman hassasiyeti olan durumlarda konumu işletme, resmi kurum '
            'veya ilgili harita sağlayıcısı üzerinden teyit etmelidir.',
      ],
    ),
    LegalSection(
      heading: '10. Park, mesire alanı ve plaj bilgileri',
      paragraphs: [
        'Gezgah kullanıcıların uygulama üzerinden mesire alanları, parklar, '
            'plajlar, beach club alanları ve koylara ulaşmasını sağlayabilir. '
            'Mesire/park özellikleri tenis kortu, WC, mescit, otopark, kamp, '
            'tesis, plaj, göl kenarı, oyun parkı, futbol/basketbol sahası, '
            'oturma alanı, seyir terası, piknik, yürüyüş parkuru ve ateş '
            'yakabilme gibi başlıklardan oluşabilir. Plaj özellikleri halk '
            'plajı, beach club, koy, dalgakıran, cankurtaran, şezlong, '
            'yeme-içme, otopark, kayalık, çakıl, kum, ücretsiz ve ücretli gibi '
            'başlıklardan oluşabilir.',
        'Bu bilgiler Gezgah ekibinin incelemesi veya mevcut kaynaklar '
            'doğrultusunda eklenir. Mevsimsel koşullar, belediye/işletme '
            'kararları, hava durumu, tadilat, güvenlik, kapasite, '
            'ücretlendirme ve mevzuat değişiklikleri nedeniyle bilgiler '
            'değişebilir. Gezgah bu alanların açık/kapalı olma durumunu, '
            'kullanım güvenliğini, ücret bilgisini veya hizmetlerin kesintisiz '
            'sunulacağını garanti etmez.',
      ],
    ),
    LegalSection(
      heading: '11. Sponsorlu içerikler ve reklamlar',
      paragraphs: [
        'Gezgah uygulama içinde ana sayfa listelemelerinde, arama '
            'sonuçlarında, kategori sayfalarında, mekan detaylarında, '
            'sponsorlu listelemelerde, video alanlarında ve bildirimlerde '
            'reklam veya sponsorlu içerik gösterebilir. Sponsorlu içerikler '
            'uygun alanlarda \u201csponsorlu\u201d, \u201creklam\u201d, '
            '\u201cöne çıkan\u201d veya benzeri ibarelerle ayrıştırılabilir.',
        'Sponsorlu gösterim, Gezgah\u2019ın ilgili işletmeyi diğer '
            'işletmelerden üstün gördüğü, hizmet kalitesini garanti ettiği veya '
            'işletme adına taahhütte bulunduğu anlamına gelmez. Reklam veren '
            'işletmelerin sunduğu hizmet, fiyat, kampanya, stok, etkinlik ve '
            'taahhütlerden ilgili işletme sorumludur.',
      ],
    ),
    LegalSection(
      heading: '12. Rezervasyon sistemi',
      paragraphs: [
        'Kullanıcı, Gezgah\u2019ın anlaşmalı işletmeleri için rezervasyon '
            'talebi oluşturabilir. Talep; işletme sahibine, işletmenin yetkili '
            'hesabına veya Gezgah tarafından belirlenen operasyon kanalına '
            'iletilir. İşletme uygunluk görürse rezervasyonu onaylayabilir, '
            'reddedebilir, farklı saat önerebilir veya depozito/ön ödeme talep '
            'edebilir.',
        'İşletme kapasitesi, özel günler, etkinlikler, hava koşulları, teknik '
            'arızalar, masa düzeni, kullanıcı kişi sayısı veya operasyonel '
            'nedenlerle rezervasyon iptal edilebilir veya değiştirilebilir. '
            'Böyle bir durumda kullanıcıya uygulama bildirimi, SMS, e-posta, '
            'telefon veya uygun başka bir kanalla bilgi verilebilir.',
      ],
    ),
    LegalSection(
      heading: '13. Depozito, işlem ücreti ve ödeme',
      paragraphs: [
        'İşletmenin talep etmesi halinde kullanıcıdan rezervasyonu güvence '
            'altına almak için depozito veya ön ödeme alınabilir. Ödeme '
            'işlemleri Gezgah\u2019ın anlaşmalı ödeme kuruluşu veya üçüncü '
            'taraf ödeme altyapısı üzerinden yürütülür. Kart numarası, CVV ve '
            'benzeri hassas kart verileri Gezgah tarafından doğrudan '
            'saklanmamalıdır; bu veriler ödeme kuruluşunun güvenli '
            'altyapısında işlenir.',
        'Gezgah, rezervasyon ve ödeme altyapısının kullanımı karşılığında '
            'işlem ücreti tahsil edebilir. Depozito, işlem ücreti, iade '
            'koşulları, iptal süresi, kesinti oranı ve varsa hizmet bedeli '
            'ödeme öncesinde kullanıcıya açık şekilde gösterilmelidir. Kanundan '
            'doğan tüketici hakları saklıdır.',
      ],
    ),
    LegalSection(
      heading: '14. Kedy yapay zeka kullanımı',
      paragraphs: [
        'Kedy; mekan arama, filtreleme, öneri ve sohbet deneyimi sunan yapay '
            'zeka destekli asistandır. Kedy tarafından verilen cevaplar '
            'uygulamadaki bilgiler, kullanıcının sorgusu, mekan verileri ve '
            'yapay zeka modelinin çıktıları doğrultusunda oluşturulur. Yapay '
            'zeka cevapları her zaman doğru, güncel, eksiksiz veya kullanıcı '
            'beklentisine uygun olmayabilir.',
        'Kedy\u2019nin önerileri profesyonel tavsiye, kesin yönlendirme, '
            'sağlık/gıda güvenliği tavsiyesi, hukuki görüş veya finansal '
            'tavsiye niteliği taşımaz. Kullanıcı kritik bilgileri ilgili '
            'işletme, resmi kurum veya güvenilir kaynaklardan teyit etmelidir.',
      ],
    ),
    LegalSection(
      heading: '15. Favoriler, değerlendirme ve puanlama',
      paragraphs: [
        'Kullanıcı dilediği mekan veya etkinliği favorilerine ekleyebilir. '
            'Favoriler kullanıcının hesabında saklanır ve kişiselleştirilmiş '
            'keşif deneyimi sunmak için kullanılabilir.',
        'Kullanıcı uygulama üzerinden işletmelere değerlendirme ve puan '
            'verebilir. Bu değerlendirme ve puanlar ilk aşamada kullanıcı '
            'uygulamasında yayınlanmayabilir; Gezgah Pro üzerinden ilgili '
            'işletmeyi yöneten yetkili hesap tarafından görüntülenebilir. '
            'Gezgah ileride değerlendirme sistemini kamuya açık hale getirmek '
            'isterse, kullanıcıya değerlendirme akışında açık bilgilendirme '
            'sunmalı ve değerlendirmeleri anonim, rumuzlu veya kullanıcı '
            'ayarlarına uygun şekilde yayınlamalıdır. Geçmişte yalnızca '
            'işletmeye gösterileceği belirtilerek alınan değerlendirmeler, '
            'kullanıcıya ek bilgilendirme ve uygun haklar sunulmadan kamuya '
            'açık şekilde yayınlanmamalıdır.',
        'Kullanıcı; hakaret, tehdit, küfür, ayrımcılık, yanıltıcı bilgi, '
            'reklam, spam, sahte deneyim, kişisel veri ifşası, başkasına ait '
            'görsel veya telif ihlali içeren değerlendirme paylaşamaz. Gezgah '
            'bu tür içerikleri kaldırabilir veya hesabı sınırlandırabilir.',
      ],
    ),
    LegalSection(
      heading: '16. Kullanıcının yükümlülükleri',
      paragraphs: [
        'Kullanıcı uygulamayı hukuka, dürüstlük kuralına, üçüncü kişilerin '
            'haklarına ve Gezgah politikalarına uygun kullanmakla yükümlüdür. '
            'Kullanıcı; sahte hesap açamaz, başkası adına işlem yapamaz, '
            'işletmeleri yanıltamaz, bot/otomasyon kullanamaz, tersine '
            'mühendislik yapamaz, uygulama verilerini izinsiz kazıyamaz, '
            'sponsorlu alanları manipüle edemez veya yanlış konum/kimlik '
            'bilgisi veremez.',
        'Kullanıcı rezervasyonlarında iyi niyet ve nezaket kurallarına uygun '
            'davranmalı; gelemeyeceği rezervasyonu makul süre içinde iptal '
            'etmeli ve ödeme öncesinde kendisine gösterilen depozito/no-show '
            'koşullarına uygun hareket etmelidir.',
      ],
    ),
    LegalSection(
      heading: '17. Hizmet değişiklikleri ve erişim',
      paragraphs: [
        'Gezgah; uygulamanın kapsamını, özelliklerini, kategori yapısını, '
            'sponsorlu alanlarını, filtrelerini, rezervasyon sistemini, Kedy '
            'yapay zeka özelliklerini, ödeme altyapısını ve diğer hizmet '
            'bileşenlerini güncelleyebilir, geçici olarak durdurabilir veya '
            'kaldırabilir. Bakım, güvenlik, teknik arıza, mevzuata uyum veya '
            'ticari kararlar nedeniyle uygulamaya erişim geçici olarak '
            'kesilebilir.',
      ],
    ),
    LegalSection(
      heading: '18. Sorumluluğun sınırları',
      paragraphs: [
        'Gezgah uygulamayı makul özenle sunar. Bununla birlikte işletmelerin '
            'fiili hizmet kalitesi, fiyatlandırması, ürünleri, menü içeriği, '
            'alerjen bilgisi, çalışma saatleri, rezervasyon kapasitesi, '
            'etkinlik iptalleri, işletme içi hizmet kusurları, üçüncü taraf '
            'harita/ödeme/iletişim altyapıları, internet bağlantısı, cihaz '
            'sorunları ve kullanıcı kaynaklı hatalardan sorumlu değildir.',
        'Hiçbir hüküm Gezgah\u2019ın ağır kusurundan, kasıtlı davranışından '
            'veya emredici mevzuat gereği sınırlandırılamayacak '
            'sorumluluklarından muafiyet anlamına gelmez.',
      ],
    ),
    LegalSection(
      heading: '19. Fikri mülkiyet',
      paragraphs: [
        'Gezgah adı, logosu, tasarımları, yazılımları, veri tabanı yapısı, '
            'kategori ve filtre kurgusu, arayüzleri, metinleri, görsel düzeni, '
            'Kedy markası ve uygulama içi tüm özgün unsurlar Gezgah\u2019a veya '
            'lisans verenlerine aittir. Kullanıcıya yalnızca kişisel, sınırlı, '
            'devredilemez ve münhasır olmayan kullanım hakkı verilir.',
      ],
    ),
    LegalSection(
      heading: '20. Hesap silme ve fesih',
      paragraphs: [
        'Kullanıcı Hesabım ekranından kişisel bilgilerini yönetebilir, '
            'izinlerini değiştirebilir ve hesabını dilediği zaman silebilir.',
        'Hesap silme talebi sonrası kişisel veriler; hukuki yükümlülükler, '
            'ödeme/rezervasyon uyuşmazlıkları, güvenlik kayıtları ve kanuni '
            'saklama süreleri saklı kalmak üzere silinir, yok edilir veya '
            'anonim hale getirilir.',
        'Gezgah, kullanıcının sözleşmeye aykırı davranması, sahte işlem '
            'yapması, sistem güvenliğini tehdit etmesi, işletmelere veya diğer '
            'kullanıcılara zarar vermesi veya hukuki zorunluluk doğması '
            'halinde hesabı askıya alabilir veya feshedebilir.',
      ],
    ),
    LegalSection(
      heading: '21. Sözleşme değişiklikleri',
      paragraphs: [
        'Gezgah; mevzuat, uygulama özellikleri, ödeme modeli, rezervasyon '
            'sistemi, veri işleme faaliyetleri veya ticari süreçlerdeki '
            'değişiklikler nedeniyle bu Sözleşme\u2019yi güncelleyebilir. '
            'Önemli değişiklikler uygulama içi bildirim, e-posta veya uygun '
            'diğer yollarla duyurulur. Kullanıcı değişiklikleri kabul etmiyorsa '
            'hesabını silebilir ve uygulamayı kullanmayı bırakabilir.',
      ],
    ),
    LegalSection(
      heading: '22. Uygulanacak hukuk ve uyuşmazlık çözümü',
      paragraphs: [
        'Bu Sözleşme Türkiye Cumhuriyeti hukukuna tabidir. Tüketici sıfatıyla '
            'işlem yapan kullanıcıların kanundan doğan tüketici hakları '
            'saklıdır. Uyuşmazlıklarda parasal sınırlar dahilinde tüketici '
            'hakem heyetleri ve yetkili tüketici mahkemeleri; diğer hallerde '
            'yetkili mahkemeler ve icra daireleri görevli olabilir.',
      ],
    ),
  ],
  'KVKK Aydınlatma Metni': [
    LegalSection(
      heading: '1. Veri sorumlusu',
      paragraphs: [
        '6698 sayılı Kişisel Verilerin Korunması Kanunu (\u201cKVKK\u201d) '
            'kapsamında kişisel verileriniz veri sorumlusu sıfatıyla '
            '[ŞİRKET/ŞAHIS İŞLETMESİ ÜNVANI] tarafından işlenmektedir.',
      ],
    ),
    LegalSection(
      heading: '2. İşlenen kişisel veri kategorileri',
      paragraphs: [
        'Gezgah tarafından işlenebilecek kişisel veri kategorileri şunlardır: '
            'kimlik verileri, iletişim verileri, kullanıcı işlem verileri, '
            'konum verileri, cihaz ve işlem güvenliği verileri, rezervasyon '
            'verileri, ödeme/depozito işlem verileri, favori ve tercih '
            'verileri, pazarlama izin verileri, değerlendirme/puanlama '
            'verileri, destek talebi verileri, Kedy yapay zeka etkileşim '
            'verileri ve uygulama içi izin kayıtları.',
      ],
    ),
    LegalSection(
      heading: '3. Kişisel verilerin işlenme amaçları',
      paragraphs: [
        '• Üyelik oluşturma, hesap yönetimi ve kullanıcı kimliğinin '
            'doğrulanması.',
        '• Mekan, menü, etkinlik, park, plaj, mesire alanı ve harita '
            'deneyiminin sağlanması.',
        '• Yakınlık, yol tarifi, konum tabanlı keşif ve arama özelliklerinin '
            'çalıştırılması.',
        '• Mikrofonla sesli arama fonksiyonunun sunulması.',
        '• Kedy yapay zeka asistanı ile mekan önerisi ve sohbet deneyimi '
            'sağlanması.',
        '• Favoriler, kullanıcı tercihleri ve kişiselleştirilmiş keşif '
            'deneyiminin oluşturulması.',
        '• Rezervasyon talebinin alınması, işletmeye iletilmesi, '
            'onay/ret/iptal süreçlerinin yürütülmesi.',
        '• Depozito/ön ödeme, işlem ücreti, ödeme, iade, muhasebe ve finans '
            'kayıtlarının oluşturulması.',
        '• Değerlendirme ve puanların ilgili işletmeye Gezgah Pro üzerinden '
            'gösterilmesi; kalite ölçümü yapılması.',
        '• Kampanya, etkinlik, sponsorlu içerik ve ticari bildirimlerin '
            'kullanıcı tercihleri doğrultusunda gönderilmesi.',
        '• Kullanıcı destek taleplerinin yönetilmesi; güvenlik, dolandırıcılık '
            've kötüye kullanımın önlenmesi.',
        '• Hata kayıtlarının tutulması, ürün geliştirme, analitik, raporlama '
            've anonim istatistik üretimi.',
        '• Yasal yükümlülüklerin yerine getirilmesi, yetkili kurum taleplerinin '
            'karşılanması, uyuşmazlıkların çözülmesi ve hakların korunması.',
      ],
    ),
    LegalSection(
      heading: '4. Kişisel verilerin işlenme hukuki sebepleri',
      paragraphs: [
        'Kişisel verileriniz KVKK m.5 ve ilgili mevzuatta yer alan hukuki '
            'sebeplere dayanılarak işlenir. Başlıca hukuki sebepler şunlardır: '
            'bir sözleşmenin kurulması veya ifası için gerekli olması; veri '
            'sorumlusunun hukuki yükümlülüğünü yerine getirmesi; bir hakkın '
            'tesisi, kullanılması veya korunması için veri işlemenin zorunlu '
            'olması; ilgili kişinin temel hak ve özgürlüklerine zarar vermemek '
            'kaydıyla veri sorumlusunun meşru menfaati; kanunlarda açıkça '
            'öngörülmesi; ilgili kişinin kendisi tarafından alenileştirilmiş '
            'olması ve gerekli hallerde açık rıza.',
      ],
    ),
    LegalSection(
      heading: '5. Kişisel verilerin aktarılması',
      paragraphs: [
        'Kişisel verileriniz; rezervasyon talebinin yürütülmesi için ilgili '
            'işletmeye; ödeme/depozito işlemleri için ödeme kuruluşuna; '
            'bildirim, SMS, e-posta, sunucu, barındırma, veri tabanı, '
            'analitik, hata izleme, güvenlik, harita, müşteri destek ve yapay '
            'zeka altyapısı sağlayıcılarına; mali müşavir, hukuk danışmanı ve '
            'denetçilere; yetkili kamu kurum ve kuruluşlarına; uyuşmazlık '
            'halinde mahkemeler, icra daireleri ve yetkili mercilere '
            'aktarılabilir.',
        'Aktarım yalnızca ilgili amaçla sınırlı, ölçülü ve hukuki dayanağa '
            'uygun şekilde yapılmalıdır. Yurt dışına veri aktarımı söz konusuysa '
            'KVKK m.9 ve ilgili ikincil mevzuatta öngörülen uygun aktarım '
            'mekanizması ayrıca belirlenmeli; gerekiyorsa kullanıcıdan ayrı '
            'açık rıza alınmalıdır.',
      ],
    ),
    LegalSection(
      heading: '6. Kişisel veri toplama yöntemleri',
      paragraphs: [
        'Kişisel verileriniz; mobil uygulama üyelik formu, hesap ekranı, '
            'rezervasyon ekranı, ödeme/depozito ekranı, favori ve değerlendirme '
            'işlemleri, Kedy sohbet ekranı, sesli arama, cihaz izinleri, '
            'çerez/SDK teknolojileri, destek talepleri, bildirim izinleri, '
            'işletme ile yürütülen rezervasyon süreçleri ve sistem kayıtları '
            'aracılığıyla otomatik veya otomatik olmayan yollarla toplanabilir.',
      ],
    ),
    LegalSection(
      heading: '7. Saklama ve imha',
      paragraphs: [
        'Kişisel verileriniz işleme amacının gerektirdiği süre boyunca ve '
            'ilgili mevzuatta öngörülen saklama süreleri kadar saklanır. '
            'İşleme sebebi ortadan kalktığında veriler silinir, yok edilir veya '
            'anonim hale getirilir. Anonim hale getirilen veriler kullanıcıyla '
            'ilişkilendirilemeyecek şekilde istatistik, raporlama ve ürün '
            'geliştirme amacıyla kullanılabilir.',
      ],
    ),
    LegalSection(
      heading: '8. İlgili kişinin hakları',
      paragraphs: [
        'KVKK m.11 kapsamında; kişisel verilerinizin işlenip işlenmediğini '
            'öğrenme, işlenmişse bilgi talep etme, işlenme amacını ve amaca '
            'uygun kullanılıp kullanılmadığını öğrenme, yurt içinde veya yurt '
            'dışında aktarıldığı üçüncü kişileri bilme, eksik veya yanlış '
            'işlenmişse düzeltilmesini isteme, şartları oluşmuşsa silinmesini '
            'veya yok edilmesini isteme, bu işlemlerin aktarıldığı üçüncü '
            'kişilere bildirilmesini isteme, münhasıran otomatik sistemler '
            'yoluyla aleyhinize bir sonucun ortaya çıkmasına itiraz etme ve '
            'kanuna aykırı işleme nedeniyle zarara uğramanız halinde zararın '
            'giderilmesini talep etme haklarına sahipsiniz.',
      ],
    ),
    LegalSection(
      heading: '9. Başvuru yöntemi',
      paragraphs: [
        'KVKK kapsamındaki taleplerinizi [hukuk/kvkk e-posta adresi] adresine '
            'veya [ticari adres] adresine yazılı olarak iletebilirsiniz. '
            'Başvuruda ad, soyad, iletişim bilgisi, talep konusu ve '
            'kimliğinizi doğrulamaya yarayacak bilgiler bulunmalıdır. Gezgah '
            'başvuruları mevzuatta öngörülen sürelerde sonuçlandırır. Talep '
            'konusu ayrıca işlem maliyeti gerektiriyorsa mevzuatta belirlenen '
            'ücret talep edilebilir.',
      ],
    ),
    LegalSection(
      heading: '10. Aydınlatma metninin güncellenmesi',
      paragraphs: [
        'Bu Aydınlatma Metni; uygulama özellikleri, veri işleme amaçları, '
            'üçüncü taraf sağlayıcılar, hukuki sebepler veya mevzuat '
            'değişiklikleri nedeniyle güncellenebilir. Önemli değişiklikler '
            'kullanıcıya uygun yöntemlerle duyurulur.',
      ],
    ),
  ],
};
