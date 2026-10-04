#!/usr/bin/env bash
# ============================================================
# Nate the Great's Flashing Tool (Linux)
# Requires adb and fastboot to be in PATH
# or in the same folder as this script.
#
# Usage:
#   chmod +x flash_helper_linux.sh
#   ./flash_helper_linux.sh
#
# Install platform-tools, for example:
#   Debian/Ubuntu: sudo apt install adb fastboot
#   Fedora:        sudo dnf install android-tools
#   Arch:          sudo pacman -S android-tools
# If the device is not detected, install the Android udev rules
# (package android-udev-rules or similar) or run with sudo.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB="adb"
FASTBOOT="fastboot"

# Prefer adb/fastboot next to this script if present.
if [ -f "$SCRIPT_DIR/adb" ] && [ -x "$SCRIPT_DIR/adb" ]; then ADB="$SCRIPT_DIR/adb"; fi
if [ -f "$SCRIPT_DIR/fastboot" ] && [ -x "$SCRIPT_DIR/fastboot" ]; then FASTBOOT="$SCRIPT_DIR/fastboot"; fi

# Make adb/fastboot next to this script available to manual commands too.
export PATH="$SCRIPT_DIR:$PATH"

ESC_WAIT=0.1
LINE="============================================================"

printf '\033]0;%s\007' "Nate the Great's Flashing Tool"

# ============================================================
# HELPERS
# ============================================================

pause_any() {
    printf 'Press any key to continue . . . '
    IFS= read -rsn1 _k || exit 1
    echo
}

pause_silent() {
    IFS= read -rsn1 _k || exit 1
}

# choice_key "ALLOWED" "Prompt: "  ->  sets CHOICE to the uppercase key pressed
choice_key() {
    local allowed="$1" prompt="$2" k
    printf '%s' "$prompt"
    while true; do
        IFS= read -rsn1 k || { echo; exit 1; }
        k="$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')"
        if [ -n "$k" ] && [[ "$allowed" == *"$k"* ]]; then
            break
        fi
    done
    echo "$k"
    CHOICE="$k"
}

# Removes double quotes, matching single quotes (drag and drop) and outer spaces.
clean_input() {
    local s="$1"
    s="${s//\"/}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    case "$s" in
        \'*\') s="${s#\'}"; s="${s%\'}" ;;
    esac
    printf '%s' "$s"
}

# If the file is not in the current folder, try beside this script.
resolve_file() {
    local f="$1"
    if [ ! -f "$f" ] && [ -f "$SCRIPT_DIR/$f" ]; then
        f="$SCRIPT_DIR/$f"
    fi
    printf '%s' "$f"
}

detect_adb() {
    ADB_FOUND=""
    ADB_UNAUTH=""
    ADB_OFFLINE=""
    local a b rest
    while read -r a b rest; do
        case "$(printf '%s' "$b" | tr '[:upper:]' '[:lower:]')" in
            device) ADB_FOUND=1 ;;
            unauthorized) ADB_UNAUTH=1 ;;
            offline) ADB_OFFLINE=1 ;;
        esac
    done < <("$ADB" devices 2>/dev/null)
}

detect_sideload() {
    SIDELOAD_FOUND=""
    SIDELOAD_SERIAL=""
    local a b rest
    while read -r a b rest; do
        if [ "$(printf '%s' "$b" | tr '[:upper:]' '[:lower:]')" = "sideload" ]; then
            SIDELOAD_FOUND=1
            SIDELOAD_SERIAL="$a"
        fi
    done < <("$ADB" devices 2>/dev/null)
}

detect_fastboot() {
    FB_FOUND=""
    FB_SERIAL=""
    local a b rest
    while read -r a b rest; do
        if [ -n "$a" ]; then
            FB_FOUND=1
            FB_SERIAL="$a"
        fi
    done < <("$FASTBOOT" devices 2>/dev/null)
}

