"""
ComfyUI API Client for Digital Genesis Art Pipeline
Sends workflow prompts to ComfyUI server and retrieves generated images.
"""

import json
import urllib.request
import urllib.error
import time
import os
import uuid
import shutil
from pathlib import Path


class ComfyUIClient:
    def __init__(self, server_url="http://127.0.0.1:8188"):
        self.server_url = server_url
        self.client_id = str(uuid.uuid4())

    def is_running(self):
        try:
            urllib.request.urlopen(f"{self.server_url}/system_stats", timeout=2)
            return True
        except (urllib.error.URLError, ConnectionRefusedError, OSError):
            return False

    def queue_prompt(self, workflow):
        payload = json.dumps({"prompt": workflow, "client_id": self.client_id}).encode("utf-8")
        req = urllib.request.Request(
            f"{self.server_url}/prompt",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        response = urllib.request.urlopen(req)
        return json.loads(response.read())

    def get_history(self, prompt_id):
        response = urllib.request.urlopen(f"{self.server_url}/history/{prompt_id}")
        return json.loads(response.read())

    def wait_for_completion(self, prompt_id, timeout=300, poll_interval=2):
        start = time.time()
        while time.time() - start < timeout:
            try:
                history = self.get_history(prompt_id)
                if prompt_id in history:
                    return history[prompt_id]
            except Exception:
                pass
            time.sleep(poll_interval)
        raise TimeoutError(f"Generation timed out after {timeout}s")

    def get_image(self, filename, subfolder="", folder_type="output"):
        params = urllib.parse.urlencode({"filename": filename, "subfolder": subfolder, "type": folder_type})
        response = urllib.request.urlopen(f"{self.server_url}/view?{params}")
        return response.read()

    def generate_and_save(self, workflow, output_path, timeout=300):
        """Queue a workflow, wait for it, and save all output images."""
        result = self.queue_prompt(workflow)
        prompt_id = result["prompt_id"]
        print(f"  Queued prompt: {prompt_id}")

        history = self.wait_for_completion(prompt_id, timeout=timeout)
        outputs = history.get("outputs", {})

        saved_files = []
        for node_id, node_output in outputs.items():
            if "images" in node_output:
                for i, img_info in enumerate(node_output["images"]):
                    img_data = self.get_image(
                        img_info["filename"],
                        img_info.get("subfolder", ""),
                        img_info.get("type", "output"),
                    )
                    out_dir = Path(output_path)
                    out_dir.mkdir(parents=True, exist_ok=True)

                    ext = Path(img_info["filename"]).suffix or ".png"
                    if len(node_output["images"]) == 1 and len(outputs) == 1:
                        save_path = out_dir / f"output{ext}"
                    else:
                        save_path = out_dir / f"output_{node_id}_{i}{ext}"

                    with open(save_path, "wb") as f:
                        f.write(img_data)
                    saved_files.append(str(save_path))
                    print(f"  Saved: {save_path}")

        return saved_files


import urllib.parse  # needed for get_image
