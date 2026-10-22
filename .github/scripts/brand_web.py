"""Adds SEO tags and a branded animated loader (with a skeleton) to web/index.html.
The loader disappears when Flutter draws its first frame."""
p = "web/index.html"
s = open(p, encoding="utf-8").read()

SITE = "https://usamatech1.github.io/pureburn/"
DESC = "PureBurn is a free fitness app: BMI and goals, daily workouts, Pakistani diet plans, calorie and water tracking, sleep, and a friendly AI coach. Works in your phone browser and as an app."

if "pb-seo" not in s:
    seo = (
        '<!-- pb-seo -->'
        '<link rel="preconnect" href="https://www.gstatic.com" crossorigin>'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
        '<link rel="dns-prefetch" href="https://www.gstatic.com">'
        f'<meta name="description" content="{DESC}">'
        '<meta name="keywords" content="fitness app, BMI calculator, Pakistani diet plan, desi diet plan, weight loss, workout planner, calorie tracker, water tracker, Ramadan diet, blood sugar log, blood pressure log">'
        '<meta name="robots" content="index,follow,max-image-preview:large">'
        '<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">'
        '<meta name="theme-color" content="#fff5ec" media="(prefers-color-scheme: light)">'
        '<meta name="color-scheme" content="dark light">'
        f'<link rel="canonical" href="{SITE}">'
        '<meta property="og:type" content="website">'
        '<meta property="og:site_name" content="PureBurn">'
        '<meta property="og:title" content="PureBurn: BMI, workouts and Pakistani diet plans">'
        f'<meta property="og:description" content="{DESC}">'
        f'<meta property="og:url" content="{SITE}">'
        f'<meta property="og:image" content="{SITE}icons/Icon-512.png">'
        '<meta name="twitter:card" content="summary">'
        '<meta name="twitter:title" content="PureBurn: BMI, workouts and Pakistani diet plans">'
        f'<meta name="twitter:description" content="{DESC}">'
        '<script type="application/ld+json">'
        '{"@context":"https://schema.org","@type":"WebApplication","name":"PureBurn",'
        f'"url":"{SITE}","applicationCategory":"HealthApplication","operatingSystem":"Android, iOS, Web",'
        f'"description":"{DESC}","offers":{{"@type":"Offer","price":"0","priceCurrency":"USD"}}}}'
        '</script>'
    )
    s = s.replace("</head>", seo + "</head>", 1)
    s = s.replace("<html>", '<html lang="en">', 1)
    # Readable content for crawlers and for people with scripts blocked.
    nos = (
        '<noscript><main style="font-family:sans-serif;max-width:560px;margin:40px auto;padding:0 20px;line-height:1.5">'
        '<h1>PureBurn</h1><p>Burn clean. Live pure.</p>'
        '<p>PureBurn is a free fitness app with BMI and goal planning, daily workouts, Pakistani diet plans, '
        'calorie, water and sleep tracking, and an AI coach. Turn on JavaScript to use it.</p></main></noscript>'
    )
    s = s.replace("<body>", "<body>" + nos, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("seo added")

if "pb-splash" not in s:
    splash = (
        '<style>'
        '#pb-splash{position:fixed;inset:0;z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:flex-start;'
        'padding:0 20px;box-sizing:border-box;background:radial-gradient(120% 60% at 90% 0%,rgba(242,138,85,.22),transparent 60%),#050505;'
        'color:#fff;transition:opacity .45s ease;font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif}'
        '@media (prefers-color-scheme: light){#pb-splash{background:radial-gradient(120% 60% at 90% 0%,rgba(201,83,31,.20),transparent 60%),#fff5ec;color:#111}'
        '#pb-splash .sk{background:linear-gradient(90deg,#eadfd4 25%,#f6eee6 37%,#eadfd4 63%);background-size:400% 100%}'
        '#pb-splash small,#pb-splash .msg{color:#7a6a5d}#pb-splash .bar{background:#ead9c9}}'
        '#pb-splash .brand{margin-top:16vh;display:flex;flex-direction:column;align-items:center}'
        '#pb-splash svg{width:76px;height:76px;animation:pbpulse 1.6s ease-in-out infinite;filter:drop-shadow(0 0 18px rgba(242,138,85,.45))}'
        '#pb-splash p{font:300 20px/1 -apple-system,Segoe UI,Roboto,Arial,sans-serif;letter-spacing:6px;margin:20px 0 0}'
        '#pb-splash small{display:block;color:#8d8d8d;font:400 9px/1 -apple-system,Segoe UI,Roboto,Arial,sans-serif;letter-spacing:3px;margin-top:12px}'
        '#pb-splash b{font-weight:800}'
        '#pb-splash .bar{position:relative;width:180px;height:3px;border-radius:3px;background:#262626;overflow:hidden;margin-top:26px}'
        '#pb-splash .bar i{position:absolute;inset:0 auto 0 0;width:40%;border-radius:3px;background:#f28a55;animation:pbslide 1.2s ease-in-out infinite}'
        '#pb-splash .msg{margin-top:12px;font-size:12px;color:#8d8d8d;min-height:14px}'
        '#pb-splash .skel{width:100%;max-width:420px;margin-top:34px;display:grid;grid-template-columns:1fr 1fr;gap:12px;opacity:.9}'
        '#pb-splash .sk{border-radius:20px;height:84px;background:linear-gradient(90deg,#161616 25%,#222 37%,#161616 63%);background-size:400% 100%;animation:pbshimmer 1.6s ease infinite}'
        '#pb-splash .sk.w{grid-column:1/3;height:110px}'
        '@keyframes pbpulse{50%{transform:scale(1.08);opacity:.88}}'
        '@keyframes pbslide{0%{left:-40%}100%{left:100%}}'
        '@keyframes pbshimmer{0%{background-position:100% 50%}100%{background-position:0 50%}}'
        '@media (prefers-reduced-motion:reduce){#pb-splash svg,#pb-splash .bar i,#pb-splash .sk{animation:none}}'
        '</style>'
        '<div id="pb-splash" role="status" aria-live="polite"><div class="brand">'
        '<svg viewBox="0 0 100 100" aria-hidden="true"><path fill="#f28a55" fill-rule="evenodd" '
        'd="M50 90C25 90 16 68 26 50C30 43 36 40 38 30C40 22 45 14 50 8C58 20 82 38 80 62C78 80 66 90 50 90Z'
        'M50 84C38 84 35 72 42 62C45 58 48 56 50 50C56 58 66 66 64 74C63 80 57 84 50 84Z"/></svg>'
        '<p><b>PURE</b>BURN</p><small>BURN CLEAN. LIVE PURE.</small>'
        '<div class="bar"><i></i></div><div class="msg" id="pb-msg">Getting your plan ready...</div></div>'
        '<div class="skel" aria-hidden="true"><div class="sk w"></div><div class="sk"></div><div class="sk"></div><div class="sk"></div><div class="sk"></div></div></div>'
        '<script>(function(){function hide(){var e=document.getElementById("pb-splash");if(!e)return;'
        'e.style.opacity="0";setTimeout(function(){if(e.parentNode)e.parentNode.removeChild(e)},480)}'
        'document.addEventListener("flutter-first-frame",hide);window.addEventListener("flutter-first-frame",hide);'
        'setTimeout(function(){var m=document.getElementById("pb-msg");if(m)m.textContent="Still loading, your connection looks slow..."},7000);'
        'setTimeout(hide,25000)})();</script>'
    )
    s = s.replace("</body>", splash + "</body>", 1)
    open(p, "w", encoding="utf-8").write(s)
    print("splash added")
else:
    print("splash already there")