# sideload_flow RETRY_STATE "Detected label"
# Asks for a file, sideloads it, and sets STATE.
sideload_flow() {
    local retry="$1" label="$2" input f rc

    echo
    echo "$label: $SIDELOAD_SERIAL"
    echo

    printf 'Enter filename and extension to sideload: '
    IFS= read -r input || exit 1
    f="$(clean_input "$input")"

    if [ -z "$f" ]; then
        echo
        echo "No filename entered."
        pause_any
        STATE="$retry"
        return
    fi

    f="$(resolve_file "$f")"
    if [ ! -f "$f" ]; then
        echo
        echo "ERROR: File not found: $f"
        echo "Put it in the current folder or beside this script, or enter the full path."
        pause_any
        STATE="$retry"
        return
    fi

    echo
    echo "$LINE"
    echo "Starting ADB sideload..."
    echo "$LINE"
    echo

    "$ADB" sideload "$f"
    rc=$?

    echo

    if [ "$rc" -ne 0 ]; then
        echo "$LINE"
        echo "ADB sideload reported an error. Error code: $rc"
        echo "$LINE"
        echo
        choice_key RN "Press R to retry sideload or N to continue: "
        if [ "$CHOICE" = "N" ]; then
            STATE=POST_SIDELOAD
        else
            STATE="$retry"
        fi
        return
    fi

    echo
    echo "$LINE"
    echo "ADB sideload completed."
    echo "$LINE"
    echo

    STATE=POST_SIDELOAD
}

# ============================================================
# START / MAIN MENU
# ============================================================

state_START() {
    local k rest
    clear
    echo
    echo "Welcome to Nate the Great's flashing tool"
    echo
    echo "Press ENTER to start the tool or press ESC to exit the tool"
    echo

    IFS= read -rsn1 k || exit 1
    if [ "$k" = $'\e' ]; then
        # An arrow key or similar sends more bytes after ESC: ignore those.
        if IFS= read -rsn2 -t "$ESC_WAIT" rest; then
            STATE=START
        else
            STATE=EXIT
        fi
        return
    fi
    if [ -z "$k" ]; then
        STATE=MODE_MENU
    else
        STATE=START
    fi
}

state_MODE_MENU() {
    clear
    echo
    echo "Welcome to Nate the Great's flashing tool"
    echo
    echo "If your device is in ADB mode press 1"
    echo "If your device is in ADB Sideload mode press 2"
    echo "If your device is in Bootloader (Fastboot) mode press 3"
    echo
    choice_key 123 "Select an option: "

    case "$CHOICE" in
        3) STATE=FASTBOOT_INITIAL ;;
        2) STATE=DIRECT_SIDELOAD ;;
        1) STATE=ADB_MODE ;;
    esac
}

# ============================================================
# ADB MODE
# ============================================================

state_ADB_MODE() {
    clear
    echo
    echo "Checking for ADB device..."
    echo

    while true; do
        detect_adb

        if [ -n "$ADB_FOUND" ]; then
            STATE=ADB_DETECTED
            return
        fi

        if [ -n "$ADB_UNAUTH" ]; then
            echo "Device found but UNAUTHORIZED. Unlock the phone and accept the USB debugging prompt."
            echo
        fi
        if [ -n "$ADB_OFFLINE" ]; then
            echo "Device found but OFFLINE. Try replugging the cable or toggling USB debugging."
            echo
        fi
        if "$ADB" devices 2>/dev/null | grep -qi "no permissions"; then
            echo "Device found but no USB permissions. Install the Android udev rules or run this script with sudo."
            echo
        fi
        echo "ADB Device not found.....Press Y to retry or N to return to the main menu."
        echo
        choice_key YN "Select: "

        if [ "$CHOICE" = "N" ]; then
            STATE=MODE_MENU
            return
        fi
    done
}

state_ADB_DETECTED() {
    echo
    echo "ADB device detected."
    echo
    echo "Rebooting to bootloader mode in 5 seconds..... (PLEASE DO NOT UNPLUG YOUR DEVICE)"
    sleep 5

    if ! "$ADB" reboot bootloader; then
        echo
        echo "Failed to send reboot command."
        pause_any
        STATE=MODE_MENU
        return
    fi

    echo
    echo "Waiting for Fastboot device..."
    sleep 3
    STATE=FASTBOOT_INITIAL
}

# ============================================================
# DIRECT ADB SIDELOAD MODE
# ============================================================

state_DIRECT_SIDELOAD() {
    clear
    echo
    echo "Checking for ADB Sideload device..."
    echo

    while true; do
        detect_sideload
        if [ -n "$SIDELOAD_FOUND" ]; then
            break
        fi

        echo "ADB Sideload device not found.....Press Y to retry or N to return to the main menu."
        echo
        choice_key YN "Select: "
        if [ "$CHOICE" = "N" ]; then
            STATE=MODE_MENU
            return
        fi
    done

    sideload_flow DIRECT_SIDELOAD "ADB Sideload device detected"
}

# ============================================================
# INITIAL FASTBOOT FLASH
# ============================================================

