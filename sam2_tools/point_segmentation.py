import os
import numpy as np
import cv2
import torch
from PIL import Image

from sam2.build_sam import build_sam2
from sam2.sam2_image_predictor import SAM2ImagePredictor

from .shared_utils import (
    load_or_create_config,
    get_unique_path,
    save_pfm,
)

# ============================================================
# Point Selector (interactive point mode)
# ============================================================
class PointSelector:
    def __init__(self, img_bgr, predictor):
        self.clone = img_bgr.copy()
        self.image_bgr = img_bgr.copy()

        self.points_pos = []  # left-click = foreground
        self.points_neg = []  # right-click = background

        self.predictor = predictor
        self.current_mask = None
        self.rgb_for_predictor = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)

    def reset(self):
        self.image_bgr = self.clone.copy()
        self.points_pos.clear()
        self.points_neg.clear()
        self.current_mask = None

    def mouse_cb(self, event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            # Foreground click
            self.points_pos.append((x, y))
            self.update_mask()

        elif event == cv2.EVENT_MBUTTONDOWN:
            self.points_neg.append((x, y))
            self.update_mask()

        elif event == cv2.EVENT_RBUTTONDOWN:
            self.points_neg.append((x, y))
            self.update_mask()

    # ------------------------------------------------------------------
    def update_mask(self):
        # No points → no mask
        if not self.points_pos and not self.points_neg:
            self.current_mask = None
            self.render_preview()
            return

        # Prepare points for SAM2
        all_pts = self.points_pos + self.points_neg
        labels = [1] * len(self.points_pos) + [0] * len(self.points_neg)

        pts_arr = np.array(all_pts)
        labels_arr = np.array(labels)

        with torch.inference_mode():
            masks, scores, logits = self.predictor.predict(
                point_coords=pts_arr,
                point_labels=labels_arr,
                multimask_output=False,
            )

        self.current_mask = masks[0]  # best mask
        self.render_preview()

    # ------------------------------------------------------------------
    def render_preview(self):
        img = self.clone.copy()

        # Overlay mask
        if self.current_mask is not None:
            mask = (self.current_mask.squeeze() > 0).astype(np.uint8)
            # Red overlay for mask preview
            img[mask > 0] = (0, 0, 255)

        # Draw points
        for (x, y) in self.points_pos:
            cv2.circle(img, (x, y), 5, (0, 255, 0), -1)  # green = FG

        for (x, y) in self.points_neg:
            cv2.circle(img, (x, y), 5, (0, 0, 255), -1)  # red = BG

        self.image_bgr = img

# ============================================================
# RUN POINT SEGMENTATION
# ============================================================
def run_point_segmentation(
    input_path,
    output_path,
    num_masks=1,
    model_id=1,
    pfm=False,
):
    # Prepare output directories
    if not os.path.exists(input_path):
        print("Input not found:", input_path)
        return

    os.makedirs(output_path, exist_ok=True)
    #To save in a sub-folder
    # base = os.path.splitext(os.path.basename(input_path))[0]
    # save_dir = os.path.join(output_path, base)
    # os.makedirs(save_dir, exist_ok=True)
    #To save in same folder
    save_dir = output_path
    base = os.path.splitext(os.path.basename(input_path))[0]

    # Load config
    config = load_or_create_config()
    checkpoint = config["checkpoints"][str(model_id)]

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

    # Load predictor
    sam2_model = build_sam2(model_cfg, checkpoint, device=device)
    predictor = SAM2ImagePredictor(sam2_model)

    # Load image
    bgr_img = cv2.imread(input_path)
    if bgr_img is None:
        print("Failed to load image:", input_path)
        return

    # Prepare image for predictor
    rgb = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2RGB)

    with torch.inference_mode():
        predictor.set_image(rgb)

    # Create selector interface
    win = "Left Click=Positive, Right/Middle Click=Negative, Enter=Confirm, R=Reset, Esc=Cancel"
    selector = PointSelector(bgr_img, predictor)

    cv2.namedWindow(win, cv2.WINDOW_NORMAL)
    cv2.setMouseCallback(win, selector.mouse_cb)

    final_mask = None

    while True:
        cv2.imshow(win, selector.image_bgr)
        key = cv2.waitKey(20) & 0xFF

        if key == 13:  # ENTER
            final_mask = selector.current_mask
            break

        elif key in (ord("r"), ord("R")):
            selector.reset()

        elif key == 27:  # ESC
            cv2.destroyAllWindows()
            return

    cv2.destroyAllWindows()

    if final_mask is None:
        print("No mask generated.")
        return

    # Save final mask
    mask = final_mask.squeeze().astype(np.uint8) * 255

    if pfm:
        out = get_unique_path(f"{save_dir}/{base}_mask.pfm")
        save_pfm(out, final_mask.squeeze())  # PFM uses float mask, not 0–255
    else:
        out = get_unique_path(f"{save_dir}/{base}_mask.png")
        Image.fromarray(mask).save(out)

    print("Saved:", out)
