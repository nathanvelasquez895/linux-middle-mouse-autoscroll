#!/bin/bash
# =============================================================================
# Middle Mouse Toggle-Scroll for Linux (Debian-based, X11)
# =============================================================================
# WHAT THIS DOES:
#   Click middle mouse button (scroll wheel click) to START autoscroll.
#   An anchor icon appears where you clicked.
#   Move mouse UP, DOWN, LEFT, or RIGHT from that point to scroll.
#   The farther from the anchor, the faster it scrolls.
#   Click middle mouse again to STOP. Icon disappears.
#
# REQUIREMENTS:
#   - Debian-based distro (Ubuntu, Mint, Pop!_OS, Debian, etc.)
#   - X11 display server (not Wayland)
#
# STUDENT NOTE:
#   This is a bash shell script. Bash is a command language built into Linux.
#   Lines starting with # are comments — they are ignored when the script runs.
#   "set -e" means "stop immediately if any command fails" — good practice.
# =============================================================================

set -e

echo "=== Middle Mouse Toggle-Scroll Setup ==="

# =============================================================================
# STEP 1 — INSTALL DEPENDENCIES
# =============================================================================
# STUDENT NOTE:
#   These are external programs our script depends on.
#   - xbindkeys: listens for mouse/keyboard input and runs commands in response
#   - xdotool: simulates mouse clicks and reads mouse position programmatically
#   - x11-xserver-utils: utilities for X11 (the display system Ubuntu uses)
#   - bc: a calculator tool used for floating point math in bash
#     (bash can only do integer math natively)
#   - python3-tk: Python's built-in GUI library (tkinter), used for the icon window
#   - python3-pil, python3-pil.imagetk: Pillow image library, lets us load PNG files
# =============================================================================

echo "[1/4] Installing dependencies..."
sudo apt-get update -q
sudo apt-get install -y xbindkeys xdotool x11-xserver-utils bc python3-tk python3-pil python3-pil.imagetk

# =============================================================================
# STEP 2 — BACK UP EXISTING XBINDKEYS CONFIG
# =============================================================================
# STUDENT NOTE:
#   xbindkeys reads its configuration from ~/.xbindkeysrc
#   The ~ means "home directory" (e.g. /home/nate)
#   We back it up before modifying it so we don't destroy anything the user had before.
#   "-f" in the if statement means "does this file exist?"
# =============================================================================

if [ -f "$HOME/.xbindkeysrc" ]; then
    cp "$HOME/.xbindkeysrc" "$HOME/.xbindkeysrc.bak"
    echo "      Backed up existing ~/.xbindkeysrc to ~/.xbindkeysrc.bak"
fi

# =============================================================================
# STEP 3 — CREATE DIRECTORIES AND DEFAULT ICON
# =============================================================================
# STUDENT NOTE:
#   mkdir -p creates a directory and any missing parent directories.
#   We store the icon in ~/.local/share/middle-scroll/
#   The default icon is an SVG (vector graphic) drawn with XML tags.
#   If the user drops their own anchor.png in that folder, it gets used instead.
# =============================================================================

echo "[2/4] Writing scripts and icon..."
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/middle-scroll"

ICON_PATH="$HOME/.local/share/middle-scroll/anchor.svg"

if [ ! -f "$HOME/.local/share/middle-scroll/anchor.png" ]; then
    cat > "$ICON_PATH" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="22" fill="none" stroke="#444" stroke-width="2"/>
  <polygon points="24,6 16,18 32,18" fill="#444"/>
  <polygon points="24,42 16,30 32,30" fill="#444"/>
  <polygon points="6,24 18,16 18,32" fill="#444"/>
  <polygon points="42,24 30,16 30,32" fill="#444"/>
  <circle cx="24" cy="24" r="4" fill="#444"/>
</svg>
SVGEOF
    echo "      Default anchor icon written to $ICON_PATH"
    echo "      To use your own icon, place a 48x48 PNG at:"
    echo "      ~/.local/share/middle-scroll/anchor.png"
fi

# =============================================================================
# STEP 4 — WRITE THE PYTHON OVERLAY SCRIPT
# =============================================================================
# STUDENT NOTE:
#   This is a separate Python script that shows the anchor icon on screen.
#   It creates a small borderless window (no title bar, no borders) at the
#   exact position where you clicked.
#
#   Key concepts used here:
#   - tkinter: Python's standard GUI toolkit for creating windows and widgets
#   - PIL (Pillow): image processing library — used to load and resize the PNG
#   - signal.SIGTERM: a signal sent to a process to ask it to terminate cleanly
#     When our main scroll daemon kills this overlay, it sends SIGTERM,
#     and we catch it here to close the window properly instead of leaving it stuck.
#
#   Why a separate script?
#   Bash can't create GUI windows, so we delegate that job to Python.
#   The main bash script launches this as a background process and tracks its PID
#   so it can kill it when scrolling stops.
# =============================================================================

