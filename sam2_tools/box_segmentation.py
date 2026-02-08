import os
import numpy as np
import torch
import cv2
from PIL import Image
from datetime import datetime, timezone

from sam2.build_sam import build_sam2
from sam2.sam2_image_predictor import SAM2ImagePredictor

from .shared_utils import (
    load_or_create_config,
    get_unique_path,
    save_pfm,
    load_image_rgb,
    BoxSelector,
)


def run_box_segmentation(
    input_path, output_path, num_masks, model_id, box, pfm, overlay
):
    # To save in a subfolder
    # base = os.path.splitext(os.path.basename(input_path))[0]
    # save_dir = os.path.join(output_path, base)
    # os.makedirs
    # To save in same folder
    save_dir = output_path
    base = os.path.splitext(os.path.basename(input_path))[0]

    config = load_or_create_config()
    checkpoints = config["checkpoints"]
    checkpoint = checkpoints[str(model_id)]

    # Model config
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

    rgb, bgr_img = load_image_rgb(input_path)
    if rgb is None or bgr_img is None:
        return
    H, W, _ = bgr_img.shape

    # Get user box if not provided
    if box is None:
        print("Draw selection box...")
        win = "Box Selection (Enter=OK, R=reset, Esc=cancel)"
        selector = BoxSelector(bgr_img.copy(), win_name=win)

        cv2.namedWindow(win, cv2.WINDOW_NORMAL)
        cv2.setMouseCallback(win, selector.mouse_cb)

        while True:
            cv2.imshow(win, selector.image_bgr)
            key = cv2.waitKey(20) & 0xFF
            if key == 13:
                b = selector.get_box()
                if b:
                    box = b
                    break
            elif key in (ord("r"), ord("R")):
                selector.reset()
            elif key == 27:
                cv2.destroyAllWindows()
                return
        cv2.destroyAllWindows()

    x1, y1, x2, y2 = box

    # Load model
    sam2_model = build_sam2(model_cfg, checkpoint, device=device)
    predictor = SAM2ImagePredictor(sam2_model)

    # Predict masks
    box_arr = np.array([x1, y1, x2, y2], dtype=np.float32)

    with torch.inference_mode():
        predictor.set_image(rgb)
        masks, scores, _ = predictor.predict(box=box_arr, multimask_output=True)

    if len(masks) == 0:
        print("No masks returned.")
        return

    order = np.argsort(-np.array(scores))
    masks = np.array(masks)[order]
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
    # Save masks
    for i, m in enumerate(masks[:num_masks]):
        seg = np.squeeze(m)
        if pfm:
            out = get_unique_path(f"{save_dir}/{base}_{ts}_mask_{i}.pfm")
            save_pfm(out, seg.astype(np.float32))
        else:
            out = get_unique_path(f"{save_dir}/{base}_{ts}_mask_{i}.png")
            mask = seg.astype(np.uint8)
            Image.fromarray(mask * 255).save(out)

    # Optional overlay
    if overlay:
        best = np.squeeze(masks[0]).astype(bool)
        overlay_img = rgb.copy()
        overlay_img[best] = [255, 0, 0]
        out = get_unique_path(f"{save_dir}/{base}_{ts}_overlay.jpg")
        Image.fromarray(overlay_img).save(out, quality=95)
        print("Saved overlay:", out)
