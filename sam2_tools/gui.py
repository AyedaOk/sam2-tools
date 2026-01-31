import tkinter as tk
import os
from tkinter import filedialog, ttk, messagebox
from .auto_segmentation import run_auto_segmentation
from .box_segmentation import run_box_segmentation
from .point_segmentation import run_point_segmentation
from .shared_utils import BoxSelector


def start_gui():
    root = tk.Tk()
    root.title("SAM2 Segmentation Tool")

    tk.Label(root, text="Input image:").grid(row=0, column=0)
    input_var = tk.StringVar(value=os.path.expanduser("~"))
    tk.Entry(root, textvariable=input_var, width=40).grid(row=0, column=1)
    tk.Button(
        root,
        text="Browse",
        command=lambda: input_var.set(
            filedialog.askopenfilename(initialdir=os.path.expanduser("~"))
        ),
    ).grid(row=0, column=2)

    tk.Label(root, text="Output folder:").grid(row=1, column=0)
    output_var = tk.StringVar(value=os.path.expanduser("~"))
    tk.Entry(root, textvariable=output_var, width=40).grid(row=1, column=1)
    tk.Button(
        root,
        text="Browse",
        command=lambda: output_var.set(
            filedialog.askdirectory(initialdir=os.path.expanduser("~"))
        ),
    ).grid(row=1, column=2)

    tk.Label(root, text="Model:").grid(row=2, column=0)
    model_labels = ["Large", "Base+", "Small", "Tiny"]
    model_id_map = {
        "Large": 1,
        "Base+": 2,
        "Small": 3,
        "Tiny": 4,
    }
    model_var = tk.StringVar(value="Large")
    ttk.Combobox(root, textvariable=model_var, values=model_labels).grid(
        row=2, column=1
    )

    # Mode moved here (between model and num masks)
    tk.Label(root, text="Mode:").grid(row=3, column=0)
    mode_var = tk.StringVar(value="Box")
    ttk.Combobox(root, textvariable=mode_var, values=["Box", "Auto", "Points"]).grid(
        row=3, column=1
    )

    num_masks_lbl = tk.Label(root, text="Num Masks:")
    num_masks_lbl.grid(row=4, column=0)
    num_masks_var = tk.IntVar(value=1)
    num_masks_spin = tk.Spinbox(root, from_=1, to=10, textvariable=num_masks_var)
    num_masks_spin.grid(row=4, column=1)

    pfm_var = tk.BooleanVar()
    tk.Checkbutton(root, text="Save as PFM", variable=pfm_var).grid(row=5, column=0)

    overlay_var = tk.BooleanVar()
    overlay_chk = tk.Checkbutton(root, text="Overlay", variable=overlay_var)
    overlay_chk.grid(row=5, column=1)

    def _toggle_mode_controls(*_):
        if mode_var.get() == "Box":
            overlay_chk.grid()
            overlay_chk.config(state="normal")
            num_masks_lbl.grid()
            num_masks_spin.grid()
        else:
            overlay_var.set(False)
            overlay_chk.grid_remove()
            if mode_var.get() == "Auto":
                num_masks_lbl.grid()
                num_masks_spin.grid()
            else:
                num_masks_lbl.grid_remove()
                num_masks_spin.grid_remove()

    mode_var.trace_add("write", _toggle_mode_controls)
    _toggle_mode_controls()

    status_var = tk.StringVar(value="Ready.")
    tk.Label(root, textvariable=status_var, anchor="w").grid(
        row=6, column=0, columnspan=3, sticky="we", padx=4, pady=(6, 2)
    )

    run_btn = tk.Button(root, text="Run")
    run_btn.grid(row=7, column=1, pady=(2, 8))

    def _set_running(is_running: bool, msg: str):
        status_var.set(msg)
        run_btn.config(state=("disabled" if is_running else "normal"))

    def run_clicked():
        inp = input_var.get().strip()
        out = output_var.get().strip()
        model = model_id_map[model_var.get()]
        n = num_masks_var.get()
        mode = mode_var.get()
        save_pfm = pfm_var.get()
        overlay = overlay_var.get()

        _set_running(True, f"Running {mode}…")
        root.update_idletasks()

        def do_work():
            try:
                if mode == "Points":
                    run_point_segmentation(inp, out, n, model, save_pfm)
                elif mode == "Auto":
                    run_auto_segmentation(inp, out, n, model, save_pfm)
                else:
                    run_box_segmentation(inp, out, n, model, None, save_pfm, overlay)
                root.after(0, lambda: _set_running(False, "Done."))
            except Exception as exc:
                error_msg = str(exc)
                root.after(0, lambda: _set_running(False, "Failed."))
                root.after(0, lambda: messagebox.showerror("Error", error_msg))

        root.after(0, do_work)

    run_btn.config(command=run_clicked)

    root.mainloop()
