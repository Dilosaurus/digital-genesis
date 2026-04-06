"""
Download missing models for the character expansion pipeline.

Usage:
    python download_models.py --all          # Download everything
    python download_models.py --controlnet   # Just ControlNet OpenPose
    python download_models.py --qwen         # Just Qwen Image Edit suite
    python download_models.py --list         # Show what's needed
"""

import argparse
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path


COMFYUI_PATH = Path("E:/ComfyUI")

MODELS = {
    "controlnet_openpose": {
        "url": "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors",
        "dest": COMFYUI_PATH / "models" / "controlnet" / "OpenPoseXL2.safetensors",
        "size_gb": 4.9,
        "group": "controlnet",
        "description": "ControlNet OpenPose SDXL — pose-guided generation",
    },
    "qwen_diffusion": {
        "url": "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors",
        "dest": COMFYUI_PATH / "models" / "diffusion_models" / "qwen_image_edit_2509_fp8_e4m3fn.safetensors",
        "size_gb": 19.03,
        "group": "qwen",
        "description": "Qwen Image Edit 2509 diffusion model (FP8)",
    },
    "qwen_text_encoder": {
        "url": "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
        "dest": COMFYUI_PATH / "models" / "text_encoders" / "qwen_2.5_vl_7b_fp8_scaled.safetensors",
        "size_gb": 8.74,
        "group": "qwen",
        "description": "Qwen 2.5 VL 7B text encoder (FP8)",
    },
    "qwen_lora_angles": {
        "url": "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/loras/Qwen-Edit-2509-Multiple-angles.safetensors",
        "dest": COMFYUI_PATH / "models" / "loras" / "Qwen-Edit-2509-Multiple-angles.safetensors",
        "size_gb": 0.225,
        "group": "qwen",
        "description": "Qwen multi-angle LoRA",
    },
    "qwen_lora_lightning": {
        "url": "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors",
        "dest": COMFYUI_PATH / "models" / "loras" / "Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors",
        "size_gb": 0.81,
        "group": "qwen",
        "description": "Qwen Lightning 4-step acceleration LoRA",
    },
    "qwen_vae": {
        "url": "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors",
        "dest": COMFYUI_PATH / "models" / "vae" / "qwen_image_vae.safetensors",
        "size_gb": 0.242,
        "group": "qwen",
        "description": "Qwen Image VAE",
    },
}


def download_file(url: str, dest: Path, description: str, size_gb: float):
    """Download a file with progress reporting."""
    dest.parent.mkdir(parents=True, exist_ok=True)

    if dest.exists():
        existing_gb = dest.stat().st_size / (1024**3)
        if existing_gb > size_gb * 0.9:  # close enough = already downloaded
            print(f"  SKIP: {dest.name} already exists ({existing_gb:.2f} GB)")
            return True
        else:
            print(f"  WARN: {dest.name} exists but seems incomplete ({existing_gb:.2f}/{size_gb:.2f} GB)")

    print(f"  Downloading: {description}")
    print(f"    URL:  {url}")
    print(f"    Dest: {dest}")
    print(f"    Size: {size_gb:.2f} GB")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ComfyUI-DigitalGenesis/1.0"})
        with urllib.request.urlopen(req) as response:
            total = int(response.headers.get("content-length", 0))
            downloaded = 0
            chunk_size = 8 * 1024 * 1024  # 8MB chunks

            with open(str(dest), "wb") as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total > 0:
                        pct = downloaded / total * 100
                        gb_done = downloaded / (1024**3)
                        print(f"\r    Progress: {gb_done:.2f}/{size_gb:.2f} GB ({pct:.1f}%)", end="", flush=True)

        print(f"\n    Done: {dest.name}")
        return True

    except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
        print(f"\n    ERROR: {e}")
        if dest.exists():
            dest.unlink()
        return False


def list_models(group: str = None):
    """List all models and their status."""
    total_size = 0
    needed_size = 0

    print(f"\n{'='*70}")
    print(f"  Character Expansion Pipeline — Model Status")
    print(f"{'='*70}\n")

    for model_id, info in MODELS.items():
        if group and info["group"] != group:
            continue

        exists = info["dest"].exists()
        status = "INSTALLED" if exists else "MISSING"
        icon = "+" if exists else "-"
        total_size += info["size_gb"]
        if not exists:
            needed_size += info["size_gb"]

        print(f"  [{icon}] {info['description']}")
        print(f"      File: {info['dest'].name}  ({info['size_gb']:.2f} GB)  [{status}]")

    print(f"\n  Total: {total_size:.2f} GB  |  Needed: {needed_size:.2f} GB")
    print(f"{'='*70}\n")


def main():
    parser = argparse.ArgumentParser(description="Download models for character expansion pipeline")
    parser.add_argument("--all", action="store_true", help="Download all missing models")
    parser.add_argument("--controlnet", action="store_true", help="Download ControlNet OpenPose only")
    parser.add_argument("--qwen", action="store_true", help="Download Qwen Image Edit suite only")
    parser.add_argument("--list", action="store_true", help="List model status")
    args = parser.parse_args()

    if args.list or not any([args.all, args.controlnet, args.qwen]):
        list_models()
        if not any([args.all, args.controlnet, args.qwen]):
            print("  Use --all, --controlnet, or --qwen to download.\n")
        return

    # Determine which models to download
    targets = {}
    for model_id, info in MODELS.items():
        if args.all:
            targets[model_id] = info
        elif args.controlnet and info["group"] == "controlnet":
            targets[model_id] = info
        elif args.qwen and info["group"] == "qwen":
            targets[model_id] = info

    total_gb = sum(i["size_gb"] for i in targets.values() if not i["dest"].exists())
    print(f"\n  Downloading {len(targets)} models ({total_gb:.2f} GB total)...\n")

    success = 0
    failed = 0
    for model_id, info in targets.items():
        if download_file(info["url"], info["dest"], info["description"], info["size_gb"]):
            success += 1
        else:
            failed += 1

    print(f"\n  Complete: {success} downloaded, {failed} failed\n")


if __name__ == "__main__":
    main()
