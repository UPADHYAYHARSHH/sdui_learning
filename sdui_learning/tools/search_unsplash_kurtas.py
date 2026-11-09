import urllib.request
import json

HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"}

url = "https://unsplash.com/napi/search/photos?query=indian+kurti+women&per_page=20"
req = urllib.request.Request(url, headers=HEADERS)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        results = data.get('results', [])
        print(f"Found {len(results)} results on Unsplash:")
        for r in results:
            photo_id = r.get('id')
            desc = r.get('alt_description') or r.get('description') or ''
            raw_url = r.get('urls', {}).get('regular')
            print(f"{photo_id}: {desc[:40]} -> {raw_url}")
except Exception as e:
    print(f"Error: {e}")
