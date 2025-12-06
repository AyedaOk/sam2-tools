# SAM2‑Tools
SAM2‑Tools is a lightweight Python application offering both a simple GUI and command‑line interface for running Meta AI’s Segment Anything 2 (SAM2) model.  
It supports box selection, auto segmentation, and point‑based segmentation.

---

## Features
• CLI interface for integration with Darktable  
• Basic GUI interface  
• Works with Darktable via PFM output  
• Segmentation modes: Box, Auto, Points  
• User config stored in `~/.config/sam2/config.yaml`  
• Cross‑platform: Linux, macOS, Windows  

---

## Install
```
git clone https://github.com/AyedaOk/sam2-tools.git
cd sam2-tools
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Create the config file if it doesn’t exist:
```
python3 main.py --config
```

---

## Usage

### GUI
```
python3 main.py
```

### CLI

Auto segmentation:
```
python3 main.py --auto -i /path/to/input.jpg -o /path/to/output/
```

Box mode (default):
```
python3 main.py -i /path/to/input.jpg -o /path/to/output/
```

Point‑based segmentation:
```
python3 main.py --points -i /path/to/input.jpg -o /path/to/output/
```

---

## Optional: System‑wide launcher  
To install like a system‑wide “app”:

Place the project in `/opt`:
```
sudo cp -r sam2-tools /opt/
```

Create launcher `/usr/local/bin/sam2-tools`:
```
#!/bin/bash
cd /opt/sam2-tools
./venv/bin/python3 main.py "$@"
```

Make it executable:
```
sudo chmod +x /usr/local/bin/sam2-tools
```

Now you can run:
```
sam2-tools
```

---

## Requirements
• Python 3.10+  
• Tkinter (install with: `sudo apt install python3-tk` or `sudo pacman -S tk`)  

---

## License
