// Hero başlığı daktilo (typewriter) efekti
(function () {
  var el = document.getElementById("typed");
  if (!el) return;

  var phrases = [
    "lezzetlerini keşfet",
    "kafelerini keşfet",
    "mekanlarını keşfet",
    "etkinliklerini keşfet"
  ];

  var typeSpeed = 90;    // harf yazma hızı (ms)
  var eraseSpeed = 45;   // harf silme hızı (ms)
  var holdAfterType = 1400; // yazım bitince bekleme (ms)
  var holdAfterErase = 350; // silme bitince bekleme (ms)

  var pIndex = 0;
  var charIndex = 0;
  var deleting = false;

  function tick() {
    var current = phrases[pIndex];

    if (!deleting) {
      charIndex++;
      el.textContent = current.slice(0, charIndex);
      if (charIndex === current.length) {
        deleting = true;
        return setTimeout(tick, holdAfterType);
      }
      return setTimeout(tick, typeSpeed);
    } else {
      charIndex--;
      el.textContent = current.slice(0, charIndex);
      if (charIndex === 0) {
        deleting = false;
        pIndex = (pIndex + 1) % phrases.length;
        return setTimeout(tick, holdAfterErase);
      }
      return setTimeout(tick, eraseSpeed);
    }
  }

  tick();
})();

// Beğen (kalp) butonlarını aç/kapat
(function () {
  document.addEventListener("click", function (e) {
    var btn = e.target.closest(".like-btn");
    if (!btn) return;
    btn.classList.toggle("is-liked");
  });
})();

// Liste kartına tıklayınca detay sayfasına git (kalp/buton hariç)
(function () {
  document.addEventListener("click", function (e) {
    if (e.target.closest(".like-btn") || e.target.closest("a") || e.target.closest("button")) return;
    var tile = e.target.closest(".list-col .tile");
    if (!tile) return;
    window.location.href = "detail.html";
  });
})();

// Detay sayfası: tabbar başta gizli, scroll olunca görünür, en başa dönünce gizlenir
(function () {
  var bar = document.getElementById("detailTabbar");
  if (!bar) return;

  // başta gizle
  bar.classList.add("is-hidden");

  function onScroll() {
    if (window.scrollY > 60) {
      bar.classList.remove("is-hidden");
    } else {
      bar.classList.add("is-hidden");
    }
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
})();

// Kedy chatbot — aç/kapat + basit mesajlaşma
(function () {
  var openBtn = document.getElementById("kedyOpen");
  var chat = document.getElementById("kedyChat");
  var overlay = document.getElementById("kedyOverlay");
  var closeBtn = document.getElementById("kedyClose");
  var tabbar = document.getElementById("mainTabbar");
  if (!openBtn || !chat) return;

  function openChat() {
    // 1) footer menü animasyonlu alta gir + kaybol
    if (tabbar) tabbar.classList.add("is-gone");
    // 2) ~0.5 sn sonra chatbot alttan açılsın
    setTimeout(function () {
      overlay.classList.add("show");
      chat.classList.add("open");
      chat.setAttribute("aria-hidden", "false");
    }, 500);
  }

  function closeChat() {
    overlay.classList.remove("show");
    chat.classList.remove("open");
    chat.setAttribute("aria-hidden", "true");
    // footer menü geri gelsin
    if (tabbar) tabbar.classList.remove("is-gone");
  }

  openBtn.addEventListener("click", openChat);
  closeBtn.addEventListener("click", closeChat);
  overlay.addEventListener("click", closeChat);

  // Mesaj gönderme
  var form = document.getElementById("kedyForm");
  var input = document.getElementById("kedyText");
  var stream = document.getElementById("kedyStream");
  var body = document.getElementById("kedyBody");

  function startChat() {
    chat.classList.add("started");
  }

  function addMessage(text, who) {
    startChat();
    var msg = document.createElement("div");
    msg.className = "chat-msg " + (who === "me" ? "me" : "bot");
    if (who === "me") {
      msg.innerHTML = '<div class="cm-bubble"></div>';
      msg.querySelector(".cm-bubble").textContent = text;
    } else {
      msg.innerHTML = '<span class="cm-av"><svg viewBox="0 0 576 512" fill="currentColor"><path d="M519.9-29.8c4.6-2.7 10.2-3 15.1-.6 5.5 2.7 9.1 8.3 9.1 14.4l0 144c0 47.4-25.7 88.7-64 110.8L480 464c0 26.5-21.5 48-48 48-26.5 0-48-21.5-48-48l0-98.1-77.4 51.7c26 6 45.4 29.3 45.4 57.1 0 20.6-16.7 37.3-37.3 37.3l-170.7 0C99.8 511.9 64 476.1 64 432l0-256c0-26.5-21.5-48-48-48-8.8 0-16-7.2-16-16 0-8.8 7.2-16 16-16 44.2 0 80 35.8 80 80l0 116c39.5-71.1 111.8-121.4 196.5-130.5-2.9-10.7-4.5-21.9-4.5-33.5l0-144c0-6.1 3.5-11.7 9.1-14.4 5.5-2.7 12.1-1.9 16.9 1.9l75.6 60.5 52.8 0 75.6-60.5 1.9-1.3zM305.4 192.5C188.5 200 96 297.2 96 416l0 16c0 26.5 21.5 48 48 48l170.7 0c2.9 0 5.3-2.4 5.3-5.3 0-14.7-11.9-26.6-26.7-26.7L256 448c-8.8 0-16-7.1-16-16l0-40c0-22.1-17.9-40-40-40l-8 0c-8.8 0-16-7.2-16-16 0-8.8 7.2-16 16-16l8 0c39.8 0 72 32.2 72 72l0 10.1 119.1-79.4c4.9-3.3 11.2-3.6 16.4-.8 5.2 2.8 8.4 8.2 8.4 14.1l0 128c0 8.8 7.2 16 16 16 8.8 0 16-7.2 16-16l0-212c-10.2 2.6-21 4-32 4-47.2 0-88.4-25.5-110.6-63.5zM458 60.5c-2.8 2.3-6.4 3.5-10 3.5l-64 0c-3.6 0-7.2-1.2-10-3.5L320 17.3 320 128c0 53 43 96 96 96s96-43 96-96l0-110.7-54 43.2zM376 148a20 20 0 1 1 0-40 20 20 0 1 1 0 40zm80 0a20 20 0 1 1 0-40 20 20 0 1 1 0 40z"/></svg></span><div class="cm-bubble"></div>';
      msg.querySelector(".cm-bubble").textContent = text;
    }
    stream.appendChild(msg);
    body.scrollTop = body.scrollHeight;
  }

  function botReply() {
    setTimeout(function () {
      addMessage("Hemen bakıyorum… Yakınında 3 harika seçenek buldum! İstersen listeyi açayım.", "bot");
    }, 700);
  }

  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var val = input.value.trim();
      if (!val) return;
      addMessage(val, "me");
      input.value = "";
      botReply();
    });
  }

  // öneri çipleri
  document.addEventListener("click", function (e) {
    var chip = e.target.closest(".cs-chip");
    if (!chip) return;
    addMessage(chip.textContent.trim(), "me");
    botReply();
  });
})();

