# find_all_m3u8_playwright.py
import asyncio
import re
import json
from urllib.parse import urljoin, urlparse
from pathlib import Path
from playwright.async_api import async_playwright

# ====== CONFIG ======
URL = "https://javhd.today/225691/english-sub-sone-385-hikaru-nagi-a-beautiful-k-cup-model-who-was-forced-to-move-on-a-train-and-became-a-prisoner-of-molestation/"
WAIT_MS_AFTER_LOAD = 9000   # time in ms to wait after goto for network activity
MAX_RESPONSE_BODY_CHARS = 200_000  # limit when reading response bodies
OUTPUT_FILE = "found_m3u8s.json"
HEADLESS = True
# ====================

M3U8_RE = re.compile(r'https?://[^\s"\'<>]+\.m3u8[^\s"\'<>]*', re.IGNORECASE)
# a more permissive pattern to capture query params after .m3u8

async def safe_text_from_response(resp):
    """Read response text with a size guard, return empty string on error."""
    try:
        text = await resp.text()
        if len(text) > MAX_RESPONSE_BODY_CHARS:
            return text[:MAX_RESPONSE_BODY_CHARS]
        return text
    except Exception:
        return ""

def normalize_url(candidate, base):
    """Return absolute URL given candidate and base (if candidate is relative)."""
    if not candidate:
        return None
    if candidate.startswith("//"):
        return "https:" + candidate
    if candidate.startswith("http://") or candidate.startswith("https://"):
        return candidate
    try:
        return urljoin(base, candidate)
    except Exception:
        return candidate

async def fetch_and_extract_m3u8_from_api(context, api_url):
    """Probe an API/url using Playwright's context.request to try and extract m3u8s"""
    found = []
    try:
        r = await context.request.get(api_url, timeout=15000)
        if r.ok:
            txt = await r.text()
            for m in M3U8_RE.findall(txt):
                found.append(m)
    except Exception:
        pass
    return found

async def parse_playlist_for_variants(context, playlist_url, base_url):
    """
    Download a playlist and parse for variant m3u8 URLs (EXT-X-STREAM-INF references).
    Also extracts any m3u8 URLs inside the playlist in general.
    """
    found = []
    try:
        r = await context.request.get(playlist_url, timeout=15000)
        if r.ok:
            text = await r.text()
            # find any .m3u8 URLs inside (could be relative)
            for m in M3U8_RE.findall(text):
                found.append(normalize_url(m, playlist_url))
            # heuristics: also look for lines following EXT-X-STREAM-INF
            lines = text.splitlines()
            for i, line in enumerate(lines):
                if line.strip().startswith("#EXT-X-STREAM-INF"):
                    # next non-empty line likely contains m3u8 url
                    j = i + 1
                    while j < len(lines) and not lines[j].strip():
                        j += 1
                    if j < len(lines):
                        candidate = lines[j].strip()
                        if ".m3u8" in candidate or candidate.endswith(".m3u8") or candidate.startswith("/"):
                            found.append(normalize_url(candidate, playlist_url))
    except Exception:
        pass
    # dedupe
    return list(dict.fromkeys([f for f in found if f]))

