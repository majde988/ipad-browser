#!/usr/bin/env python3
"""
CloudDesk MemGuard v2 — مدير ضغط الذاكرة للحاويات غير المميّزة (بديل وظيفي لـ SWAP)
  • مراقبة cgroup v1/v2 وتطبيق إجراءات تصاعدية عبر Chrome DevTools Protocol
  • نشر الحالة في /run/clouddesk/api/mem.json (تقرؤه لوحة التحكم)
  • تنفيذ أوامر يدوية من /run/clouddesk/cmd/{gc,park,restore}
"""
import os, time, json, subprocess, urllib.request, urllib.parse
import websocket

CDP      = "http://127.0.0.1:9222"
RUN      = "/run/clouddesk"
API      = f"{RUN}/api/mem.json"
CMD_DIR  = f"{RUN}/cmd"
SOFT     = int(os.getenv("MEMGUARD_SOFT", 70))
HARD     = int(os.getenv("MEMGUARD_HARD", 82))
CRIT     = int(os.getenv("MEMGUARD_CRIT", 92))
INTERVAL = float(os.getenv("MEMGUARD_INTERVAL", 3))
COOLDOWN = int(os.getenv("MEMGUARD_COOLDOWN", 20))
LIMIT_MB = int(os.getenv("MEM_LIMIT_MB", 0))
SKIP     = ("data:", "about:", "chrome:", "brave:", "devtools:")

parked = {}          # targetId -> original url
last_event = "—"

def log(*a): print("[memguard]", *a, flush=True)
def _read(p):
    try: return open(p).read().strip()
    except Exception: return None
def _stat(p):
    return dict(l.split() for l in (_read(p) or "").splitlines() if len(l.split()) == 2)

# ── قياس الذاكرة (cgroup v2 ثم v1)، مستثنياً inactive_file كما يفعل docker stats ──
def cgroup_mem():
    cur = _read("/sys/fs/cgroup/memory.current")
    if cur:
        used = int(cur) - int(_stat("/sys/fs/cgroup/memory.stat").get("inactive_file", 0))
        lim  = _read("/sys/fs/cgroup/memory.max"); lim = None if lim in (None, "max") else int(lim)
    else:
        cur = _read("/sys/fs/cgroup/memory/memory.usage_in_bytes")
        if not cur: return None, None
        used = int(cur) - int(_stat("/sys/fs/cgroup/memory/memory.stat").get("total_inactive_file", 0))
        lim  = int(_read("/sys/fs/cgroup/memory/memory.limit_in_bytes") or 0)
        if lim > 1 << 50: lim = None
    if LIMIT_MB: lim = LIMIT_MB << 20
    return used >> 20, (lim >> 20 if lim else None)

# ── CDP ──
def targets():
    with urllib.request.urlopen(CDP + "/json", timeout=3) as r:
        return [t for t in json.load(r) if t.get("type") == "page"]

def cdp(ws_url, method, params=None):
    ws = websocket.create_connection(ws_url, timeout=5, suppress_origin=True)
    try:
        ws.send(json.dumps({"id": 1, "method": method, "params": params or {}}))
        while True:
            m = json.loads(ws.recv())
            if m.get("id") == 1: return m
    finally: ws.close()

def active_title():
    try:
        out = subprocess.check_output(["xdotool", "getactivewindow", "getwindowname"],
                                      timeout=2, stderr=subprocess.DEVNULL).decode()
        return out.replace(" - Brave", "").strip()
    except Exception: return ""

def split_targets():
    ts = targets(); act = active_title()
    fg = next((t for t in ts if act and t.get("title", "").strip() == act), ts[0] if ts else None)
    bg = [t for t in ts if t is not fg and not t["url"].startswith(SKIP)]
    return fg, bg, ts

# ── الإجراءات ──
def relieve(level, ts):
    for t in ts:
        try:
            cdp(t["webSocketDebuggerUrl"], "Memory.simulatePressureNotification", {"level": level})
            if level == "critical":
                cdp(t["webSocketDebuggerUrl"], "Memory.forciblyPurgeJavaScriptMemory")
        except Exception as e: log("relieve:", e)

def freeze(bg):
    for t in bg:
        try: cdp(t["webSocketDebuggerUrl"], "Page.setWebLifecycleState", {"state": "frozen"})
        except Exception as e: log("freeze:", e)

