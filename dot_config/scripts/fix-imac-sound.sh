#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  fix-imac-sound.sh  –  Build & install the patched snd-hda-codec-cs8409
#                        kernel module for iMac19,2
# ---------------------------------------------------------------------------
#  This script is deliberately verbose so you can see every step.
#  It will:
#    1. Clone https://github.com/egorenar/snd-hda-codec-cs8409
#       into ~/snd-hda-codec-cs8409
#    2. Enter that directory
#    3. Build the module with `make`
#    4. Install the module with `sudo make install`
# ---------------------------------------------------------------------------
set -e          # stop on first error
set -x          # print every command before it runs
# ---------------------------------------------------------------------------

REPO_URL="https://github.com/egorenar/snd-hda-codec-cs8409"
INSTALL_DIR="$HOME/snd-hda-codec-cs8409"

# --- 1. Clone the repository (only if it does not already exist) -------------
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Directory $INSTALL_DIR already exists; skipping clone."
else
    echo "Cloning $REPO_URL into $INSTALL_DIR ..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# --- 2. Enter the directory --------------------------------------------------
cd "$INSTALL_DIR"
echo "Now in $(pwd)"

# --- 3. Build the kernel module --------------------------------------------
echo "Running make ..."
make

# --- 4. Install the module (requires root) -----------------------------------
echo "Running sudo make install ..."
sudo make install

# --- 5. Inform the user ------------------------------------------------------
echo "------------------------------------------------------------------------"
echo "Build and installation complete."
echo "You may now load the new module with:"
echo "    sudo modprobe -r snd_hda_codec_cs8409   # unload old if present"
echo "    sudo modprobe snd_hda_codec_cs8409      # load new module"
echo "or simply reboot."
echo "------------------------------------------------------------------------"
