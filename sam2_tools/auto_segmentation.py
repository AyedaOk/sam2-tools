import os
import numpy as np
import torch
from PIL import Image

from sam2.build_sam import build_sam2
from sam2.automatic_mask_generator import SAM2AutomaticMaskGenerator
from .shared_utils import (
    load_or_create_config,
    get_unique_path,
    save_pfm,
)

def run_auto_segmentation(input_path, output_path, num_masks, model_id, pfm):
    # To save in a subfolder
    # base = os.path.splitext(os.path.basename(input_path))[0]
    # save_dir = os.path.join(output_path, base)
    # os.makedirs(save_dir, exist_ok=True)
    save_dir = os.path.dirname(input_path)
    base = os.path.splitext(os.path.basename(input_path))[0]

    # Load config
    config = load_or_create_config()
    checkpoints = config["checkpoints"]
    checkpoint = checkpoints[str(model_id)]

    # Select model config
    if model_id == 1:
        model_cfg = "configs/sam2.1/sam2.1_hiera_l.yaml"
    elif model_id == 2:
        model_cfg = "configs/sam2.1/sam2.1_hiera_b+.yaml"
    elif model_id == 3:
        model_cfg = "configs/sam2.1/sam2.1_hiera_s.yaml"
    else:
        model_cfg = "configs/sam2.1/sam2.1_hiera_t.yaml"

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print("Using device:", device)

    # Load model
    sam2_model = build_sam2(model_cfg, checkpoint, device=device, apply_postprocessing=False)
    generator = SAM2AutomaticMaskGenerator(sam2_model)

    # Load input
    img = Image.open(input_path).convert("RGB")
    image_np = np.array(img)

    with torch.inference_mode():
        masks = generator.generate(image_np)

    print("Generated masks:", len(masks))

    # Save masks
    for i, m in enumerate(masks[:num_masks]):
        seg = m["segmentation"]
        if pfm:
            out = get_unique_path(f"{save_dir}/{base}_mask_{i}.pfm")
            save_pfm(out, seg)
        else:
            out = get_unique_path(f"{save_dir}/{base}_mask_{i}.png")
            Image.fromarray((seg.astype(np.uint8) * 255)).save(out)

        print("Saved:", out)