cat > "$HOME/.local/bin/middle-scroll-overlay.py" << 'PYEOF'
#!/usr/bin/env python3
import sys, os, signal, tkinter as tk
from PIL import Image, ImageTk, ImageDraw

x, y = int(sys.argv[1]), int(sys.argv[2])
icon_dir = os.path.expanduser("~/.local/share/middle-scroll")
png_path = os.path.join(icon_dir, "anchor.png")

SIZE = 48

root = tk.Tk()
root.overrideredirect(True)
root.attributes("-topmost", True)
root.attributes("-alpha", 0.75)
root.configure(bg="black")
root.geometry(f"{SIZE}x{SIZE}+{x - SIZE//2}+{y - SIZE//2}")

if os.path.exists(png_path):
    raw = Image.open(png_path).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
    bg = Image.new("RGB", (SIZE, SIZE), "black")
    bg.paste(raw, mask=raw.split()[3])
    photo = ImageTk.PhotoImage(bg)
else:
    # Default 4-directional compass rose icon
    img = Image.new("RGB", (SIZE, SIZE), "black")
    draw = ImageDraw.Draw(img)
    cx, cy = SIZE//2, SIZE//2

    # Outer circle
    draw.ellipse([2, 2, SIZE-3, SIZE-3], fill="#333333", outline="#aaaaaa", width=2)

    # Up arrow
    draw.polygon([(cx, 6), (cx-6, 16), (cx+6, 16)], fill="white")
    # Down arrow
    draw.polygon([(cx, SIZE-6), (cx-6, SIZE-16), (cx+6, SIZE-16)], fill="white")
    # Left arrow
    draw.polygon([(6, cy), (16, cy-6), (16, cy+6)], fill="white")
    # Right arrow
    draw.polygon([(SIZE-6, cy), (SIZE-16, cy-6), (SIZE-16, cy+6)], fill="white")

    # Center dot
    draw.ellipse([cx-3, cy-3, cx+3, cy+3], fill="white")

    photo = ImageTk.PhotoImage(img)

lbl = tk.Label(root, image=photo, bg="black", borderwidth=0)
lbl.pack()

signal.signal(signal.SIGTERM, lambda *_: root.destroy())

root.mainloop()
PYEOF
chmod +x "$HOME/.local/bin/middle-scroll-overlay.py"

# =============================================================================
# STEP 5 — WRITE THE MAIN SCROLL DAEMON
# =============================================================================
# STUDENT NOTE:
#   This is the core logic script. It runs in the background as a "daemon"
#   (a background process that keeps running and doing work).
#
#   Key concepts:
#   - PID file: a small file containing a process ID number. We use this to
#     track whether the daemon is already running, so we can toggle it off.
#     If the PID file exists = scroll is ON. If not = scroll is OFF.
#   - xdotool getmouselocation: reads the current mouse cursor position
#   - xdotool click 4/5: simulates scroll up (4) or scroll down (5)
#   - xdotool click 6/7: simulates scroll left (6) or scroll right (7)
#   - bc: used for floating point math to calculate scroll speed delay
#   - The scroll speed is based on distance from the anchor point:
#     farther away = shorter delay between scroll ticks = faster scrolling
#     This mimics exactly how Windows autoscroll works.
# =============================================================================

cat > "$HOME/.local/bin/middle-scroll.sh" << 'EOF'
#!/bin/bash

PIDFILE="/tmp/middle-scroll.pid"
OVERLAY_PIDFILE="/tmp/middle-scroll-overlay.pid"

# --- TOGGLE OFF ---
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")

    if [ -f "$OVERLAY_PIDFILE" ]; then
        kill "$(cat $OVERLAY_PIDFILE)" 2>/dev/null
        rm -f "$OVERLAY_PIDFILE"
    fi
    pkill -f "middle-scroll-overlay.py" 2>/dev/null || true

    kill "$OLD_PID" 2>/dev/null
    rm -f "$PIDFILE"
    exit 0
fi

# --- TOGGLE ON ---
echo $$ > "$PIDFILE"

ANCHOR=$(xdotool getmouselocation --shell)
ANCHOR_X=$(echo "$ANCHOR" | grep "^X=" | cut -d= -f2)
ANCHOR_Y=$(echo "$ANCHOR" | grep "^Y=" | cut -d= -f2)