// Hesabım sayfası — ayar toggle anahtarları
(function () {
  document.addEventListener("click", function (e) {
    var sw = e.target.closest(".acc-switch");
    if (!sw) return;
    var on = sw.classList.toggle("on");
    sw.setAttribute("aria-checked", on ? "true" : "false");
  });
})();

// Hesabım sayfası — Uygulama Ayarları paneli aç/kapat
(function () {
  var openBtn = document.getElementById("settingsOpen");
  var panel = document.getElementById("settingsPanel");
  var overlay = document.getElementById("settingsOverlay");
  var closeBtn = document.getElementById("settingsClose");
  if (!openBtn || !panel) return;

  function openPanel() {
    overlay.classList.add("show");
    panel.classList.add("open");
    panel.setAttribute("aria-hidden", "false");
  }
  function closePanel() {
    overlay.classList.remove("show");
    panel.classList.remove("open");
    panel.setAttribute("aria-hidden", "true");
  }

  openBtn.addEventListener("click", openPanel);
  closeBtn.addEventListener("click", closePanel);
  overlay.addEventListener("click", closePanel);
})();

// Hesabım sayfası — Sözleşmeler tıklanınca doküman panelini aç
(function () {
  var card = document.getElementById("agreementsCard");
  var panel = document.getElementById("docPanel");
  var overlay = document.getElementById("docOverlay");
  var backBtn = document.getElementById("docBack");
  var titleEl = document.getElementById("docTitle");
  var contentEl = document.getElementById("docContent");
  if (!card || !panel) return;

  var lorem =
    "<p>Bu metin örnek (placeholder) içeriktir. Gerçek sözleşme metni hukuk ekibi tarafından sağlandığında bu alana yerleştirilecektir.</p>";

  var docs = {
    "Kullanıcı Sözleşmesi": {
      updated: "Son güncelleme: 1 Haziran 2026",
      html:
        "<h3>1. Taraflar ve Konu</h3><p>İşbu Kullanıcı Sözleşmesi, Gezgah uygulamasını kullanan kullanıcı ile Gezgah arasında, hizmetin kullanım koşullarını düzenlemek amacıyla akdedilmiştir.</p>" +
        "<h3>2. Hizmetin Kapsamı</h3><p>Gezgah; yakın çevredeki mekanları, etkinlikleri ve kampanyaları keşfetmenizi sağlayan bir rehber hizmetidir. Mekanlara ilişkin bilgiler bilgilendirme amaçlıdır.</p>" +
        "<h3>3. Kullanıcı Yükümlülükleri</h3><p>Kullanıcı, uygulamayı yürürlükteki mevzuata ve dürüstlük kurallarına uygun şekilde kullanmayı kabul eder.</p>" + lorem
    },
    "Gizlilik Politikası": {
      updated: "Son güncelleme: 1 Haziran 2026",
      html:
        "<h3>1. Toplanan Veriler</h3><p>Konum bilginiz, yalnızca yakınınızdaki mekanları gösterebilmek için ve izniniz dahilinde işlenir.</p>" +
        "<h3>2. Verilerin Kullanımı</h3><p>Toplanan veriler, hizmet kalitesini artırmak ve size uygun öneriler sunmak için kullanılır; üçüncü taraflarla pazarlama amacıyla paylaşılmaz.</p>" +
        "<h3>3. Güvenlik</h3><p>Verileriniz uygun teknik ve idari tedbirlerle korunur.</p>" + lorem
    },
    "KVKK Aydınlatma Metni": {
      updated: "Son güncelleme: 1 Haziran 2026",
      html:
        "<h3>1. Veri Sorumlusu</h3><p>6698 sayılı Kişisel Verilerin Korunması Kanunu uyarınca veri sorumlusu Gezgah'tır.</p>" +
        "<h3>2. İşleme Amaçları</h3><p>Kişisel verileriniz; hizmetin sunulması, hesabınızın yönetilmesi ve yasal yükümlülüklerin yerine getirilmesi amacıyla işlenir.</p>" +
        "<h3>3. Haklarınız</h3><p>KVKK m.11 kapsamında verilerinize erişme, düzeltme ve silinmesini talep etme haklarına sahipsiniz.</p>" + lorem
    },
    "Çerez Politikası": {
      updated: "Son güncelleme: 1 Haziran 2026",
      html:
        "<h3>1. Çerez Nedir?</h3><p>Çerezler, uygulamayı kullanımınız sırasında cihazınıza kaydedilen küçük metin dosyalarıdır.</p>" +
        "<h3>2. Kullanım Amacı</h3><p>Çerezler; tercihlerinizi hatırlamak ve deneyiminizi iyileştirmek için kullanılır.</p>" +
        "<h3>3. Çerez Yönetimi</h3><p>Çerez tercihlerinizi cihaz veya tarayıcı ayarlarınızdan dilediğiniz zaman değiştirebilirsiniz.</p>" + lorem
    }
  };

  function openDoc(name) {
    var doc = docs[name];
    if (!doc) return;
    titleEl.textContent = name;
    contentEl.innerHTML = '<span class="doc-updated">' + doc.updated + "</span>" + doc.html;
    overlay.classList.add("show");
    panel.classList.add("open");
    panel.setAttribute("aria-hidden", "false");
  }
  function closeDoc() {
    overlay.classList.remove("show");
    panel.classList.remove("open");
    panel.setAttribute("aria-hidden", "true");
  }

  card.addEventListener("click", function (e) {
    var row = e.target.closest(".acc-row");
    if (!row) return;
    var nameEl = row.querySelector(".acc-txt b");
    if (nameEl) openDoc(nameEl.textContent.trim());
  });

  backBtn.addEventListener("click", closeDoc);
  overlay.addEventListener("click", closeDoc);
})();

