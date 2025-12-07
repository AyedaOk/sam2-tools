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

### Download model checkpoints
Download the SAM2 model checkpoint files from:

https://github.com/facebookresearch/sam2?tab=readme-ov-file#download-checkpoints

Place the downloaded checkpoint files into the default directory:

```
~/.config/sam2/checkpoints/
```

Your configuration directory should look like:

```
~/.config/sam2/
    config.yaml
    checkpoints/
        <checkpoint files>
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

Create launcher in `/usr/local/bin/sam2-tools`:
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
## Windows
Install the following first:

• Python 3.10–3.13  
https://www.python.org/downloads/  

• Microsoft Visual C++ Redistributable (required for PyTorch)  
https://aka.ms/vs/17/release/vc_redist.x64.exe  

• Git for Windows  
https://git-scm.com/download/win  

Open PowerShell and clone the project (recommended location: Documents):

```
cd $env:USERPROFILE\Documents
git clone https://github.com/AyedaOk/sam2-tools
cd sam2-tools
python -m venv venv
```

If PowerShell blocks script execution, allow local scripts:

```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Activate the virtual environment and install dependencies:

```
venv\Scripts\activate
pip install -r requirements.txt
```

Initialize the configuration file (if it does not already exist):

```
deactivate
.\launcher\sam2-tools.bat --config
```

Download the SAM2 model checkpoints from:  
https://github.com/facebookresearch/sam2?tab=readme-ov-file#download-checkpoints

Place all downloaded checkpoint files into the default directory:

```
C:\Users\YOURNAME\AppData\Roaming\sam2\checkpoints\
```

Your configuration directory should look like:

```
AppData\Roaming\sam2\
    config.yaml
    checkpoints\
        <checkpoint files>
```

Run the GUI:

```
.\launcher\sam2-tools.bat
```

or the packaged executable (if present):

```
.\launcher\sam2-tools.exe
```

---

## Requirements
• Python 3.10+  
• Tkinter (install with: `sudo apt install python3-tk` or `sudo pacman -S tk`)  

---

## License