PARK = """<!doctype html><html dir=rtl><head><meta charset=utf-8><title>💤 {t}</title>
<style>body{{background:#111;color:#ddd;font-family:sans-serif;text-align:center;padding-top:20vh}}
a{{color:#5dade2;font-size:18px}}</style>
<script>var u={u};function go(){{location.replace(u)}}
document.addEventListener('visibilitychange',function(){{if(!document.hidden)go()}});
if(!document.hidden)setTimeout(go,300);</script></head>
<body><h2>💤 تم ركن هذا التبويب لتوفير الذاكرة</h2><p>{t}</p>
<p><a href="#" onclick="go();return false">↩ استعادة الآن</a></p></body></html>"""

def park(bg, n):
    for t in bg[:n]:
        html = PARK.format(t=t.get("title", "")[:80].replace("<", "&lt;"), u=json.dumps(t["url"]))
        url = "data:text/html;charset=utf-8," + urllib.parse.quote(html, safe="")
        try:
            cdp(t["webSocketDebuggerUrl"], "Page.navigate", {"url": url})
            parked[t["id"]] = t["url"]; log("parked:", t["url"][:70])
        except Exception as e: log("park:", e)

def restore(ts):
    for t in ts:
        u = parked.pop(t["id"], None)
        if u and t["url"].startswith("data:"):
            try: cdp(t["webSocketDebuggerUrl"], "Page.navigate", {"url": u}); log("restored:", u[:70])
            except Exception as e: log("restore:", e)

# ── النشر والأوامر ──
def publish(used, lim, pct, tier, ts, bg):
    parked_now = sum(1 for t in ts if t["url"].startswith("data:text/html") and t.get("title", "").startswith("💤"))
    d = {"used_mb": used, "limit_mb": lim, "pct": pct, "tier": tier, "tabs": len(ts),
         "bg": len(bg), "parked": parked_now, "last": last_event, "ts": int(time.time())}
    try:
        with open(API + ".tmp", "w") as f: json.dump(d, f)
        os.replace(API + ".tmp", API)          # كتابة ذرّية
    except Exception as e: log("publish:", e)

def handle_commands(fg, bg, ts):
    global last_event
    try: cmds = os.listdir(CMD_DIR)
    except Exception: return
    for c in cmds:
        try: os.remove(os.path.join(CMD_DIR, c))
        except Exception: pass
        log("command:", c)
        if   c == "gc":      relieve("critical", ts)
        elif c == "park":    park(bg[::-1], len(bg))
        elif c == "restore": restore(ts)
        last_event = f"{c} @ {time.strftime('%H:%M:%S')}"

def main():
    global last_event
    os.makedirs(os.path.dirname(API), exist_ok=True); os.makedirs(CMD_DIR, exist_ok=True)
    log(f"started | soft={SOFT}% hard={HARD}% crit={CRIT}% | interval={INTERVAL}s")
    last_action, last_tier = 0.0, 0
    while True:
        time.sleep(INTERVAL)
        used, lim = cgroup_mem()
        if not used or not lim: continue
        pct  = used * 100 // lim
        tier = 3 if pct >= CRIT else 2 if pct >= HARD else 1 if pct >= SOFT else 0
        try: fg, bg, ts = split_targets()
        except Exception:
            publish(used, lim, pct, tier, [], []); continue      # Brave لم يقلع بعد
        handle_commands(fg, bg, ts)
        publish(used, lim, pct, tier, ts, bg)
        if tier == 0:
            if last_tier: log(f"recovered {used}/{lim}MB ({pct}%)"); last_tier = 0
            continue
        if tier <= last_tier and time.time() - last_action < COOLDOWN: continue
        allt = ([fg] if fg else []) + bg
        log(f"tier{tier} {used}/{lim}MB ({pct}%) tabs={len(allt)} bg={len(bg)}")
        if tier == 1:   relieve("moderate", allt)
        elif tier == 2: relieve("critical", allt); freeze(bg)
        else:           park(bg[::-1], max(1, len(bg) // 2)) if bg else relieve("critical", allt)
        last_event = f"tier{tier} @ {time.strftime('%H:%M:%S')}"
        last_action, last_tier = time.time(), tier

if __name__ == "__main__":
    main()