// Hesabım sayfası — Profil Bilgileri panelini aç/kapat + kaydet
(function () {
  var panel = document.getElementById("profilePanel");
  var overlay = document.getElementById("profileOverlay");
  var backBtn = document.getElementById("profileBack");
  var rowBtn = document.getElementById("profileInfoBtn");
  var editBtn = document.getElementById("profileEditBtn");
  var form = document.getElementById("profileForm");
  if (!panel) return;

  function openPanel() {
    overlay.classList.add("show");
    panel.classList.add("open");
    panel.setAttribute("aria-hidden", "false");
  }
  function closePanel() {
    overlay.classList.remove("show");
    panel.classList.remove("open");
    panel.setAttribute("aria-hidden", "true");
  }

  if (rowBtn) rowBtn.addEventListener("click", openPanel);
  if (editBtn) editBtn.addEventListener("click", openPanel);
  backBtn.addEventListener("click", closePanel);
  overlay.addEventListener("click", closePanel);

  if (form) {
    form.addEventListener("submit", function (e) {
      e.preventDefault();
      // Hero'daki ad/e-posta'yı güncelle
      var name = document.getElementById("pfName").value.trim();
      var email = document.getElementById("pfEmail").value.trim();
      var infoName = document.querySelector(".pf-info b");
      var infoMail = document.querySelector(".pf-info small");
      if (infoName && name) infoName.textContent = name;
      if (infoMail && email) infoMail.textContent = email;
      closePanel();
    });
  }
})();

