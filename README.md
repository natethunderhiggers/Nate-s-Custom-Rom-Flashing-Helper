# Nate the Great's Android Flashing Tool

A simple Windows/macOS/Linux flashing tool for Android custom ROM installation.

Nate the Great's Flashing Tool provides an interactive command-line interface for common Android custom ROM flashing tasks using **ADB** and **Fastboot**.

It is designed to make the flashing process easier by guiding the user through device detection, boot image flashing, recovery sideloading, additional Fastboot images, KernelSU/APatch images, and reboot options.

---

## Features

- Cross-platform support:
  - Windows
  - Linux
  - macOS
- ADB device detection
- ADB authorization/offline detection
- ADB → Bootloader/Fastboot reboot
- Direct ADB Sideload mode
- Fastboot device detection
- Automatic flashing of:
  - `boot_ab`
  - `vendor_boot_ab`
  - `init_boot_ab`
- Automatic reboot to recovery after the initial Fastboot flash
- Interactive ADB sideloading
- Sideload retry handling
- Additional Fastboot flashing
- KernelSU support
- KernelSU Next support
- SukiSU support
- APatch support
- Manual Fastboot command mode
- Reboot to recovery
- Reboot to system
- File existence checks
- Fastboot failure reporting
- Reports which flashing step failed
- Reports which flashing steps completed before a failure
- Portable `adb` and `fastboot` support

---

## Repository Structure

```text
Nates-Custom-ROM-Flashing-Helper/
│
├── Windows/
│   └── flash_helper.bat
│
├── Linux/
│   └── flash_helper_linux.sh
│
├── macOS/
│   └── flash_helper_macos.command
│
└── README.md
```

---

# Requirements

The tool requires Android **ADB and Fastboot platform-tools**.

You can either:

1. Install `adb` and `fastboot` on your system and make them available through `PATH`, or
2. Place the required executables beside the flashing script.

You will also need the appropriate USB drivers or permissions for your operating system and Android device.

---

# Windows

## Requirements

Windows requires:

- `adb.exe`
- `fastboot.exe`

Place them in your system `PATH`, or place them in the same directory as the flashing tool.

You will also need the appropriate USB drivers for your Android device.

---

## Starting the Tool

Run:

```text
Windows/flash_helper.bat
```

The tool will display:

```text
Welcome to Nate the Great's flashing tool

Press ENTER to start the tool or press ESC to exit the tool
```

Press:

- **ENTER** → Start
- **ESC** → Exit

---

# Linux

## Installing ADB and Fastboot

### Debian / Ubuntu

```bash
sudo apt install adb fastboot
```

### Fedora

```bash
sudo dnf install android-tools
```

### Arch Linux

```bash
sudo pacman -S android-tools
```

If the device is not detected, install the appropriate Android **udev rules** or run the script with appropriate privileges.

---

## Running the Tool

Make the script executable:

```bash
chmod +x flash_helper_linux.sh
```

Then run:

```bash
./flash_helper_linux.sh
```

The script can use `adb` and `fastboot` from the system `PATH`, or executables placed beside the script.

---

# macOS

The macOS version is provided as:

```text
macOS/flash_helper_macos.command
```

You will need Android platform-tools containing:

```text
adb
fastboot
```

The script can use platform-tools installed on the system or executables located beside the script.

If macOS prevents the script from opening because of its security/quarantine mechanism, allow the file to run through macOS security settings or remove the quarantine attribute as appropriate for your system.

---

# Main Menu

After starting the tool, you will see three main options:

```text
If your device is in ADB mode press 1
If your device is in ADB Sideload mode press 2
If your device is in Bootloader (Fastboot) mode press 3
```

---

# 1. ADB Mode

Choose **1** when Android is booted normally and USB debugging is enabled.

The tool checks for an ADB device.

If the device is found, it waits five seconds and then sends:

```bash
adb reboot bootloader
```

