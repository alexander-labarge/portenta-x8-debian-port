# Portenta X8 Debian arm64 Port

> **Turnkey Debian 12 (Bookworm) for Arduino Portenta X8**  
> SystemReady-ES–compliant U-Boot patches, reproducible build scripts, and a microSD-loader that installs a full APT-enabled OS onto the on-board eMMC.

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-24292e?style=for-the-badge&logo=opensourceinitiative&logoColor=white" alt="MIT License"/>
  <img src="https://img.shields.io/badge/arm64-supported-24292e?style=for-the-badge&logo=linux&logoColor=white" alt="ARM64 Supported"/>
  <img src="https://img.shields.io/badge/status-alpha-24292e?style=for-the-badge&logo=github" alt="Project status"/>
</p>

## About

This repository provides everything required to replace the Portenta X8’s Yocto factory image with a first-class Debian 12 Bookworm environment:

- **U-Boot + UEFI patch set** enabling `grubaa64.efi` boot on SystemReady-ES hardware.  
- **Container-friendly build scripts** that cross-compile on x86-64 and emit reproducible binaries.  
- **One-step installer** that flashes the patched bootloader and lays down a clean Debian rootfs on the X8’s 16 GB eMMC.

---

**Author:** Alexander La Barge  
**Contact:** [alex@labarge.dev](mailto:alex@labarge.dev)  
**Date:** 11 June 2025  
**License:** MIT

---

## Static ARM64 Binaries Subproject

> **Fully static MediaMTX & FFmpeg Arm64 builds and deployment for Arduino Portenta X8**  
> Reproducible, container-friendly build scripts and an automated deployment tool.

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-24292e?style=for-the-badge&logo=opensourceinitiative&logoColor=white" alt="MIT License"/>
  <img src="https://img.shields.io/badge/ubuntu-24.04-orange?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/arm64-supported-24292e?style=for-the-badge&logo=linux&logoColor=white" alt="ARM64 Supported"/>
</p>

### Overview

This **subproject** provides:

- `build_mediamtx_arm64_static.sh`: Builds a fully static ARM64 MediaMTX binary on Ubuntu 24.04 x86-64.  
- `build_ffmpeg_arm64_static.sh`: Builds a fully static ARM64 FFmpeg binary (with x265 support).  
- `deploy_static_binaries.sh`: Securely copies and installs those binaries onto a Portenta X8 running the default Yocto image.  

All scripts enforce host-sanity checks, use cross-compilation toolchains (including musl for static libc), and strip binaries for minimal footprint.

### Repository Layout

```bash
# In the `cross_compile_builders_amd64_for_arm64` directory:
.
├── build_mediamtx_arm64_static.sh       # Static build script for MediaMTX
├── build_ffmpeg_arm64_static.sh         # Static build script for FFmpeg + x265
├── deploy_static_binaries.sh            # SSH-based deployer to Portenta X8
├── ffmpeg-arm64-static
│   ├── bin
│   │   └── ffmpeg
│   ├── include
│   │   ├── x265_config.h
│   │   └── x265.h
│   └── lib
│       ├── libx265.a
│       └── pkgconfig
│           └── x265.pc
└── mediamtx-arm64-static
    └── bin
        └── mediamtx

8 directories, 9 files

````

### Prerequisites

* **Host OS:** Ubuntu 24.04 (tested)
* **Required Packages (Automatically Installed):**

  * `build-essential`, `git`, `wget`, `curl`, `ca-certificates`, `xz-utils`
  * `crossbuild-essential-arm64`, `qemu-user-static`
  * `pkg-config`, `yasm`, `nasm`, `cmake`, `ninja-build`, etc. (see each script)
* **SSH Deployment:** `sshpass` (installable via `apt`)

### Usage

1. **Build MediaMTX**

   ```bash
   chmod +x build_mediamtx_arm64_static.sh
   ./build_mediamtx_arm64_static.sh
   ```

   Outputs: `mediamtx-arm64-static/bin/mediamtx`

2. **Build FFmpeg**

   ```bash
   chmod +x build_ffmpeg_arm64_static.sh
   ./build_ffmpeg_arm64_static.sh
   ```

   Outputs: `ffmpeg-arm64-static/bin/ffmpeg`

3. **Deploy to Portenta X8**

   * Edit `deploy_static_binaries.sh` and set:

     ```bash
     REMOTE="fio@10.0.0.2"   # SSH user@host of your device
     PASS="fio"             # SSH password (or use key-based auth)
     ```
   * Run:

     ```bash
     chmod +x deploy_static_binaries.sh
     ./deploy_static_binaries.sh
     ```

### Configuration

* **Deployment targets:**

  * `REMOTE` – SSH user and address of the Portenta X8
  * `PASS` – Password for `sshpass` (or switch to key-based authentication)
* **Binary Paths:**

  * Update `MEDIAMTX_BIN` and `FFMPEG_BIN` in `deploy_static_binaries.sh` to match your build outputs.

### License

MIT © Alexander La Barge
(Contact: [alex@labarge.dev](mailto:alex@labarge.dev))
Date: 11 June 2025

```
```
