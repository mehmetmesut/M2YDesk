// M2YDesk indirme sayfası: işletim sistemi sekmeleri ve her sistem için indirme seçenekleri.
(function () {
  'use strict';
  var a = window.M2Y_AYAR, $ = function (i) { return document.getElementById(i); };
  if (!a || !a.dosyalar) {
    $('hata').hidden = false;
    ['onay-bolum', 'indir', 'adimlar'].forEach(function (i) { $(i).hidden = true; });
    return;
  }
  var SITE = 'https://desk.mehmetmesut.com';
  var INDIR_IKON = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3v12m0 0l-4-4m4 4l4-4M5 21h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  var MASA = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="4" width="18" height="12" rx="2" stroke="currentColor" stroke-width="2"/><path d="M8 20h8M12 16v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>';
  var CEP = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="7" y="3" width="10" height="18" rx="2" stroke="currentColor" stroke-width="2"/><path d="M11 18h2" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>';

  // Seçenek: dosya (ayar.js anahtarı) ya da baglanti (mağaza). Dosyası yayında olmayan seçenek gösterilmez.
  var SISTEMLER = [
    { id: 'win', ad: 'Windows', ikon: MASA, secenekler: [
        { ad: 'Hızlı Destek', kim: 'Destek alacaklar için. Kurulum gerektirmez; indirip açmanız yeterli.', dosya: 'windows_qs' },
        { ad: 'Kalıcı kurulum', kim: 'Sürekli kullandığınız bilgisayar için. Kurulur ve bilgisayar açıldığında hazır olur.', dosya: 'windows_install' },
        { ad: 'Microsoft Store', kim: 'Hızlı Destek’in mağaza sürümü. Uyarı çıkmadan kurulur, kendiliğinden güncellenir.', baglanti: 'https://apps.microsoft.com/detail/9MZ8NFJ4QVM9', dugme: 'Store’dan al' },
        { ad: 'MSI paketi', kim: 'Kurumsal dağıtım için (BT yöneticileri).', dosya: 'windows_msi' }
      ],
      not: 'Windows “PC’nizi korudu” uyarısı verirse: Ek bilgi → Yine de çalıştır. Kalıcı kurulum yönetici onayı ister.',
      komutlar: [
        ['PowerShell ile Hızlı Destek’i aç', "$env:M2Y_HIZLI='1'; irm " + SITE + '/win-kur.ps1 | iex'],
        ['PowerShell ile kalıcı kurulum', 'irm ' + SITE + '/win-kur.ps1 | iex']
      ] },
    { id: 'mac', ad: 'macOS', ikon: MASA, secenekler: [
        { ad: 'Apple Silicon (.dmg)', kim: 'M1 ve üzeri işlemcili Mac’ler için.', dosya: 'macos_apple' },
        { ad: 'Intel (.dmg)', kim: 'Intel işlemcili Mac’ler için.', dosya: 'macos_intel' }
      ],
      not: '.dmg ile kurarsanız ilk açılışta Sistem Ayarları → Gizlilik ve Güvenlik → “Yine de aç” gerekir. Uygulama, Ekran Kaydı ve Erişilebilirlik izinlerini nasıl vereceğinizi adım adım gösterir.',
      komutlar: [['Terminal ile kur (uyarı çıkmaz)', 'curl -fsSL ' + SITE + '/mac-kur.sh | bash']] },
    { id: 'linux', ad: 'Linux', ikon: MASA, secenekler: [
        { ad: 'Debian / Ubuntu paketi (.deb)', kim: 'Debian, Ubuntu, Mint, Pardus ve türevleri; 64 bit (x86_64).', dosya: 'linux_deb' }
      ],
      not: 'Kurmak için dosyayı indirdiğiniz klasörde Terminal açıp aşağıdaki komutu çalıştırın.',
      komutlar: a.dosyalar.linux_deb ? [['Kurulum komutu', 'sudo apt install ./' + a.dosyalar.linux_deb]] : [] },
    { id: 'android', ad: 'Android', ikon: CEP, qr: true, secenekler: [
        { ad: 'Google Play · RustDesk', kim: 'Resmî uygulama. Kurduktan sonra aşağıdaki QR kodu okutun.', baglanti: 'https://play.google.com/store/apps/details?id=com.carriez.flutter_hbb', dugme: 'Google Play' },
        { ad: 'M2YDesk APK', kim: 'Sunucu ayarı hazır gelir, QR gerekmez. 64 bit (arm64) cihazlar; kurarken “bilinmeyen kaynak” izni istenir.', dosya: 'android' }
      ],
      not: 'Android’de uygulama hem bağlanabilir hem de ekranını paylaşabilir (Paylaş sekmesi → Hizmeti başlat).' },
    { id: 'ios', ad: 'iPhone / iPad', ikon: CEP, qr: true, secenekler: [
        { ad: 'App Store · RustDesk', kim: 'Resmî uygulama. Kurduktan sonra aşağıdaki QR kodu okutun.', baglanti: 'https://apps.apple.com/app/rustdesk-remote-desktop/id1581225015', dugme: 'App Store' }
      ],
      not: 'iPhone ve iPad yalnızca bağlanan (kontrol eden) taraf olarak kullanılır; ekranları paylaşılamaz.' }
  ];
  SISTEMLER.forEach(function (s) {
    s.secenekler = s.secenekler.filter(function (o) { return o.baglanti || a.dosyalar[o.dosya]; });
  });

  function h(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
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
    var kb = h('button', 'kopyala', 'Kopyala'); kb.type = 'button';
    kb.addEventListener('click', function () {
      if (!navigator.clipboard) { kb.textContent = 'Kopyalanamadı'; return; }
      navigator.clipboard.writeText(metin).then(function () { kb.textContent = 'Kopyalandı'; }, function () { kb.textContent = 'Kopyalanamadı'; });
    });
    return kb;
  }

  function secenekSatiri(o, ilk) {
    var li = h('li', ilk ? 'one' : null), yazi = h('div'), ad = h('b', null, o.ad), l = h('a', 'btn' + (ilk ? ' ana' : ''));
    if (ilk) ad.appendChild(h('span', null, 'ÖNERİLEN'));
    yazi.appendChild(ad); yazi.appendChild(h('p', null, o.kim));
    if (o.baglanti) { l.href = o.baglanti; l.target = '_blank'; l.rel = 'noopener'; l.textContent = o.dugme; }
    else {
      l.href = 'indir/' + encodeURIComponent(a.dosyalar[o.dosya]);
      l.setAttribute('download', a.dosyalar[o.dosya]);
      l.setAttribute('data-indir', o.dosya);
      l.setAttribute('data-ad', o.ad);
      l.insertAdjacentHTML('beforeend', INDIR_IKON);
      l.appendChild(h('span', null, 'İndir'));
    }
    li.appendChild(yazi); li.appendChild(l);
    return li;
  }

  // Mobil: resmî RustDesk uygulamasına sunucu ayarını QR ile verir.
  function qrBolumu() {
    var kap = h('div', 'mobil'), sol = h('div'), qr = h('div');
    sol.appendChild(h('p', null, 'RustDesk uygulamasında Ayarlar → ID/Relay Sunucusu → QR tara ile bu kodu okutun.'));
    var rehber = h('a', null, 'Tüm uygulama ayarları ve önerilen değerler →'); rehber.href = '/ios-ayarlar';
    var rp = h('p'); rp.appendChild(rehber); sol.appendChild(rp);
    var det = h('details'); det.appendChild(h('summary', null, 'QR okutamıyorsanız elle girin'));
    [['ID Sunucusu', a.sunucu], ['Anahtar', a.anahtar]].forEach(function (r, i) {
      var satir = h('div', 'satir');
      satir.appendChild(h('span', null, r[0])); satir.appendChild(h('code', null, r[1]));
      if (i === 1) satir.appendChild(kopyaDugmesi(a.anahtar));
      det.appendChild(satir);
    });
    det.appendChild(h('p', 'kucuk', 'Relay ve API alanlarını boş bırakın.'));
    sol.appendChild(det);
    qr.id = 'qr'; qr.setAttribute('role', 'img'); qr.setAttribute('aria-label', 'RustDesk sunucu ayarı QR kodu');
    kap.appendChild(sol); kap.appendChild(qr);
    if (window.QRCode) {
      new QRCode(qr, { text: 'config=' + JSON.stringify({ host: a.sunucu, relay: '', api: 'https://' + a.sunucu, key: a.anahtar }), width: 176, height: 176, correctLevel: QRCode.CorrectLevel.M });
    }
    return kap;
  }

  var sekmeKutu = $('sekmeler'), panel = $('panel'), sekmeler = {}, onay = $('onay-kutu'), onayNot = $('onay-not'), onayBolum = $('onay-bolum');
  var gorunen = SISTEMLER.filter(function (s) { return s.secenekler.length; });

  function sec(s, odak) {
    gorunen.forEach(function (q) { sekmeler[q.id].setAttribute('aria-selected', q === s ? 'true' : 'false'); sekmeler[q.id].tabIndex = q === s ? 0 : -1; });
    panel.setAttribute('aria-labelledby', 'sekme-' + s.id);
    panel.textContent = '';
    var dosyaVar = s.secenekler.some(function (o) { return o.dosya; });
    onayBolum.hidden = !dosyaVar;           // yalnız dosya indirilen sistemlerde onay gerekir
    panel.appendChild(onayBolum);
    var liste = h('ul', 'secenekler');
    s.secenekler.forEach(function (o, i) { liste.appendChild(secenekSatiri(o, i === 0)); });
    panel.appendChild(liste);
    panel.appendChild(h('p', 'not', s.not));
    (s.komutlar || []).forEach(function (k) {
      var det = h('details'), kutu = h('div', 'komut');
      det.appendChild(h('summary', null, k[0]));
      kutu.appendChild(h('code', null, k[1])); kutu.appendChild(kopyaDugmesi(k[1]));
      det.appendChild(kutu); panel.appendChild(det);
    });
    if (s.qr) panel.appendChild(qrBolumu());
    $('adimlar').hidden = !!s.qr;
    kilit();
    if (odak) sekmeler[s.id].focus();
  }

  var onerilen = algila();
  gorunen.forEach(function (s) {
    var t = h('button', 'sekme'); t.type = 'button'; t.id = 'sekme-' + s.id;
    t.setAttribute('role', 'tab'); t.setAttribute('aria-controls', 'panel');
    t.insertAdjacentHTML('beforeend', s.ikon);
    t.appendChild(h('b', null, s.ad));
    t.appendChild(h('small', null, s.id === onerilen ? 'Cihazınız' : ''));
    t.addEventListener('click', function () { sec(s); });
    sekmeKutu.appendChild(t); sekmeler[s.id] = t;
  });
  sekmeKutu.addEventListener('keydown', function (ev) {
    var yon = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[ev.key], i = -1;
    gorunen.forEach(function (s, n) { if (sekmeler[s.id].tabIndex === 0) i = n; });
    if (!yon || i < 0) return;
    ev.preventDefault();
    sec(gorunen[(i + yon + gorunen.length) % gorunen.length], true);
  });

  // İndirme başlayınca rehber penceresi; SHA-256 imzalı surum.json'dan, alınamazsa satır gizli kalır.
  var ozetler = null;
  function ozetGoster(anahtar) {
    var d = ozetler && ozetler[anahtar], ozet = d && d.sha256;
    var gecerli = typeof ozet === 'string' && /^[0-9a-f]{64}$/.test(ozet);
    $('sonra-ozet-satir').hidden = !gecerli;
    if (gecerli) $('sonra-ozet').textContent = ozet;
  }
  function indirmeSonrasi(el) {
    var pencere = $('sonra'), anahtar = el.getAttribute('data-indir');
    if (!pencere.showModal) return;
    $('sonra-baslik').textContent = 'M2YDesk · ' + el.getAttribute('data-ad');
    $('sonra-dosya').textContent = a.dosyalar[anahtar];
    $('sonra-yeniden').href = el.href;
    $('sonra-yeniden').setAttribute('download', a.dosyalar[anahtar]);
    ozetGoster(anahtar);
    pencere.showModal();
    if (ozetler) return;
    fetch('guncelleme/surum.json').then(function (r) { return r.ok ? r.json() : {}; })
      .then(function (j) { ozetler = (j && j.dosyalar) || {}; ozetGoster(anahtar); })
      .catch(function () { ozetler = {}; });
  }

  // KVKK onayı: onay verilmeden dosya indirilemez
  function kilit() {
    panel.querySelectorAll('[data-indir]').forEach(function (el) {
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
  panel.addEventListener('click', function (ev) {
    var el = ev.target.closest && ev.target.closest('[data-indir]');
    if (!el) return;
    if (onay.checked) { indirmeSonrasi(el); return; }
    ev.preventDefault();
    onayNot.textContent = 'İndirmek için önce bu onay kutusunu işaretleyin.';
    onay.focus();
  });

  $('surum').textContent = (a.surum || '—').replace(/^v/, '');
  $('guncelleme').textContent = a.guncelleme || '—';
  sec(gorunen.filter(function (s) { return s.id === onerilen; })[0] || gorunen[0]);
})();