The tool then continues into the Fastboot flashing process.

If the device is not detected, you can:

```text
Press Y to retry
Press N to return to the main menu
```

The tool also distinguishes between:

- `device`
- `unauthorized`
- `offline`

ADB states.

---

# 2. ADB Sideload Mode

Choose **2** if the phone is already in Android Recovery's:

```text
Apply Update from ADB
```

mode.

The tool checks for an ADB sideload device.

Once detected, it asks:

```text
Enter filename and extension to sideload:
```

You can enter either:

```text
ROM.zip
```

or a full path such as:

```text
C:\Users\YourName\Downloads\ROM.zip
```

The tool also handles quoted paths.

For example:

```text
"C:\Users\YourName\Downloads\ROM.zip"
```

The tool validates that the file exists before attempting the sideload.

It then runs:

```bash
adb sideload <file>
```

If the sideload fails, you can retry it or continue to the next menu.

---

# 3. Bootloader / Fastboot Mode

Choose **3** when the device is already in Bootloader/Fastboot mode.

The tool checks for the Fastboot device before proceeding.

You will then be asked to confirm the flashing operation.

The initial flashing process uses:

```text
boot.img
vendor_boot.img
init_boot.img
```

and flashes them to:

```text
boot_ab
vendor_boot_ab
init_boot_ab
```

The tool verifies that all three required images exist before attempting to flash them.

---

# Initial Flashing Process

The initial Fastboot process is:

```text
boot.img
    ↓
boot_ab

vendor_boot.img
    ↓
vendor_boot_ab

init_boot.img
    ↓
init_boot_ab

    ↓
Reboot to Recovery

    ↓
ADB Sideload
```

The tool warns the user not to disconnect the device during the flashing process.

It also tracks the current flashing step so that a Fastboot failure can report what happened.

For example:

```text
ERROR: A Fastboot command failed.

Failed step: vendor_boot_ab
Completed before the failure: boot_ab
```

This helps determine where the flashing process stopped.

---

# Recovery / ADB Sideload

After the initial Fastboot images are successfully flashed, the tool reboots the device into recovery.

The user is then instructed to select:

```text
Apply Update from ADB
```

in recovery and press ENTER.

The tool waits for the device to appear as an ADB sideload device.

Once detected, it asks for the ROM/update ZIP and runs:

```bash
adb sideload <ROM.zip>
```

---

# After Sideload

Once the sideload completes, the tool provides:

```text
Press 1 to install additional images from Fastboot
Press 2 to reboot to system and exit
Press 3 to exit without rebooting
```

---

# Additional Fastboot

Selecting additional Fastboot allows you to perform further image modifications.

The menu provides:

```text
Press 1 to Flash KernelSU/KernelSU Next/SukiSU modified images
Press 2 to Flash APatch modified images
Press 3 to flash any other file (manual command)
```

---

# KernelSU / KernelSU Next / SukiSU

Selecting option **1** asks for the modified image filename.

The selected image is flashed to:

```text
init_boot_ab
```

using:

```bash
fastboot flash init_boot_ab <image>
```

After a successful flash:

```text
Press 1 to flash any other file (manual command)
Press 2 to reboot to recovery
Press 3 to reboot to system
```

---

# APatch

Selecting option **2** asks for the APatch modified image filename.

The image is flashed to:

```text
boot_ab
```

using:

```bash
fastboot flash boot_ab <image>
```

After a successful flash:

```text
Press 1 to flash any other file (manual command)
Press 2 to reboot to recovery
Press 3 to reboot to system
```

---

# Manual Fastboot Commands

The manual Fastboot mode allows you to enter your own Fastboot command.

Example:

```bash
fastboot flash vendor_boot vendor_boot_custom.img
```

The tool executes the command and reports whether it completed successfully or returned an error code.

You can then:

```text
1 → Enter another command
2 → Reboot to recovery
3 → Reboot to system
```

