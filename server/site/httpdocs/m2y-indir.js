// M2YDesk indirme sayfası: seçilen cihazın kartı, tüm cihazlar listesi, KVKK onayı ve indirme sonrası rehber.
(function () {
  'use strict';
  var a = window.M2Y_AYAR, $ = function (i) { return document.getElementById(i); };
  if (!a || !a.dosyalar) {
    $('hata').hidden = false;
    ['indir', 'cihazlar-bolum'].forEach(function (i) { $(i).hidden = true; });
    return;
  }
  var SITE = 'https://desk.mehmetmesut.com';
  // Sınıf dizgileri Stitch tasarımından; m2y-ana.css bu dosya da taranarak derlenir.
  var D_ANA = 'inline-flex items-center justify-center gap-space-xs px-space-xl py-3.5 rounded-xl bg-gradient-to-r from-primary-container to-secondary-container hover:from-primary hover:to-primary-container text-white font-label-lg text-label-lg font-bold shadow-lg shadow-primary-container/30 hover:shadow-primary-container/50 hover:-translate-y-0.5 active:translate-y-0 transition-all';
  var D_IKI = 'inline-flex items-center justify-center gap-space-xs px-space-lg py-3 rounded-xl bg-surface-container hover:bg-surface-container-high text-on-surface font-label-lg text-label-lg font-medium transition-all';
  var D_SATIR_ANA = 'px-space-md py-2 rounded-lg bg-primary-container hover:bg-primary text-on-primary-container font-label-md text-label-md font-semibold transition-colors flex items-center gap-1 shadow-sm';
  var D_SATIR = 'px-space-md py-2 rounded-lg bg-surface-container hover:bg-surface-container-high text-on-surface font-label-md text-label-md font-medium transition-colors flex items-center gap-1';
  var SATIR = 'p-space-md lg:p-space-lg flex flex-col md:flex-row md:items-center justify-between gap-space-md hover:bg-surface-container/60 transition-colors';
  var KUTU_ANA = 'w-12 h-12 rounded-xl bg-primary-container/20 text-primary flex items-center justify-center flex-shrink-0';
  var KUTU = 'w-12 h-12 rounded-xl bg-surface-container-high text-on-surface flex items-center justify-center flex-shrink-0';
  var ROZET = 'px-2 py-0.5 rounded-full bg-primary/20 text-primary font-label-sm text-label-sm font-bold';
  var KOD = 'font-telemetry-data text-telemetry-data text-on-surface break-all';
  var KOPYA = 'px-space-sm py-1 rounded-lg bg-surface-container-high hover:bg-surface-variant text-on-surface font-label-md text-label-md';
  var ACILIR = 'rounded-xl bg-surface-container px-space-md py-space-sm font-body-sm text-body-sm text-on-surface-variant';

  // Seçenek: dosya (ayar.js anahtarı) ya da baglanti (mağaza). Dosyası yayında olmayan seçenek gösterilmez.
  var SISTEMLER = [
    { id: 'win', ad: 'Windows', ikon: 'desktop_windows', ozet: 'Hızlı Destek, kalıcı kurulum, Microsoft Store ve MSI paketi', secenekler: [
        { ad: 'Hızlı Destek', etiket: 'Kurulum gerektirmez', kim: 'Destek alacaklar için. Kurulum gerektirmez; indirip açmanız yeterli.', dosya: 'windows_qs' },
        { ad: 'Kalıcı kurulum', kim: 'Sürekli kullandığınız bilgisayar için. Kurulur ve bilgisayar açıldığında hazır olur.', dosya: 'windows_install' },
        { ad: 'Microsoft Store', kim: 'Hızlı Destek’in mağaza sürümü. Uyarı çıkmadan kurulur.', baglanti: 'https://apps.microsoft.com/detail/9MZ8NFJ4QVM9', ikon: 'storefront' },
        { ad: 'MSI paketi', kim: 'Kurumsal dağıtım için (BT yöneticileri).', dosya: 'windows_msi' }
      ],
      not: 'Windows “PC’nizi korudu” uyarısı verirse: Ek bilgi → Yine de çalıştır. Kalıcı kurulum yönetici onayı ister.',
      komutlar: [
        ['PowerShell ile Hızlı Destek’i aç', "$env:M2Y_HIZLI='1'; irm " + SITE + '/win-kur.ps1 | iex'],
        ['PowerShell ile kalıcı kurulum', 'irm ' + SITE + '/win-kur.ps1 | iex']
      ] },
    { id: 'mac', ad: 'macOS', ikon: 'laptop_mac', ozet: 'Apple Silicon (M1 ve üzeri) Mac’ler için .dmg', secenekler: [
        { ad: 'Apple Silicon (.dmg)', etiket: 'M1 ve üzeri', kim: 'M1 ve üzeri işlemcili Mac’ler için.', dosya: 'macos_apple' },
        { ad: 'Intel (.dmg)', kim: 'Intel işlemcili Mac’ler için.', dosya: 'macos_intel' }
      ],
      not: '.dmg ile kurarsanız ilk açılışta Sistem Ayarları → Gizlilik ve Güvenlik → “Yine de aç” gerekir. Uygulama, Ekran Kaydı ve Erişilebilirlik izinlerini nasıl vereceğinizi adım adım gösterir.',
      komutlar: [['Terminal ile kur (uyarı çıkmaz)', 'curl -fsSL ' + SITE + '/mac-kur.sh | bash']] },
    { id: 'linux', ad: 'Linux', ikon: 'terminal', ozet: 'Debian, Ubuntu, Mint, Pardus için .deb paketi (64 bit)', secenekler: [
        { ad: 'Debian / Ubuntu paketi (.deb)', etiket: '64 bit', kim: 'Debian, Ubuntu, Mint, Pardus ve türevleri; 64 bit (x86_64).', dosya: 'linux_deb' }
      ],
      not: 'Kurmak için dosyayı indirdiğiniz klasörde Terminal açıp aşağıdaki komutu çalıştırın.',
      komutlar: a.dosyalar.linux_deb ? [['Kurulum komutu', 'sudo apt install ./' + a.dosyalar.linux_deb]] : [] },
    { id: 'android', ad: 'Android', ikon: 'smartphone', qr: true, ozet: 'Google Play’deki RustDesk ya da M2YDesk APK', secenekler: [
        { ad: 'Google Play · RustDesk', etiket: 'Resmî uygulama', kim: 'Resmî uygulama. Kurduktan sonra aşağıdaki QR kodu okutun.', baglanti: 'https://play.google.com/store/apps/details?id=com.carriez.flutter_hbb' },
        { ad: 'M2YDesk APK', kim: 'Sunucu ayarı hazır gelir, QR gerekmez. 64 bit (arm64) cihazlar; kurarken “bilinmeyen kaynak” izni istenir.', dosya: 'android' }
      ],
      not: 'Android’de uygulama hem bağlanabilir hem de ekranını paylaşabilir (Paylaş sekmesi → Hizmeti başlat).' },
    { id: 'ios', ad: 'iPhone / iPad', ikon: 'tablet_mac', qr: true, ozet: 'App Store’daki RustDesk uygulaması', secenekler: [
        { ad: 'App Store · RustDesk', etiket: 'Resmî uygulama', kim: 'Resmî uygulama. Kurduktan sonra aşağıdaki QR kodu okutun.', baglanti: 'https://apps.apple.com/app/rustdesk-remote-desktop/id1581225015' }
      ],
      not: 'iPhone ve iPad yalnızca bağlanan (kontrol eden) taraf olarak kullanılır; ekranları paylaşılamaz.' }
  ];
  SISTEMLER.forEach(function (s) {
    s.secenekler = s.secenekler.filter(function (o) { return o.baglanti || a.dosyalar[o.dosya]; });
  });
  var gorunen = SISTEMLER.filter(function (s) { return s.secenekler.length; });

  function h(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function ikon(ad, boyut) {
    var e = h('span', 'material-symbols-outlined ' + boyut, ad);
    e.setAttribute('aria-hidden', 'true');
    return e;
  }

  function algila() {
    var ua = navigator.userAgent, pf = navigator.platform || '';
    if (/Android/i.test(ua)) return 'android';
    if (/iPhone|iPad|iPod/i.test(ua) || (/Mac/i.test(pf) && navigator.maxTouchPoints > 1)) return 'ios';
    if (/Win/i.test(pf) || /Windows/i.test(ua)) return 'win';
    if (/Mac/i.test(pf)) return 'mac';
    if (/Linux|X11/i.test(pf + ua)) return 'linux';
    return 'win';
  }

  function kopyaDugmesi(metin) {
    var kb = h('button', KOPYA, 'Kopyala'); kb.type = 'button';
    kb.addEventListener('click', function () {
      if (!navigator.clipboard) { kb.textContent = 'Kopyalanamadı'; return; }
      navigator.clipboard.writeText(metin).then(function () { kb.textContent = 'Kopyalandı'; }, function () { kb.textContent = 'Kopyalanamadı'; });
    });
    return kb;
  }

  // İndirme ya da mağaza bağlantısı; sinif düğmenin görünümünü belirler.
  function dugme(o, sinif, boyut) {
    var l = h('a', sinif);
    if (o.baglanti) {
      l.href = o.baglanti; l.target = '_blank'; l.rel = 'noopener';
      l.appendChild(ikon(o.ikon || 'open_in_new', boyut));
      l.appendChild(document.createTextNode(o.ad));
    } else {
      l.href = 'indir/' + encodeURIComponent(a.dosyalar[o.dosya]);
      l.setAttribute('download', a.dosyalar[o.dosya]);
      l.setAttribute('data-indir', o.dosya);
      l.setAttribute('data-ad', o.ad);
      l.appendChild(ikon('download', boyut));
      l.appendChild(document.createTextNode('İndir · ' + o.ad));
    }
    return l;
  }

  // Mobil: resmî RustDesk uygulamasına sunucu ayarını QR ile verir.
  function qrBolumu() {
    var kap = h('div', 'rounded-xl bg-surface-container p-space-md flex flex-col sm:flex-row items-start justify-between gap-space-md'), sol = h('div', 'flex flex-col gap-space-sm font-body-sm text-body-sm text-on-surface-variant'), qr = h('div', 'rounded-lg bg-white p-2 flex-shrink-0');
    sol.appendChild(h('p', null, 'RustDesk uygulamasında Ayarlar → ID/Relay Sunucusu → QR tara ile bu kodu okutun.'));
    var rehber = h('a', 'text-primary underline', 'Tüm uygulama ayarları ve önerilen değerler →'); rehber.href = '/ios-ayarlar';
    sol.appendChild(rehber);
    var det = h('details'); det.appendChild(h('summary', 'cursor-pointer', 'QR okutamıyorsanız elle girin'));
    [['ID Sunucusu', a.sunucu], ['Anahtar', a.anahtar]].forEach(function (r, i) {
      var satir = h('div', 'flex flex-wrap items-center gap-space-sm mt-space-sm');
      satir.appendChild(h('span', null, r[0])); satir.appendChild(h('code', KOD, r[1]));
      if (i === 1) satir.appendChild(kopyaDugmesi(a.anahtar));
      det.appendChild(satir);
    });
    det.appendChild(h('p', 'mt-space-sm', 'Relay ve API alanlarını boş bırakın.'));
    sol.appendChild(det);
    qr.id = 'qr'; qr.setAttribute('role', 'img'); qr.setAttribute('aria-label', 'RustDesk sunucu ayarı QR kodu');
    kap.appendChild(sol); kap.appendChild(qr);
    if (window.QRCode) {
      new QRCode(qr, { text: 'config=' + JSON.stringify({ host: a.sunucu, relay: '', api: 'https://' + a.sunucu, key: a.anahtar }), width: 176, height: 176, correctLevel: QRCode.CorrectLevel.M });
    }
    return kap;
  }

  var onerilen = algila(), secili = null;
  var onay = $('onay-kutu'), onayNot = $('onay-not'), onayBolum = $('onay-bolum');

  function sec(s) {
    secili = s;
    var ilk = s.secenekler[0], dugmeler = $('kart-dugmeler'), ek = $('kart-ek');
    $('kart-rozet').textContent = s.id === onerilen ? 'Cihazınız için önerilen' : 'Seçtiğiniz cihaz';
    $('kart-tespit').hidden = s.id !== onerilen;
    $('kart-ikon').textContent = s.ikon;
    $('kart-ad').textContent = s.ad + ' · ' + ilk.ad;
    $('kart-etiket').textContent = ilk.etiket || '';
    $('kart-etiket').hidden = !ilk.etiket;
    $('kart-kim').textContent = ilk.kim;
    $('kart-not').textContent = s.not;
    var dosyali = s.secenekler.some(function (o) { return o.dosya; });
    onayBolum.hidden = !dosyali;             // yalnız dosya indirilen sistemlerde onay gerekir
    $('kart-ozet-dugme').hidden = !dosyali;
    $('kart-ozet').hidden = true;
    dugmeler.textContent = '';
    s.secenekler.forEach(function (o, i) {
      var d = dugme(o, i === 0 ? D_ANA : D_IKI, i === 0 ? 'text-[22px]' : 'text-[20px]');
      if (i > 0) d.title = o.kim;
      dugmeler.appendChild(d);
    });
    ek.textContent = '';
    (s.komutlar || []).forEach(function (k) {
      var det = h('details', ACILIR), kutu = h('div', 'flex flex-wrap items-center gap-space-sm mt-space-sm');
      det.appendChild(h('summary', 'cursor-pointer font-semibold text-on-surface', k[0]));
      kutu.appendChild(h('code', KOD, k[1])); kutu.appendChild(kopyaDugmesi(k[1]));
      det.appendChild(kutu); ek.appendChild(det);
    });
    if (s.qr) ek.appendChild(qrBolumu());
    kilit();
  }

  var liste = $('cihazlar');
  gorunen.forEach(function (s) {
    var satir = h('div', SATIR), sol = h('div', 'flex items-center gap-space-md'), kutu = h('div', s.id === onerilen ? KUTU_ANA : KUTU);
    var yazi = h('div'), baslik = h('div', 'flex items-center gap-space-xs flex-wrap'), sag = h('div', 'flex flex-wrap items-center md:justify-end gap-space-sm flex-shrink-0');
    kutu.appendChild(ikon(s.ikon, 'text-[26px]'));
    baslik.appendChild(h('h3', 'font-headline-sm text-headline-sm font-semibold text-on-surface', s.ad));
    if (s.id === onerilen) baslik.appendChild(h('span', ROZET, 'Cihazınız'));
    yazi.appendChild(baslik);
    yazi.appendChild(h('p', 'font-body-sm text-body-sm text-on-surface-variant mt-0.5', s.ozet));
    sol.appendChild(kutu); sol.appendChild(yazi);
    var tum = h('button', D_SATIR, 'Seçenekler ve kurulum'); tum.type = 'button';
    tum.addEventListener('click', function () { sec(s); $('indir').scrollIntoView(); $('kart-ad').focus({ preventScroll: true }); });
    sag.appendChild(tum);
    var hizli = dugme(s.secenekler[0], D_SATIR_ANA, 'text-[16px]');
    hizli.setAttribute('data-sistem', s.id);
    sag.appendChild(hizli);
    satir.appendChild(sol); satir.appendChild(sag); liste.appendChild(satir);
  });
  $('kart-ad').tabIndex = -1;

  // SHA-256 imzalı surum.json'dan okunur; alınamazsa boş kalır ve satırlar gösterilmez.
  var ozetIstegi = null;
  function ozetAl(anahtar) {
    if (!ozetIstegi) {
      ozetIstegi = fetch('guncelleme/surum.json').then(function (r) { return r.ok ? r.json() : {}; })
        .then(function (j) { return (j && j.dosyalar) || {}; }).catch(function () { return {}; });
    }
    return ozetIstegi.then(function (d) {
      var o = d[anahtar] && d[anahtar].sha256;
      return typeof o === 'string' && /^[0-9a-f]{64}$/.test(o) ? o : null;
    });
  }
  $('kart-ozet-dugme').addEventListener('click', function () {
    var o = secili.secenekler.filter(function (q) { return q.dosya; })[0], kutu = $('kart-ozet');
    if (!o) return;
    kutu.hidden = false; kutu.textContent = 'Okunuyor…';
    ozetAl(o.dosya).then(function (ozet) {
      kutu.textContent = ozet ? a.dosyalar[o.dosya] + ' · SHA-256: ' + ozet : 'Doğrulama değeri şu an okunamadı.';
    });
  });

  // İndirme başlayınca rehber penceresi
  function indirmeSonrasi(el) {
    var pencere = $('sonra'), anahtar = el.getAttribute('data-indir');
    if (!pencere.showModal) return;
    $('sonra-baslik').textContent = 'M2YDesk · ' + el.getAttribute('data-ad');
    $('sonra-dosya').textContent = a.dosyalar[anahtar];
    $('sonra-yeniden').href = el.href;
    $('sonra-yeniden').setAttribute('download', a.dosyalar[anahtar]);
    $('sonra-ozet-satir').hidden = true;
    pencere.showModal();
    ozetAl(anahtar).then(function (ozet) {
      $('sonra-ozet-satir').hidden = !ozet;
      if (ozet) $('sonra-ozet').textContent = ozet;
    });
  }

  // KVKK onayı: onay verilmeden dosya indirilemez
  function kilit() {
    document.querySelectorAll('[data-indir]').forEach(function (el) {
      el.classList.toggle('kilitli', !onay.checked);
      el.setAttribute('aria-disabled', onay.checked ? 'false' : 'true');
    });
    if (onay.checked) onayNot.textContent = '';
  }
  try { onay.checked = localStorage.getItem('m2y-onay') === '1'; } catch (e) { /* depolama yok */ }
  onay.addEventListener('change', function () {
    try { localStorage.setItem('m2y-onay', onay.checked ? '1' : '0'); } catch (e) { /* depolama yok */ }
    kilit();
  });
  document.addEventListener('click', function (ev) {
    var el = ev.target.closest && ev.target.closest('[data-indir]');
    if (!el) return;
    if (onay.checked) { indirmeSonrasi(el); return; }
    ev.preventDefault();
    var sid = el.getAttribute('data-sistem');   // listeden tıklandıysa onay kutusu o sistemin kartında görünsün
    if (sid) sec(gorunen.filter(function (s) { return s.id === sid; })[0]);
    onayNot.textContent = 'İndirmek için önce bu onay kutusunu işaretleyin.';
    onayBolum.scrollIntoView({ block: 'center' });
    onay.focus({ preventScroll: true });
  });

  document.querySelectorAll('[data-surum]').forEach(function (e) { e.textContent = (a.surum || '—').replace(/^v/, ''); });
  document.querySelectorAll('[data-guncelleme]').forEach(function (e) { e.textContent = a.guncelleme || '—'; });
  sec(gorunen.filter(function (s) { return s.id === onerilen; })[0] || gorunen[0]);
})();