async def find_all_m3u8(url):
    results = []   # list of dicts: { url, discovered_by, context }
    seen = set()

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=HEADLESS)
        context = await browser.new_context()
        page = await context.new_page()

        # collectors
        request_candidates = []   # tuple (url, resource_type)
        response_candidates = []  # tuple (url, tag/why)

        # --- 1) attach listeners BEFORE navigation ---
        def on_request(req):
            u = req.url
            if ".m3u8" in u.lower():
                request_candidates.append((u, req.resource_type))
        page.on("request", on_request)

        async def on_response(resp):
            try:
                u = resp.url
                ctype = (resp.headers.get("content-type") or "").lower()
                # direct response URL with m3u8
                if ".m3u8" in u.lower():
                    response_candidates.append((u, "response-url", ctype))
                    return
                # limit reading to small/likely text/JSON playlists
                if ("mpegurl" in ctype) or ("text" in ctype) or ("json" in ctype) or ("application" in ctype):
                    text = await safe_text_from_response(resp)
                    if ".m3u8" in text:
                        for m in M3U8_RE.findall(text):
                            response_candidates.append((m, "response-body", ctype))
            except Exception:
                pass
        page.on("response", lambda r: asyncio.create_task(on_response(r)))

        # Attach console listener to capture any console logs that might contain urls
        console_records = []
        page.on("console", lambda msg: console_records.append(msg.text if hasattr(msg, "text") else str(msg)))

        # --- 2) Navigate and wait ---
        print("🔁 Navigating to:", url)
        try:
            await page.goto(url, timeout=60000)
        except Exception as e:
            print("⚠️ goto failed:", e)

        # Give scripts & player time to run
        await page.wait_for_timeout(WAIT_MS_AFTER_LOAD)

        # --- 3) Technique: DOM scanning (main content) ---
        try:
            html = await page.content()
            for m in M3U8_RE.findall(html):
                candidate = normalize_url(m, url)
                if candidate not in seen:
                    results.append({"url": candidate, "discovered_by": "dom-main-html", "context": url})
                    seen.add(candidate)
        except Exception:
            pass

        # --- 4) Technique: scan every frame/iframe content ---
        for frame in page.frames:
            try:
                f_url = frame.url or url
                fhtml = await frame.content()
                for m in M3U8_RE.findall(fhtml):
                    candidate = normalize_url(m, f_url)
                    if candidate not in seen:
                        results.append({"url": candidate, "discovered_by": "dom-frame-html", "context": f_url})
                        seen.add(candidate)
            except Exception:
                pass

        # --- 5) Technique: JS eval of common player globals ---
        player_checks = {
            "jwplayer": "typeof jwplayer !== 'undefined' ? (function(){ try{ let j=jwplayer(); return JSON.stringify(j.getPlaylist ? j.getPlaylist() : j); }catch(e){return null}})() : null",
            "videojs": "typeof videojs !== 'undefined' ? (function(){ try{ let arr=videojs.getAll ? videojs.getAll() : null; return JSON.stringify(arr); }catch(e){return null}})() : null",
            "hlsjs": "typeof Hls !== 'undefined' ? (function(){ try{ return 'Hls_present'; }catch(e){return null}})() : null",
            "window_player": "window.player || window._player || window.playerConfig || window._playerConfig || null"
        }

        for name, js in player_checks.items():
            try:
                raw = await page.evaluate(js)
                if raw:
                    # raw could be a JSON string or object; convert to str and search for m3u8
                    txt = str(raw)
                    for m in M3U8_RE.findall(txt):
                        candidate = normalize_url(m, url)
                        if candidate not in seen:
                            results.append({"url": candidate, "discovered_by": f"js-eval-{name}", "context": url})
                            seen.add(candidate)
            except Exception:
                pass

        # --- 6) Technique: inline <script> scanning for API endpoints, turboviplay patterns, or cdn patterns ---
        try:
            scripts = await page.query_selector_all("script")
            for s in scripts:
                try:
                    txt = (await (await s.get_property("textContent")).json_value()) or ""
                    if not txt:
                        continue
                    # turboviplay / turbosplayer / cdn patterns
                    for m in re.findall(r'https?://cdn[0-9a-z\.-_]*\.(?:turboviplay|turboviplay\.com|turboviplay\.net)[^\s"\']*\.m3u8[^\s"\']*', txt, re.IGNORECASE):
                        candidate = normalize_url(m, url)
                        if candidate not in seen:
                            results.append({"url": candidate, "discovered_by": "script-inline-turboviplay", "context": "inline_script"})
                            seen.add(candidate)
                    # generic m3u8 urls inside scripts
                    for m in M3U8_RE.findall(txt):
                        candidate = normalize_url(m, url)
                        if candidate not in seen:
                            results.append({"url": candidate, "discovered_by": "script-inline-m3u8", "context": "inline_script"})
                            seen.add(candidate)
                    # find /api/ endpoints for probing
                    for api in re.findall(r'https?://[^\s"\']+/api/[^\s"\']+', txt):
                        # probe this api URL
                        try:
                            api_found = await fetch_and_extract_m3u8_from_api(context, api)
                            for af in api_found:
                                candidate = normalize_url(af, api)
                                if candidate not in seen:
                                    results.append({"url": candidate, "discovered_by": "api-probe", "context": api})
                                    seen.add(candidate)
                        except Exception:
                            pass
                except Exception:
                    pass
        except Exception:
            pass

        # --- 7) Network-captured candidates (requests & responses) ---
        # requests captured
        for u, rtype in request_candidates:
            candidate = normalize_url(u, url)
            if candidate not in seen:
                results.append({"url": candidate, "discovered_by": "network-request", "context": rtype})
                seen.add(candidate)

        # response-captured (from bodies or response URLs)
        for u, tag, ctype in response_candidates:
            candidate = normalize_url(u, url)
            if candidate not in seen:
                results.append({"url": candidate, "discovered_by": f"network-response-{tag}", "context": ctype})
                seen.add(candidate)

        # --- 8) Console logs heuristics: sometimes players print playlist URLs to console ---
        for entry in console_records:
            for m in M3U8_RE.findall(str(entry)):
                candidate = normalize_url(m, url)
                if candidate not in seen:
                    results.append({"url": candidate, "discovered_by": "console-log", "context": entry})
                    seen.add(candidate)

        # --- 9) Parse each discovered playlist for nested variants (EXT-X-STREAM-INF) ---
        # We'll fetch each discovered candidate and parse for additional .m3u8
        additional = []
        for item in list(results):
            candidate = item["url"]
            try:
                more = await parse_playlist_for_variants(context, candidate, url)
                for m in more:
                    if m not in seen:
                        additional.append({"url": m, "discovered_by": "playlist-parse", "context": candidate})
                        seen.add(m)
            except Exception:
                pass
        results.extend(additional)

        # Close browser
        await browser.close()

    # Final dedupe ordering preserved; return structured list
    return results

if __name__ == "__main__":
    all_found = asyncio.run(find_all_m3u8(URL))
    if not all_found:
        print("❌ No m3u8 URLs discovered.")
    else:
        print(f"🎉 Discovered {len(all_found)} m3u8 candidate(s). Saving to {OUTPUT_FILE}")
        Path(OUTPUT_FILE).write_text(json.dumps(all_found, indent=2))
        for i, it in enumerate(all_found, 1):
            print(f"{i}. {it['url']}\n   -> discovered_by: {it['discovered_by']}\n   -> context: {it['context']}\n")