python3 "$HOME/.local/bin/middle-scroll-overlay.py" "$ANCHOR_X" "$ANCHOR_Y" &
echo $! > "$OVERLAY_PIDFILE"

# --- TUNING VARIABLES ---
# Adjust these to change how scrolling feels
DEADZONE=10        # pixels from anchor where nothing happens (avoids jitter)
SPEED_DIVISOR=40   # lower = speed ramps up faster with distance
MAX_DELAY=0.15     # seconds between scroll ticks at slowest speed (close to anchor)
MIN_DELAY=0.01     # seconds between scroll ticks at fastest speed (far from anchor)

# --- MAIN SCROLL LOOP ---
while true; do
    # Get current mouse position (both X and Y)
    MOUSE=$(xdotool getmouselocation --shell)
    CUR_X=$(echo "$MOUSE" | grep "^X=" | cut -d= -f2)
    CUR_Y=$(echo "$MOUSE" | grep "^Y=" | cut -d= -f2)

    # Calculate distance from anchor in both axes
    DIST_X=$(( CUR_X - ANCHOR_X ))
    DIST_Y=$(( CUR_Y - ANCHOR_Y ))

    # Absolute values for dead zone and speed calculation
    ABS_X=${DIST_X#-}
    ABS_Y=${DIST_Y#-}

    # If cursor is within dead zone on both axes, do nothing
    if [ "$ABS_X" -le "$DEADZONE" ] && [ "$ABS_Y" -le "$DEADZONE" ]; then
        sleep 0.05
        continue
    fi

    # --- VERTICAL SCROLL ---
    if [ "$ABS_Y" -gt "$DEADZONE" ]; then
        DELAY_Y=$(echo "scale=4; $MAX_DELAY - ($ABS_Y / $SPEED_DIVISOR) * ($MAX_DELAY - $MIN_DELAY)" | bc)
        DELAY_Y=$(echo "scale=4; if ($DELAY_Y < $MIN_DELAY) $MIN_DELAY else if ($DELAY_Y > $MAX_DELAY) $MAX_DELAY else $DELAY_Y" | bc)

        if [ "$DIST_Y" -gt 0 ]; then
            xdotool click 5   # scroll down
        else
            xdotool click 4   # scroll up
        fi
        sleep "$DELAY_Y"
    fi

    # --- HORIZONTAL SCROLL ---
    if [ "$ABS_X" -gt "$DEADZONE" ]; then
        DELAY_X=$(echo "scale=4; $MAX_DELAY - ($ABS_X / $SPEED_DIVISOR) * ($MAX_DELAY - $MIN_DELAY)" | bc)
        DELAY_X=$(echo "scale=4; if ($DELAY_X < $MIN_DELAY) $MIN_DELAY else if ($DELAY_X > $MAX_DELAY) $MAX_DELAY else $DELAY_X" | bc)

        if [ "$DIST_X" -gt 0 ]; then
            xdotool click 7   # scroll right
        else
            xdotool click 6   # scroll left
        fi
        sleep "$DELAY_X"
    fi

done

# Cleanup if loop exits unexpectedly
if [ -f "$OVERLAY_PIDFILE" ]; then
    kill "$(cat $OVERLAY_PIDFILE)" 2>/dev/null
    rm -f "$OVERLAY_PIDFILE"
fi
pkill -f "middle-scroll-overlay.py" 2>/dev/null || true
rm -f "$PIDFILE"
EOF
chmod +x "$HOME/.local/bin/middle-scroll.sh"

# =============================================================================
# STEP 6 — CONFIGURE XBINDKEYS
# =============================================================================
# STUDENT NOTE:
#   xbindkeys watches for input events (mouse buttons, key combos) and runs
#   commands when they fire. Its config file is ~/.xbindkeysrc
#
#   "b:2" means mouse button 2, which is the middle mouse button.
#   The & at the end of the command runs it in the background so xbindkeys
#   doesn't freeze waiting for the script to finish.
#
#   We grep out any old middle-scroll entry first to avoid duplicates
#   if this setup script is run more than once.
# =============================================================================

echo "[3/4] Configuring xbindkeys..."
grep -v "middle-scroll" "$HOME/.xbindkeysrc" > /tmp/.xbindkeysrc.tmp 2>/dev/null || true
mv /tmp/.xbindkeysrc.tmp "$HOME/.xbindkeysrc" 2>/dev/null || true

cat >> "$HOME/.xbindkeysrc" << 'EOF'

# Middle mouse button: toggle scroll mode on/off
"$HOME/.local/bin/middle-scroll.sh &"
  b:2
EOF

# =============================================================================
# STEP 7 — AUTOSTART ON LOGIN
# =============================================================================
# STUDENT NOTE:
#   ~/.config/autostart/ is a standard directory Ubuntu checks on login.
#   Any .desktop file placed here gets launched automatically when you log in.
#   This is how we make xbindkeys start with the system so the scroll feature
#   is always ready without manually running anything.
# =============================================================================

echo "[4/4] Adding xbindkeys to startup..."
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/xbindkeys.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=xbindkeys
Exec=xbindkeys
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

pkill xbindkeys 2>/dev/null || true
pkill -f "middle-scroll-overlay.py" 2>/dev/null || true
rm -f /tmp/middle-scroll.pid /tmp/middle-scroll-overlay.pid
sleep 0.5
xbindkeys

echo ""
echo "=== Done! ==="
echo ""
echo "========================================"
echo "HOW TO USE"
echo "========================================"
echo "1. Click your middle mouse button once to START scrolling"
echo "   - An anchor icon appears where you clicked"
echo "   - Move the mouse UP, DOWN, LEFT, or RIGHT from that point"
echo "   - The farther from the anchor, the faster it scrolls"
echo "   - Diagonal movement scrolls both axes simultaneously"
echo "   - There is a small dead zone right around the anchor"
echo "2. Click the middle mouse button again to STOP scrolling"
echo "   - The anchor icon disappears"
echo ""
echo "NOTE: Horizontal scrolling (left/right) requires the application"
echo "to support it. Most browsers and text editors do."
echo ""
echo "========================================"
echo "CUSTOM ANCHOR ICON"
echo "========================================"
echo "Drop a PNG named 'anchor.png' here to use your own icon:"
echo "  ~/.local/share/middle-scroll/anchor.png"
echo "Recommended size: 48x48px"
echo ""
echo "========================================"
echo "TUNING SCROLL FEEL"
echo "========================================"
echo "Edit ~/.local/bin/middle-scroll.sh and adjust:"
echo "  DEADZONE      = pixels around anchor with no scroll (default: 10)"
echo "  SPEED_DIVISOR = lower = faster speed ramp with distance (default: 40)"
echo "  MAX_DELAY     = slowest scroll interval in seconds (default: 0.15)"
echo "  MIN_DELAY     = fastest scroll interval in seconds (default: 0.01)"
echo ""
echo "========================================"
echo "UNINSTALL"
echo "========================================"
echo "  pkill xbindkeys"
echo "  pkill -f middle-scroll-overlay.py"
echo "  rm -f ~/.config/autostart/xbindkeys.desktop"
echo "  rm -f ~/.local/bin/middle-scroll.sh"
echo "  rm -f ~/.local/bin/middle-scroll-overlay.py"
echo "  rm -rf ~/.local/share/middle-scroll"
echo "  rm -f /tmp/middle-scroll.pid /tmp/middle-scroll-overlay.pid"
echo "  mv ~/.xbindkeysrc.bak ~/.xbindkeysrc  # restore prior config if needed"
echo "  # Optional: sudo apt-get remove xbindkeys xdotool bc python3-pil python3-pil.imagetk"
echo ""
echo "========================================"
echo "KNOWN LIMITATION"
echo "========================================"
echo "Middle clicking a link will NOT open it in a new tab while this script"
echo "is installed, because xbindkeys intercepts the button before the browser"
echo "sees it. There is no clean fix at the shell script level."
echo ""
echo "========================================"
echo "FUTURE GNOME EXTENSION ROADMAP"
echo "========================================"
echo "THE REAL FIX — rewrite as a GNOME Shell extension (JavaScript):"
echo "  A GNOME extension has compositor-level access, meaning it can inspect"
echo "  what is actually under the cursor before deciding what to do with a click."
echo ""
echo "  The approach:"
echo "  1. Intercept middle click before it reaches the application"
echo "  2. Use AT-SPI to check whether the element under the cursor is a hyperlink"
echo "  3. If cursor is over a link: pass the click through unchanged"
echo "     -> browser opens new tab as normal"
echo "  4. If cursor is NOT over a link: swallow the click, start scroll mode"
echo "     -> autoscroll activates"
echo ""
echo "  Key APIs to learn when you get there:"
echo "  - Clutter  : catching and intercepting mouse events"
echo "  - St.Widget / Clutter.Actor : drawing the anchor icon"
echo "  - Gio      : firing scroll events"
echo "  - AT-SPI   : inspecting UI elements under the cursor"