---

# Reboot Options

The tool supports:

### Reboot to Recovery

```bash
fastboot reboot recovery
```

### Reboot to System

```bash
fastboot reboot
```

When the phone is still in recovery after sideloading, the tool uses ADB to reboot the device instead of attempting to use Fastboot.

---

# File Placement

For the initial flashing process, place:

```text
boot.img
vendor_boot.img
init_boot.img
```

in the same directory as the flashing tool, or provide the appropriate files where requested.

For sideloading and additional image flashing, you can provide:

- A filename
- A relative path
- A full path

---

# Example Directory

A typical setup could look like:

```text
Nates-Custom-ROM-Flashing-Helper/
│
├── Windows/
│   ├── flash_helper.bat
│   ├── adb.exe
│   ├── fastboot.exe
│   ├── boot.img
│   ├── vendor_boot.img
│   └── init_boot.img
│
├── Linux/
│   ├── flash_helper_linux.sh
│   ├── adb
│   ├── fastboot
│   ├── boot.img
│   ├── vendor_boot.img
│   └── init_boot.img
│
└── macOS/
    ├── flash_helper_macos.command
    ├── adb
    ├── fastboot
    ├── boot.img
    ├── vendor_boot.img
    └── init_boot.img
```

You do **not** have to keep the images inside the repository itself. They can be kept separately and supplied when using the tool.

---

# Troubleshooting

## Device not detected by ADB

Check:

- USB cable
- USB port
- USB debugging
- Device authorization
- ADB drivers on Windows
- udev rules on Linux

If Android displays an RSA/USB debugging authorization prompt, accept it.

---

## ADB shows `unauthorized`

Unlock the phone and accept the USB debugging authorization prompt.

Then select:

```text
Y
```

to retry.

---

## ADB shows `offline`

Try:

- Reconnecting the USB cable
- Restarting USB debugging
- Restarting ADB
- Reconnecting the device

Then retry.

---

## Fastboot device not detected

Check:

- The phone is actually in Bootloader/Fastboot mode
- USB cable
- USB port
- Windows USB drivers
- Linux udev rules
- macOS USB access

On Linux, check the appropriate udev rules or try running the script with appropriate privileges.

---

## A Fastboot flash fails

Do **not** assume that the entire operation succeeded.

The tool reports:

```text
Failed step:
Completed before the failure:
```

This tells you which command failed and which earlier steps completed.

Check the Fastboot error output before attempting another flash.

---

# Important Warning

## Flashing Android partitions can permanently damage your device if incorrect images or commands are used.

This tool executes ADB and Fastboot commands on your device.

Before flashing:

- Make sure you have the correct ROM for your device.
- Make sure the images belong to your exact device/build.
- Keep the USB connection stable.
- Do not disconnect the device while flashing.
- Do not close the tool during an active flash.
- Understand what partition you are flashing before using manual commands.
- Keep a backup of important data.

**You are responsible for the commands and files you use with this tool.**

---

# Disclaimer

This project is provided as-is.

Nate the Great's Android Flashing Tool is an independent utility and is not affiliated with:

- Google
- Android
- Any Android device manufacturer
- KernelSU
- KernelSU Next
- SukiSU
- APatch
- Any custom ROM project

The author is not responsible for data loss, bootloops, soft bricks, hard bricks, or other damage resulting from the use or misuse of this tool.

**Use at your own risk.**

---

# License

This project is licensed under the **MIT License**.

See the `LICENSE` file for details.

---

# Contributing

Suggestions, bug reports, and improvements are welcome.

If you find an issue:

1. Check the troubleshooting section.
2. Make sure `adb` and `fastboot` work independently.
3. Reproduce the issue.
4. Open a GitHub issue with:
   - Operating system
   - Device model
   - ADB/Fastboot version
   - The step where the problem occurred
   - Relevant error output

Please do not post private information, device authentication data, or personal files.
