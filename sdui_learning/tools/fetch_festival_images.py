#!/usr/bin/env python3
"""
Fetch authentic high-quality festival product, banner, and animated GIF images from the web.

Supports:
    --festival all
    --festival diwali
    --festival uttarayan
    --festival holi
    --festival navratri

Usage:
    python3 tools/fetch_festival_images.py --festival diwali
    python3 tools/fetch_festival_images.py --festival all --force
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import shutil
import ssl
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from PIL import Image, ImageOps

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)

# Target dimensions for optimal rendering across SDUI screen layouts
TARGET_SIZES = {
    # Banners
    "banners/hero.jpg": (1170, 540),
    "banners/promo_decor.jpg": (600, 600),
    "banners/promo_gifts.jpg": (600, 600),
    "banners/banner_her_garba_look.jpg": (600, 600),
    "banners/banner_his_kediyu_look.jpg": (600, 600),
    "banners/mosaic_colour_up.jpg": (800, 1000),
    "banners/mosaic_herbal_colours.jpg": (800, 480),
    "banners/mosaic_white_tees.jpg": (800, 480),
    # Static topbars
    "topbar.png": (1200, 516),
}

FESTIVAL_VERIFIED_IMAGES = {
    "navratri": {
        "banners/banner_her_garba_look.jpg": [
            "https://hatkebride.com/cdn/shop/files/21_9e717693-02e2-450b-b8ce-7dfbd10a96e8.jpg?v=1723337683",
            "https://i.pinimg.com/736x/ec/d7/40/ecd7406a4b1bb649c0953ba54b1f63ff.jpg",
        ],
        "banners/banner_his_kediyu_look.jpg": [
            "https://i.pinimg.com/736x/8f/c9/2b/8fc92bbdb0ff49c6934c264aa7fdb6d3.jpg",
            "https://medias.utsavfashion.com/media/catalog/product/cache/1/image/1000x/040ec09b1e35df139433887a97daa66f/g/u/gujarati-style-cotton-kediyu-dhoti-set-in-fuchsia-and-black-v1-myg1178.jpg",
        ],
        "categories/choli.jpg": [
            "https://hatkebride.com/cdn/shop/files/14_4111ce39-0d12-4211-9a7f-7127bcfb92d8.jpg?v=1723337683",
        ],
        "categories/kediyu.jpg": [
            "https://medias.utsavfashion.com/media/catalog/product/cache/1/image/1000x/040ec09b1e35df139433887a97daa66f/g/u/gujarati-style-cotton-kediyu-dhoti-set-in-mustard-and-black-v1-myg1179.jpg",
        ],
        "categories/jewellery.jpg": [
            "https://i.pinimg.com/736x/a2/12/32/a21232c91a0c4f808796bc9da20a9686.jpg",
        ],
        "categories/dandiya.jpg": [
            "https://i.etsystatic.com/28160908/r/il/6e39ed/5412579849/il_1080xN.5412579849_c7.jpg",
        ],
        "categories/footwear.jpg": [
            "https://i.etsystatic.com/27474874/r/il/eb246d/7210861596/il_fullxfull.7210861596.jpg",
        ],
        "products/mirror_work_choli.jpg": [
            "https://i.etsystatic.com/66649509/r/il/d92ea7/8693540356/il_794xN.8693540356_exp.jpg",
        ],
        "products/printed_ghagra.jpg": [
            "https://5.imimg.com/data5/SELLER/Default/2025/7/532460685/DK/GR/DR/146664718/photo.jpg",
        ],
        "products/dandiya_sticks.jpg": [
            "https://dmsretail.in/cdn/shop/files/Handmade-Raja-Rani-Couple-Dandiya-Sticks-for-Navratri-Garba-Dance.jpg",
        ],
        "products/kediyu_set.jpg": [
            "https://5.imimg.com/data5/ANDROID/Default/2024/8/446833001/FX/BA/RJ/229369390/product-jpeg.jpg",
        ],
        "products/kolhapuri_sandals.jpg": [
            "https://i.etsystatic.com/27474874/r/il/5a4a9c/7255781041/il_1080xN.7255781041_m3g4.jpg",
        ],
        "products/batwa_bag.jpg": [
            "https://www.fashionbasket.in/wp-content/uploads/2021/11/FB-077.jpg",
        ],
        "products/oxidised_necklace.jpg": [
            "https://m.media-amazon.com/images/I/81bH9-m8UaL._SY695_.jpg",
        ],
    },
    "diwali": {
        "topbar.gif": [
            "https://media.tenor.com/As3eKOE47nQAAAAM/diwali-celebration.gif",
            "https://media.tenor.com/PZcZ8P9eXgEAAAAM/happy-diwali.gif",
        ],
        "banners/hero.jpg": [
            "https://images.unsplash.com/photo-1544717305-2782549b5136?w=1200&q=85",
        ],
        "banners/promo_gifts.jpg": [
            "https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=800&q=85",
        ],
        "banners/promo_decor.jpg": [
            "https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=800&q=85",
        ],
        "categories/diyas.jpg": [
            "https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=600&q=80",
        ],
        "categories/kurtas.jpg": [
            "https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=600&q=80",
        ],
        "categories/sarees.jpg": [
            "https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=600&q=80",
        ],
        "categories/jewellery.jpg": [
            "https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=600&q=80",
        ],
        "categories/lights.jpg": [
            "https://images.unsplash.com/photo-1514517521153-1be72277b32f?w=600&q=80",
        ],
        "categories/gift_sets.jpg": [
            "https://images.unsplash.com/photo-1599785209707-a456fc1337bb?w=600&q=80",
        ],
        "categories/kids.jpg": [
            "https://images.unsplash.com/photo-1622290291468-a28f7a7dc6a8?w=600&q=80",
        ],
        "categories/menswear.jpg": [
            "https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=600&q=80",
        ],
        "products/brass_diya_set.jpg": [
            "https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=800&q=80",
        ],
        "products/silk_festive_kurta.jpg": [
            "https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=800&q=80",
        ],
        "products/gold_tone_watch.jpg": [
            "https://images.unsplash.com/photo-1524805444758-089113d48a6d?w=800&q=80",
        ],
        "products/nehru_jacket.jpg": [
            "https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=800&q=80",
        ],
        "products/embroidered_kurta.jpg": [
            "https://images.unsplash.com/photo-1617137984095-74e4e5e3613f?w=800&q=80",
        ],
        "products/fairy_light_set.jpg": [
            "https://images.unsplash.com/photo-1514517521153-1be72277b32f?w=800&q=80",
        ],
        "products/potli_bag.jpg": [
            "https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800&q=80",
        ],
    },
    "uttarayan": {
        "topbar.gif": [
            "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExcWc1bWp0dWNpdGtxcTVmZTFnbXlmdXRucWdma3A0aW91b2QzaGZveiZlcD12MV9naWZzX3NlYXJjaCZjdD1n/xT0xeJpnrWC4XWblEk/giphy.gif",
        ],
        "categories/kites.jpg": [
            "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&q=80",
        ],
        "categories/manja.jpg": [
            "https://images.unsplash.com/photo-1590736969955-71cc94801759?w=600&q=80",
        ],
        "categories/shades.jpg": [
            "https://images.unsplash.com/photo-1511499767150-a48a237f0083?w=600&q=80",
        ],
        "categories/caps.jpg": [
            "https://images.unsplash.com/photo-1588850561407-ed78c282e89b?w=600&q=80",
        ],
        "categories/jackets.jpg": [
            "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=600&q=80",
        ],
        "categories/snacks.jpg": [
            "https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&q=80",
        ],
        "products/patang_kite_pack.jpg": [
            "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&q=80",
        ],
        "products/cotton_manja_reel.jpg": [
            "https://images.unsplash.com/photo-1590736969955-71cc94801759?w=800&q=80",
        ],
        "products/uv_sunglasses.jpg": [
            "https://images.unsplash.com/photo-1511499767150-a48a237f0083?w=800&q=80",
        ],
        "products/starter_combo.jpg": [
            "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=80",
        ],
        "products/terrace_party_combo.jpg": [
            "https://images.unsplash.com/photo-1528605248644-14dd04022da1?w=800&q=80",
        ],
    },
    "holi": {
        "topbar.gif": [
            "https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExOHIyb2ZtZjFkdnR3dGJtcmZ1dDV6aHlnOHd5eTZodXRtcWRxdWh4NyZlcD12MV9naWZzX3NlYXJjaCZjdD1n/l2Sq5Ij6m33GyZEha/giphy.gif",
            "https://media.giphy.com/media/l2Sq5Ij6m33GyZEha/giphy.gif",
        ],
        "topbar.png": [
            "https://images.unsplash.com/photo-1514565131-fce0801e5785?w=1200&q=85",
        ],
        "banners/mosaic_colour_up.jpg": [
            "https://images.unsplash.com/photo-1576267423445-b2e0074d68a4?w=800&q=85",
        ],
        "banners/mosaic_herbal_colours.jpg": [
            "https://images.unsplash.com/photo-1615873968403-89e068629265?w=800&q=85",
        ],
        "banners/mosaic_white_tees.jpg": [
            "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800&q=85",
        ],
        "categories/safe_play.jpg": [
            "https://images.unsplash.com/photo-1576267423445-b2e0074d68a4?w=600&q=80",
        ],
        "categories/looks.jpg": [
            "https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=600&q=80",
        ],
        "categories/skin_care.jpg": [
            "https://images.unsplash.com/photo-1556228720-195a672e8a03?w=600&q=80",
        ],
        "categories/party.jpg": [
            "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=600&q=80",
        ],
        "categories/kids.jpg": [
            "https://images.unsplash.com/photo-1502086223501-7ea6ecd79368?w=600&q=80",
        ],
        "products/herbal_colour_set.jpg": [
            "https://images.unsplash.com/photo-1615873968403-89e068629265?w=800&q=80",
        ],
        "products/white_cotton_tee.jpg": [
            "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800&q=80",
        ],
        "products/holi_kurta_set.jpg": [
            "https://images.unsplash.com/photo-1617137984095-74e4e5e3613f?w=800&q=80",
        ],
        "products/sunscreen_kit.jpg": [
            "https://images.unsplash.com/photo-1556228720-195a672e8a03?w=800&q=80",
        ],
        "products/water_pichkari.jpg": [
            "https://images.unsplash.com/photo-1513151233558-d860c5398176?w=800&q=80",
        ],
        "products/bucket_cap.jpg": [
            "https://images.unsplash.com/photo-1588850561407-ed78c282e89b?w=800&q=80",
        ],
    },
}


def download_and_validate(url: str, is_gif: bool = False, min_bytes: int = 5000) -> bytes | None:
    """Download image data and validate magic bytes and minimum size."""
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "image/webp,image/apng,image/*,*/*;q=0.8",
            "Referer": "https://www.google.com/",
        },
    )
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        with urllib.request.urlopen(req, timeout=12, context=ctx) as resp:
            data = resp.read()
            if len(data) < min_bytes:
                return None
            if is_gif:
                if data[:4] != b"GIF8":
                    return None
            else:
                is_jpeg = data[:2] == b"\xff\xd8"
                is_png = data[:4] == b"\x89PNG"
                is_webp = data[:4] == b"RIFF" and len(data) > 12 and data[8:12] == b"WEBP"
                if not (is_jpeg or is_png or is_webp):
                    return None
            return data
    except Exception as e:
        return None


def process_image(data: bytes, rel_path: str, is_gif: bool) -> bytes:
    """Resize and optimize image data based on placement role."""
    if is_gif:
        return data

    try:
        # Determine target size
        if rel_path in TARGET_SIZES:
            target_size = TARGET_SIZES[rel_path]
        elif rel_path.startswith("products/"):
            target_size = (720, 720)
        elif rel_path.startswith("categories/"):
            target_size = (480, 480)
        else:
            target_size = (800, 800)

        img = Image.open(io.BytesIO(data))
        if rel_path.endswith(".png"):
            img = img.convert("RGBA")
            fitted = ImageOps.fit(img, target_size, method=Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            fitted.save(buf, format="PNG", optimize=True)
            return buf.getvalue()
        else:
            img = img.convert("RGB")
            fitted = ImageOps.fit(img, target_size, method=Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            fitted.save(buf, format="JPEG", quality=85, optimize=True)
            return buf.getvalue()
    except Exception as e:
        print(f"    [Optimization Warning] {rel_path}: {e}, keeping original")
        return data


def generate_manifest(festival_dir: Path) -> dict:
    """Generate manifest.json summarizing all categories, products, banners, and topbar."""
    manifest = {
        "products": [],
        "categories": [],
        "banners": [],
        "topbar": None,
    }

    for p in (festival_dir / "products").glob("*.*"):
        if p.name != ".DS_Store":
            manifest["products"].append(p.name)
    manifest["products"].sort()

    for p in (festival_dir / "categories").glob("*.*"):
        if p.name != ".DS_Store":
            manifest["categories"].append(p.name)
    manifest["categories"].sort()

    banners_dir = festival_dir / "banners"
    if banners_dir.exists():
        for p in banners_dir.glob("*.*"):
            if p.name != ".DS_Store":
                manifest["banners"].append(p.name)
        manifest["banners"].sort()

    topbar_gif = festival_dir / "topbar.gif"
    if topbar_gif.exists():
        manifest["topbar"] = "topbar.gif"
    elif (festival_dir / "topbar.png").exists():
        manifest["topbar"] = "topbar.png"

    manifest_path = festival_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2))
    return manifest


def fetch_festival(festival: str, repo_root: Path, force: bool = False, dry_run: bool = False) -> bool:
    """Fetch, optimize, and mirror images for a single festival."""
    print(f"\n=======================================================")
    print(f" Fetching authentic images for festival: {festival.upper()}")
    print(f"=======================================================\n")

    verified_dict = FESTIVAL_VERIFIED_IMAGES.get(festival, {})
    if not verified_dict:
        print(f"Error: Unknown festival '{festival}'")
        return False

    assets_dir = repo_root / "assets" / "festival_images" / festival
    public_dir = repo_root / "public" / "festival_images" / festival

    assets_dir.mkdir(parents=True, exist_ok=True)
    public_dir.mkdir(parents=True, exist_ok=True)

    success_count = 0
    total_count = len(verified_dict)

    for rel_path, candidate_urls in verified_dict.items():
        dest = assets_dir / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        pub_dest = public_dir / rel_path
        pub_dest.parent.mkdir(parents=True, exist_ok=True)

        is_gif = rel_path.endswith(".gif")

        # Skip existing if not forced
        if dest.exists() and not force:
            print(f"  [EXISTS] {rel_path} ({dest.stat().st_size // 1024} KB)")
            # Ensure it is mirrored to public
            if not pub_dest.exists() or pub_dest.stat().st_size != dest.stat().st_size:
                shutil.copy2(dest, pub_dest)
            success_count += 1
            continue

        if dry_run:
            print(f"  [DRY-RUN] Would fetch {rel_path} from {candidate_urls[0][:60]}...")
            success_count += 1
            continue

        print(f"→ Processing: {rel_path}")
        downloaded = None
        source_used = None

        for url in candidate_urls:
            data = download_and_validate(url, is_gif=is_gif)
            if data:
                downloaded = data
                source_used = url
                break
            time.sleep(0.2)

        if downloaded:
            processed = process_image(downloaded, rel_path, is_gif=is_gif)
            dest.write_bytes(processed)
            pub_dest.write_bytes(processed)
            size_kb = len(processed) / 1024.0
            print(f"  ✓ SAVED & MIRRORED {rel_path} ({size_kb:.1f} KB)")
            print(f"    Source: {source_used[:80]}")
            success_count += 1
        else:
            print(f"  ✗ FAILED to fetch valid data for {rel_path}", file=sys.stderr)

    # Generate manifest in both assets and public
    generate_manifest(assets_dir)
    generate_manifest(public_dir)

    print(f"\nCompleted {festival.upper()}: {success_count}/{total_count} files ready.")
    return success_count == total_count


def main():
    parser = argparse.ArgumentParser(
        description="Fetch authentic product, banner, and animated GIF images for SDUI festivals."
    )
    parser.add_argument(
        "--festival",
        type=str,
        default="all",
        choices=["all", "navratri", "diwali", "uttarayan", "holi"],
        help="Target festival (default: all)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force re-download and overwrite existing files",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions without downloading",
    )

    args = parser.parse_args()
    repo_root = Path(__file__).resolve().parent.parent

    festivals = ["diwali", "uttarayan", "holi"] if args.festival == "all" else [args.festival]
    
    all_ok = True
    for fest in festivals:
        ok = fetch_festival(fest, repo_root=repo_root, force=args.force, dry_run=args.dry_run)
        if not ok:
            all_ok = False

    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
