import urllib.request
import json

HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"}

url = "https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=kurti+kurta+women+indian&gsrnamespace=6&prop=imageinfo&iiprop=url&format=json"
req = urllib.request.Request(url, headers=HEADERS)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        pages = data.get('query', {}).get('pages', {})
        for pid, page in pages.items():
            title = page.get('title')
            img_url = page.get('imageinfo', [{}])[0].get('url')
            print(f"{title} -> {img_url}")
except Exception as e:
    print(f"Error: {e}")
