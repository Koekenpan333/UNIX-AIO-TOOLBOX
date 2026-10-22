# UNIX AIO Toolbox

A lightweight, menu-driven shell toolkit for macOS and Linux. It detects the operating system, identifies common Linux distributions and versions, shows system information, and provides an application catalog with package-manager installation.

## Features

- Detects macOS and Linux.
- Reports OS version, architecture, kernel, hostname, and basic hardware details.
- Identifies common Linux distributions from `/etc/os-release`, including Ubuntu, Debian, Linux Mint, Pop!_OS, Fedora, Arch Linux, Manjaro, EndeavourOS, openSUSE, and Alpine.
- Checks available package managers: Homebrew, APT, DNF, YUM, Pacman, Zypper, APK, and Flatpak.
- Provides an application catalog for macOS and Linux.
- Installs catalog apps using Homebrew on macOS and a detected package manager on Linux.
- Asks for confirmation before installing applications.
- Does not automatically run `sudo`; Linux package managers may request administrator privileges themselves.
- Uses shell scripts only; Python and Node.js are not required.

## Requirements

- macOS or Linux.
- Bash.
- Internet access to install applications.
- On macOS, Homebrew is required for catalog installations.

## Installation

### Option 1: Download the ZIP

1. Download and extract the repository ZIP from GitHub.
2. Open Terminal and navigate to the extracted directory.
3. Run:

   ```sh
   chmod +x aio-toolkit.sh
   ./aio-toolkit.sh
   ```

### Option 2: Clone the repository

```sh
git clone https://github.com/Koekenpan333/UNIX-AIO-TOOLBOX.git
cd UNIX-AIO-TOOLBOX
chmod +x aio-toolkit.sh
./aio-toolkit.sh
```

## Homebrew on macOS

Homebrew is required to install applications from the catalog on macOS. If Homebrew is not detected, the toolkit displays a message and offers to open the official Homebrew website. It does not silently install Homebrew or run a remote installation script.

Official installation instructions: https://brew.sh/

After installing Homebrew, reopen Terminal if necessary and run the toolkit again.

## Application catalog

The application catalog is stored in `catalog/apps.tsv`. Each row contains four tab-separated fields:

```text
platform<TAB>package<TAB>display-name<TAB>description
```

Supported platform values are `macos`, `linux`, and `both`. Package names are passed to the detected package manager. Entries beginning with `flatpak:` use Flatpak and the specified Flatpak application ID.

To add an application, edit `catalog/apps.tsv` and add a row. Review package names and catalog changes before running the toolkit.

## Safety notes

- Review catalog entries before installing applications.
- Installing software changes your system and may require administrator approval.
- The toolkit does not execute arbitrary shell commands from catalog entries.
- Linux package names and availability vary by distribution. An installation may fail if a package is unavailable under the listed name.
- Flatpak must be installed and configured before Flatpak catalog entries can be installed.
- Use this project at your own risk and test it on a non-critical system first.

## License

This project is licensed under the MIT License. See `LICENSE`.