state_FASTBOOT_INITIAL() {
    clear
    echo
    echo "Checking required initial images..."
    echo

    BOOT_IMAGE="boot.img"
    VENDOR_BOOT_IMAGE="vendor_boot.img"
    INIT_BOOT_IMAGE="init_boot.img"

    BOOT_IMAGE="$(resolve_file "$BOOT_IMAGE")"
    VENDOR_BOOT_IMAGE="$(resolve_file "$VENDOR_BOOT_IMAGE")"
    INIT_BOOT_IMAGE="$(resolve_file "$INIT_BOOT_IMAGE")"

    if [ ! -f "$BOOT_IMAGE" ]; then
        echo "ERROR: boot.img was not found."
        echo "Put boot.img in the current folder or beside this script."
        pause_any
        STATE=MODE_MENU
        return
    fi

    if [ ! -f "$VENDOR_BOOT_IMAGE" ]; then
        echo "ERROR: vendor_boot.img was not found."
        echo "Put vendor_boot.img in the current folder or beside this script."
        pause_any
        STATE=MODE_MENU
        return
    fi

    if [ ! -f "$INIT_BOOT_IMAGE" ]; then
        echo "ERROR: init_boot.img was not found."
        echo "Put init_boot.img in the current folder or beside this script."
        pause_any
        STATE=MODE_MENU
        return
    fi

    echo "Required initial images found."
    echo
    echo "Checking for Fastboot device..."
    echo

    while true; do
        detect_fastboot
        if [ -n "$FB_FOUND" ]; then
            break
        fi

        echo "Fastboot device not found.....Press Y to retry or N to return to the main menu."
        echo "If the device is connected, check your udev rules or try running this script with sudo."
        echo
        choice_key YN "Select: "
        if [ "$CHOICE" = "N" ]; then
            STATE=MODE_MENU
            return
        fi
    done

    echo
    echo "Fastboot device detected: $FB_SERIAL"
    echo
    echo "This will flash boot_ab, vendor_boot_ab and init_boot_ab using the images found above."
    echo "Do NOT unplug the device or close this window until it finishes."
    echo
    choice_key YN "Continue? Press Y to flash or N to return to the main menu: "
    if [ "$CHOICE" = "N" ]; then
        STATE=MODE_MENU
        return
    fi
    echo

    FLASH_STEP=""
    FLASH_PROGRESS="none"

    echo "$LINE"
    echo "Flashing boot_ab..."
    echo "$LINE"
    FLASH_STEP="boot_ab"
    "$FASTBOOT" flash boot_ab "$BOOT_IMAGE" || { STATE=FLASH_ERROR; return; }
    FLASH_PROGRESS="boot_ab"

    echo
    echo "$LINE"
    echo "Flashing vendor_boot_ab..."
    echo "$LINE"
    FLASH_STEP="vendor_boot_ab"
    "$FASTBOOT" flash vendor_boot_ab "$VENDOR_BOOT_IMAGE" || { STATE=FLASH_ERROR; return; }
    FLASH_PROGRESS="boot_ab, vendor_boot_ab"

    echo
    echo "$LINE"
    echo "Flashing init_boot_ab..."
    echo "$LINE"
    FLASH_STEP="init_boot_ab"
    "$FASTBOOT" flash init_boot_ab "$INIT_BOOT_IMAGE" || { STATE=FLASH_ERROR; return; }
    FLASH_PROGRESS="boot_ab, vendor_boot_ab, init_boot_ab"

    echo
    echo "$LINE"
    echo "All initial images flashed successfully."
    echo "Rebooting to recovery..."
    echo "$LINE"

    FLASH_STEP="reboot to recovery"
    "$FASTBOOT" reboot recovery || { STATE=FLASH_ERROR; return; }

    sleep 3
    STATE=SIDELOAD_WAIT
}

state_SIDELOAD_WAIT() {
    clear
    echo
    echo "Please Select 'Apply Update from ADB' in recovery menu & press ENTER"
    echo

    pause_silent

    echo
    echo "Waiting for ADB sideload device..."
    echo

    while true; do
        detect_sideload
        if [ -n "$SIDELOAD_FOUND" ]; then
            break
        fi

        echo "ADB Sideload device not found.....Press Y to retry or N to return to the previous menu."
        echo
        choice_key YN "Select: "
        if [ "$CHOICE" = "N" ]; then
            STATE=POST_SIDELOAD
            return
        fi
    done

    sideload_flow SIDELOAD_WAIT "Sideload device detected"
}

# ============================================================
# POST SIDELOAD MENU
# ============================================================

