# linux-middle-mouse-autoscroll

Windows-style middle mouse autoscroll for Linux (Debian/X11). Click to anchor, move to scroll in any direction, click to stop.

---

## What does this do?

You know how in Windows you can click the scroll wheel and a little icon appears, then you just move the mouse, and the further you move, the faster it scrolls? Then you click again to stop?

Linux doesn't have that. This adds it.

---

## Requirements

- A **Debian-based Linux distro**  Ubuntu, Linux Mint, Pop!_OS, Debian, etc.
- **X11 display server** (not Wayland). If you're not sure which one you're on, open a terminal and type:
  ```
  echo $XDG_SESSION_TYPE
  ```
  If it says `x11` you're good. If it says `wayland` this won't work.

---

## How to download and install

### Step 1  Download the file

On this GitHub page, look for the green **"Code"** button near the top right. Click it, then click **"Download ZIP"**. Extract the ZIP somewhere you can find it, like your Downloads folder.

Or if you're comfortable with the terminal:
```bash
git clone https://github.com/YOUR-USERNAME/linux-middle-mouse-autoscroll.git
```

### Step 2  Open a terminal

Press `Ctrl + Alt + T` to open a terminal, or search for "Terminal" in your app menu.

### Step 3  Navigate to the folder

If you downloaded the ZIP and extracted it to your Downloads folder, type:
```bash
cd ~/Downloads/linux-middle-mouse-autoscroll-main
```

### Step 4  Make the script executable

Before you can run it, Linux needs permission to execute it:
```bash
chmod +x linux-middle-mouse-autoscroll.sh
```

### Step 5  Run the installer

```bash
./linux-middle-mouse-autoscroll.sh
```

It will ask for your password once to install the required tools. After that it sets everything up automatically and starts working immediately, no reboot needed.

---

## How to use it

1. **Click your middle mouse button** (the scroll wheel click) anywhere on the screen
2. A small icon appears where you clicked — this is your anchor point
3. **Move your mouse** away from the anchor to scroll:
   - Up = scroll up
   - Down = scroll down
   - Left = scroll left
   - Right = scroll right
   - Diagonal = scrolls both directions at once
   - The further from the anchor, the faster it scrolls
4. **Click the middle mouse button again** to stop — the icon disappears

---

## Tuning the scroll feel

If the scrolling feels too fast, too slow, or too sensitive, you can adjust it. Open a terminal and type:
```bash
nano ~/.local/bin/middle-scroll.sh
```
Look for these four lines near the top of the scroll loop:
```
DEADZONE=10
SPEED_DIVISOR=40
MAX_DELAY=0.15
MIN_DELAY=0.01
```
- **DEADZONE** how many pixels around the anchor do nothing (prevents accidental scrolling)
- **SPEED_DIVISOR** lower number means speed ramps up faster as you move away
- **MAX_DELAY** how slow the scrolling is when you're close to the anchor
- **MIN_DELAY** how fast the scrolling gets at maximum distance

Press `Ctrl + O` to save, then `Ctrl + X` to exit.

---

## Custom icon

Don't like the default compass rose icon? Drop your own image here:
```
~/.local/share/middle-scroll/anchor.png
```
Recommended size: 48x48 pixels, PNG format.

---

## Known limitation

While this is installed, **middle clicking a link will not open it in a new tab** — because the script intercepts the middle mouse button before the browser sees it. There is no clean fix at the shell script level.

The proper fix is to rewrite this as a GNOME Shell extension, which would have compositor-level access to check what's under the cursor before deciding what to do. See the roadmap below.

---

## Uninstall

```bash
pkill xbindkeys
pkill -f middle-scroll-overlay.py
rm -f ~/.config/autostart/xbindkeys.desktop
rm -f ~/.local/bin/middle-scroll.sh
rm -f ~/.local/bin/middle-scroll-overlay.py
rm -rf ~/.local/share/middle-scroll
rm -f /tmp/middle-scroll.pid /tmp/middle-scroll-overlay.pid
mv ~/.xbindkeysrc.bak ~/.xbindkeysrc
```
Optional — remove the installed tools if you don't use them for anything else:
```bash
sudo apt-get remove xbindkeys xdotool bc python3-pil python3-pil.imagetk
```

---

## Future roadmap — GNOME Shell extension

The goal is to eventually rewrite this as a proper GNOME Shell extension in JavaScript. That would fix the middle-click-on-links problem and work more cleanly with the desktop.

The core logic (anchor point, distance-based speed, 4-directional scroll, toggle) is already solved — it would just be a translation into JavaScript using these APIs:

- **Clutter** catches and intercepts mouse events (replaces xbindkeys)
- **St.Widget / Clutter.Actor** draws the anchor icon (replaces the Python overlay)
- **Gio** fires scroll events (replaces xdotool)
- **AT-SPI** inspects what's under the cursor to detect links (the new piece)

---

## A note on the code comments

The install script contains detailed `STUDENT NOTE` comments throughout. These were written for my own future reference as I learn computer science — they explain what each tool does and why decisions were made. If you're new to Linux or bash scripting, hopefully they're useful to you too.

---

## Tested on

- Ubuntu 24.04 LTS (X11)

If you get it working on another distro, feel free to open an issue and I'll add it to the list.