// Custom select bileşeni (profil formu)
(function () {
  document.addEventListener("click", function (e) {
    var btn = e.target.closest(".pf-select-btn");
    var opt = e.target.closest(".pf-select-opt");

    // Seçenek tıklandı
    if (opt) {
      var sel = opt.closest(".pf-select");
      sel.querySelectorAll(".pf-select-opt").forEach(function (o) {
        o.classList.remove("is-sel");
      });
      opt.classList.add("is-sel");
      // seçenek metnini al (check ikonu hariç)
      var label = opt.childNodes[0] ? opt.childNodes[0].textContent.trim() : opt.textContent.trim();
      sel.querySelector(".pf-select-val").textContent = label;
      sel.classList.remove("open");
      return;
    }

    // Buton tıklandı → aç/kapat
    if (btn) {
      var current = btn.closest(".pf-select");
      var willOpen = !current.classList.contains("open");
      document.querySelectorAll(".pf-select.open").forEach(function (s) {
        s.classList.remove("open");
      });
      if (willOpen) current.classList.add("open");
      return;
    }

    // Dışarı tıklandı → hepsini kapat
    document.querySelectorAll(".pf-select.open").forEach(function (s) {
      s.classList.remove("open");
    });
  });
})();

// Gelişmiş arama modalı — alttan üste aç/kapat
(function () {
  var modal = document.getElementById("searchModal");
  if (!modal) return;

  var boxBtn = document.getElementById("homeSearchBox");
  var tabBtn = document.getElementById("searchTabOpen");
  var closeBtn = document.getElementById("searchClose");
  var input = document.getElementById("searchModalInput");
  var clearBtn = document.getElementById("searchClear");

  function openModal() {
    modal.classList.add("open");
    modal.setAttribute("aria-hidden", "false");
    setTimeout(function () { if (input) input.focus(); }, 320);
  }
  function closeModal() {
    modal.classList.remove("open");
    modal.setAttribute("aria-hidden", "true");
    if (input) input.blur();
  }

  if (boxBtn) boxBtn.addEventListener("click", openModal);
  if (tabBtn) tabBtn.addEventListener("click", openModal);
  if (closeBtn) closeBtn.addEventListener("click", closeModal);

  // Temizle butonu görünürlüğü + işlevi
  function syncClear() {
    if (!clearBtn) return;
    clearBtn.hidden = !(input && input.value.trim());
  }
  if (input) input.addEventListener("input", syncClear);
  if (clearBtn) {
    clearBtn.addEventListener("click", function () {
      input.value = "";
      syncClear();
      input.focus();
    });
  }

  // Hazır arama / kategori / marka tıklanınca input'a yaz
  modal.addEventListener("click", function (e) {
    var chip = e.target.closest(".sm-chip");
    var cat = e.target.closest(".sm-cat");
    var kedy = e.target.closest(".sm-kedy-item");
    var src = chip || cat || kedy;
    if (!src || !input) return;
    var label = src.querySelector("small")
      ? src.querySelector("small").textContent.trim()
      : src.textContent.trim();
    input.value = label;
    syncClear();
    input.focus();
  });

  // ESC ile kapat
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && modal.classList.contains("open")) closeModal();
  });
})();

// Bildirimler modalı — aç/kapat + okundu işaretleme
(function () {
  var modal = document.getElementById("notifModal");
  if (!modal) return;

  var openBtn = document.getElementById("notifOpen");
  var closeBtn = document.getElementById("notifClose");
  var readAll = document.getElementById("notifReadAll");
  var bellDot = openBtn ? openBtn.querySelector(".badge-dot") : null;

  function open() {
    modal.classList.add("open");
    modal.setAttribute("aria-hidden", "false");
  }
  function close() {
    modal.classList.remove("open");
    modal.setAttribute("aria-hidden", "true");
  }
  function syncBell() {
    if (bellDot && !modal.querySelector(".notif.unread")) bellDot.style.display = "none";
  }

  if (openBtn) openBtn.addEventListener("click", open);
  if (closeBtn) closeBtn.addEventListener("click", close);

  if (readAll) {
    readAll.addEventListener("click", function () {
      modal.querySelectorAll(".notif.unread").forEach(function (n) {
        n.classList.remove("unread");
      });
      syncBell();
    });
  }

  // Tek bildirime tıklayınca okundu say
  modal.addEventListener("click", function (e) {
    var n = e.target.closest(".notif");
    if (!n) return;
    n.classList.remove("unread");
    syncBell();
  });

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && modal.classList.contains("open")) close();
  });
})();