state_POST_SIDELOAD() {
    echo "Press 1 to install additional images from Fastboot"
    echo "Press 2 to reboot to system and exit"
    echo "Press 3 to exit without rebooting"
    echo

    choice_key 123 "Select an option: "

    case "$CHOICE" in
        3) STATE=EXIT ;;
        2) STATE=REBOOT_FROM_RECOVERY ;;
        1) STATE=ADDITIONAL_FASTBOOT ;;
    esac
}

# ============================================================
# ADDITIONAL FASTBOOT
# ============================================================

state_ADDITIONAL_FASTBOOT() {
    clear
    echo
    echo "Please reboot to bootloader and press ENTER"
    echo

    pause_silent

    echo
    echo "Checking for Fastboot device..."
    echo

    while true; do
        detect_fastboot
        if [ -n "$FB_FOUND" ]; then
            break
        fi

        echo "Fastboot device not found.....Press Y to retry or N to return to the previous menu."
        echo "If the device is connected, check your udev rules or try running this script with sudo."
        echo
        choice_key YN "Select: "
        if [ "$CHOICE" = "N" ]; then
            STATE=POST_SIDELOAD
            return
        fi
    done

    echo
    echo "Fastboot device detected: $FB_SERIAL"
    echo

    echo "Press 1 to Flash KernelSU/KernelSU Next/SukiSU modified images"
    echo "Press 2 to Flash APatch modified images"
    echo "Press 3 to flash any other file (manual command)"
    echo

    choice_key 123 "Select an option: "

    case "$CHOICE" in
        3) STATE=MANUAL_FASTBOOT ;;
        2) STATE=APATCH ;;
        1) STATE=KERNELSU ;;
    esac
}

# ============================================================
# KERNELSU / KERNELSU NEXT / SUKISU
# ============================================================

state_KERNELSU() {
    local input f
    clear
    echo
    echo "Flash KernelSU/KernelSU Next/SukiSU modified image"
    echo

    printf 'Enter filename and extension: '
    IFS= read -r input || exit 1
    f="$(clean_input "$input")"

    if [ -z "$f" ]; then
        echo
        echo "No filename entered."
        pause_any
        STATE=KERNELSU
        return
    fi

    f="$(resolve_file "$f")"
    if [ ! -f "$f" ]; then
        echo
        echo "ERROR: File not found: $f"
        echo "Put it in the current folder or beside this script, or enter the full path."
        pause_any
        STATE=KERNELSU
        return
    fi

    echo
    echo "$LINE"
    echo "Flashing init_boot_ab..."
    echo "$LINE"
    FLASH_STEP="init_boot_ab"
    FLASH_PROGRESS="none"
    "$FASTBOOT" flash init_boot_ab "$f" || { STATE=FLASH_ERROR; return; }
    FLASH_PROGRESS="init_boot_ab"

    echo
    echo "KernelSU/KernelSU Next/SukiSU image flashed successfully."
    echo

    echo "Press 1 to flash any other file (manual command)"
    echo "Press 2 to reboot to recovery"
    echo "Press 3 to reboot to system"
    echo

    choice_key 123 "Select an option: "

    case "$CHOICE" in
        3) STATE=REBOOT_SYSTEM ;;
        2) STATE=REBOOT_RECOVERY ;;
        1) STATE=MANUAL_FASTBOOT ;;
    esac
}

# ============================================================
# APATCH
# ============================================================

state_APATCH() {
    local input f
    clear
    echo
    echo "Flash APatch modified image"
    echo

    printf 'Enter filename and extension: '
    IFS= read -r input || exit 1
    f="$(clean_input "$input")"

    if [ -z "$f" ]; then
        echo
        echo "No filename entered."
        pause_any
        STATE=APATCH
        return
    fi

    f="$(resolve_file "$f")"
    if [ ! -f "$f" ]; then
        echo
        echo "ERROR: File not found: $f"
        echo "Put it in the current folder or beside this script, or enter the full path."
        pause_any
        STATE=APATCH
        return
    fi

    echo
    echo "$LINE"
    echo "Flashing boot_ab..."
    echo "$LINE"
    FLASH_STEP="boot_ab"
    FLASH_PROGRESS="none"
    "$FASTBOOT" flash boot_ab "$f" || { STATE=FLASH_ERROR; return; }
    FLASH_PROGRESS="boot_ab"

    echo
    echo "APatch image flashed successfully."
    echo

    echo "Press 1 to flash any other file (manual command)"
    echo "Press 2 to reboot to recovery"
    echo "Press 3 to reboot to system"
    echo

    choice_key 123 "Select an option: "

    case "$CHOICE" in
        3) STATE=REBOOT_SYSTEM ;;
        2) STATE=REBOOT_RECOVERY ;;
        1) STATE=MANUAL_FASTBOOT ;;
    esac
}

