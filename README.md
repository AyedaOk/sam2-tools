# SAM2‑Tools
SAM2‑Tools is a lightweight Python application offering both a simple GUI and command‑line interface for running Meta AI’s Segment Anything 2 (SAM2) model. It supports box selection, auto segmentation, and point‑based segmentation.

---

## Features
- CLI interface for integration with Darktable  
- Basic GUI interface  
- Works with Darktable via PFM output  
- Works with the Darktable SAM2 plugin – [GitHub repo](https://github.com/AyedaOk/DT_custom_script)
- Segmentation modes: Box, Auto, Points  
- User config stored in `~/.config/sam2/config.yaml`  
- Cross‑platform: Linux, macOS, Windows  

---

## Install
### Installation Videos

Step‑by‑step install walkthrough on Linux → https://youtu.be/C98gejXkQqI

Step‑by‑step install walkthrough on Windows → https://youtu.be/atBNxKHZ0ag

Step‑by‑step install walkthrough on macOS → Comming soon...

### Installation scripts

The installation script is the easiest way to install **sam2-tools**. It will:

* Install dependencies
* Clone the repository
* Create a virtual environment
* Install the Python app and its requirements
* Download the SAM2 model checkpoints (Optional)
* Install the Darktable plugin (Optional)

#### Linux

```
bash curl -fsSL https://raw.githubusercontent.com/AyedaOk/sam2-tools/main/installer/linux_install.sh | bash
```

#### Windows

```
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/AyedaOk/sam2-tools/release/v0.2/installer/win_install.ps1 | iex"
```

#### macOS

```
curl -fsSL "https://raw.githubusercontent.com/AyedaOk/sam2-tools/release/v0.2/installer/mac_install.sh" | bash
```

### Linux Installation Steps:

Install the following first:

- Arch: `sudo pacman -S python tk git` 

- Debian/Ubuntu: `sudo apt install python3 python3-tk git` 

- Fedora: `sudo dnf install -y python3 git python3-tkinter gcc gcc-c++ make python-devel` 

Clone the repo, create the virtual environment and install the Python App:

```
git clone https://github.com/AyedaOk/sam2-tools.git
cd sam2-tools
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

On some Linux distributions, you might encounter this error during installation:

```
[Errno 122] Disk quota exceeded
```

This usually means your system’s temporary directory (`/tmp`) is full or restricted.  
You can work around it by telling `pip` to use a temporary directory inside your home folder:

```
mkdir $HOME/tmp
export TMPDIR=$HOME/tmp
pip install -r requirements.txt
rm -dfr $HOME/tmp
```

Create the config file if it doesn’t exist:
```
python3 main.py --config
```

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

Run the GUI:

```
python3 main.py
```

#### Optional: System‑wide launcher (required for Darktable integration)
To install like a system‑wide “app”:

Place the project in `/opt`:
```
cd ..
sudo cp -rp sam2-tools /opt/
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
### Windows Installation Steps:
Install the following first:

- Python 3.10–3.13  
https://www.python.org/downloads/  

```
winget install -e --id Python.Python.3.13
```

- Microsoft Visual C++ Redistributable (required for PyTorch)  
https://aka.ms/vs/17/release/vc_redist.x64.exe  
```
winget install --id Microsoft.VCRedist.2015+.x64
```

- Git for Windows  
https://git-scm.com/download/win  
```
winget install --id Git.Git -e --source winget
```

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

Create the config file if it doesn’t exist:
```
python main.py --config
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

or 

```
.\launcher\sam2-tools.exe
```

### macOS Installation Steps

Install Homebrew (required):  
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install Python, Git, and Tkinter.
```
brew install python git python-tk
```

**Important:**  
Your Python version may differ (3.12 / 3.13 / 3.14).  
Use this command to see the exact version installed:

```
ls /opt/homebrew/bin/python3*
```

You will see something like `python3 python 3.13 python3.14` — use that version above 3.10 in all commands below.

Clone the project

```
cd ~
git clone https://github.com/AyedaOk/sam2-tools.git
cd sam2-tools
```

Create and activate the virtual environment  

Replace `python3.14` with whatever version you have:

```
python3.14 -m venv venv
source venv/bin/activate
```

Install dependencies  
```
pip install -r requirements.txt
```

Create the config file (first‑time setup)
```
python3.14 main.py --config
```

Download SAM2 model checkpoints from:
https://github.com/facebookresearch/sam2?tab=readme-ov-file#download-checkpoints

Place them here:

```
~/.config/sam2/checkpoints/
```

Your directory should look like:
```
~/.config/sam2/
    config.yaml
    checkpoints/
        <checkpoint files>
```

Run the GUI  
```
python3.14 main.py
```

#### Optional: macOS Launcher (required for Darktable integration)

The launcher is included in:

```
sam2-tools/launcher/sam2-tools.command
```

Edit the first line to match where you cloned the project.  
Example (default installation to your home directory):

```
#!/bin/bash
cd "$HOME/sam2-tools"
source venv/bin/activate
python3.14 main.py "$@"
```

If your install directory is different, update the `cd` line accordingly.

Make the launcher executable:

```
cd ..
chmod +x sam2-tools/launcher/sam2-tools.command
```

Now you can **double‑click** `sam2-tools.command` in Finder to start the app.


## Usage

### GUI
```
python3 main.py
```

#### CLI

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

## License

GPL-3.0
