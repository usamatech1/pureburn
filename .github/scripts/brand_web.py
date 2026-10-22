"""Adds a black PureBurn splash screen to web/index.html. It disappears when Flutter draws its first frame."""
p = "web/index.html"
s = open(p, encoding="utf-8").read()
if "pb-splash" not in s:
    splash = (
        '<style>#pb-splash{position:fixed;inset:0;background:#000;display:flex;flex-direction:column;'
        'align-items:center;justify-content:center;z-index:99999;transition:opacity .4s}'
        '#pb-splash svg{width:84px;height:84px;animation:pbpulse 1.4s ease-in-out infinite}'
        '#pb-splash p{color:#fff;font:300 20px/1 -apple-system,Segoe UI,Roboto,Arial,sans-serif;letter-spacing:6px;margin:20px 0 0}'
        '#pb-splash small{display:block;color:#8d8d8d;font:400 9px/1 -apple-system,Segoe UI,Roboto,Arial,sans-serif;letter-spacing:3px;margin-top:12px}'
        '#pb-splash b{font-weight:800}@keyframes pbpulse{50%{transform:scale(1.08);opacity:.85}}</style>'
        '<div id="pb-splash"><svg viewBox="0 0 100 100"><path fill="#fff" fill-rule="evenodd" '
        'd="M50 90C25 90 16 68 26 50C30 43 36 40 38 30C40 22 45 14 50 8C58 20 82 38 80 62C78 80 66 90 50 90Z'
        'M50 84C38 84 35 72 42 62C45 58 48 56 50 50C56 58 66 66 64 74C63 80 57 84 50 84Z"/></svg>'
        '<p><b>PURE</b>BURN</p><small>BURN CLEAN. LIVE PURE.</small></div>'
        '<script>(function(){function hide(){var e=document.getElementById("pb-splash");if(!e)return;'
        'e.style.opacity="0";setTimeout(function(){if(e.parentNode)e.parentNode.removeChild(e)},450)}'
        'document.addEventListener("flutter-first-frame",hide);window.addEventListener("flutter-first-frame",hide);'
        'setTimeout(hide,9000)})();</script>'
    )
    s = s.replace("</body>", splash + "</body>", 1)
    open(p, "w", encoding="utf-8").write(s)
    print("splash added")
else:
    print("splash already there")