# ============================================================
# MANUAL FASTBOOT COMMAND
# ============================================================

state_MANUAL_FASTBOOT() {
    local cmd rc
    clear
    echo
    echo "Enter your own commands:"
    echo
    echo "Example:"
    echo "fastboot flash vendor_boot vendor_boot_custom.img"
    echo
    echo "You can enter any valid fastboot command."
    echo

    printf '> '
    IFS= read -r cmd || exit 1

    if [ -z "$cmd" ]; then
        echo
        echo "No command entered."
        pause_any
        STATE=MANUAL_FASTBOOT
        return
    fi

    echo
    echo "$LINE"
    echo "Running command:"
    echo "$cmd"
    echo "$LINE"
    echo

    bash -c "$cmd"
    rc=$?

    echo

    if [ "$rc" -ne 0 ]; then
        echo "Command returned error code: $rc"
    else
        echo "Command completed successfully."
    fi

    echo
    echo "Press 1 to flash another file from Fastboot"
    echo "Press 2 to reboot to recovery"
    echo "Press 3 to reboot to system"
    echo

    choice_key 123 "Select an option: "

    case "$CHOICE" in
        3) STATE=REBOOT_SYSTEM ;;
        2) STATE=REBOOT_RECOVERY ;;
        1) STATE=MANUAL_FASTBOOT ;;
    esac
}

# ============================================================
# REBOOT OPTIONS
# ============================================================

state_REBOOT_RECOVERY() {
    clear
    echo
    echo "Rebooting to recovery..."
    echo

    if ! "$FASTBOOT" reboot recovery; then
        STATE=REBOOT_ERROR
        return
    fi

    echo
    echo "Done."
    sleep 3
    STATE=EXIT
}

state_REBOOT_SYSTEM() {
    clear
    echo
    echo "Rebooting to system..."
    echo

    if ! "$FASTBOOT" reboot; then
        STATE=REBOOT_ERROR
        return
    fi

    echo
    echo "Done."
    sleep 3
    STATE=EXIT
}

# After sideload the phone is in recovery (ADB), not Fastboot,
# so this uses adb instead of fastboot.
state_REBOOT_FROM_RECOVERY() {
    clear
    echo
    echo "Rebooting to system..."
    echo

    if ! "$ADB" reboot; then
        echo
        echo "ADB reboot failed. Reboot manually from the recovery menu."
        pause_any
        STATE=POST_SIDELOAD
        return
    fi

    echo
    echo "Done."
    sleep 3
    STATE=EXIT
}

# ============================================================
# ERRORS
# ============================================================

state_FLASH_ERROR() {
    echo
    echo "$LINE"
    echo "ERROR: A Fastboot command failed."
    if [ -n "$FLASH_STEP" ]; then echo "Failed step: $FLASH_STEP"; fi
    if [ -n "$FLASH_PROGRESS" ]; then echo "Completed before the failure: $FLASH_PROGRESS"; fi
    echo "$LINE"
    echo
    echo "Checking whether the device is still connected..."
    echo

    detect_fastboot

    if [ -n "$FB_FOUND" ]; then
        echo "Device is still in Fastboot: $FB_SERIAL"
        echo "Check the error output above, then choose option 3 from the main menu to try again."
    else
        echo "The device is NO LONGER detected in Fastboot."
        echo "It may have been unplugged, lost connection, or rebooted."
        echo "Do not assume the flash finished. Some images may be flashed and others not."
        echo "Check the cable and USB port, put the device back into Bootloader mode,"
        echo "then run this tool again and choose option 3."
    fi
    echo
    pause_any
    STATE=MODE_MENU
}

state_REBOOT_ERROR() {
    echo
    echo "$LINE"
    echo "ERROR: Reboot command failed."
    echo "Please check the output above."
    echo "Returning to the main menu..."
    echo "$LINE"
    echo
    pause_any
    STATE=MODE_MENU
}

# ============================================================
# EXIT
# ============================================================

state_EXIT() {
    echo
    echo "Exiting Tool................"
    echo
    sleep 2
    exit 0
}

# ============================================================
# MAIN LOOP
# ============================================================

for tool in "$ADB" "$FASTBOOT"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: '$tool' was not found."
        echo "Install Android platform-tools, or put adb and fastboot beside this script."
        exit 1
    fi
done

FLASH_STEP=""
FLASH_PROGRESS=""
STATE=START
while true; do
    "state_$STATE"
done
