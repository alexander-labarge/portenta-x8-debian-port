# Portenta X8 Debian arm64 Port

> **Turnkey Debian 12 (Bookworm) for Arduino Portenta X8**
> SystemReady‑ES–compliant U‑Boot patches, reproducible build scripts, and a microSD‑loader that installs a full APT‑enabled OS onto the on‑board eMMC.

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-24292e?style=for-the-badge&logo=opensourceinitiative&logoColor=white" alt="MIT License"/>
  <img src="https://img.shields.io/badge/arm64-supported-24292e?style=for-the-badge&logo=linux&logoColor=white" alt="ARM64 Supported"/>
  <img src="https://img.shields.io/badge/status-alpha-24292e?style=for-the-badge&logo=github" alt="Project status"/>
</p>

## About

This repository provides everything required to replace the Portenta X8’s Yocto factory image with a first‑class Debian 12 Bookworm environment:

* **U‑Boot + UEFI patch set** enabling `grubaa64.efi` boot on SystemReady‑ES hardware.
* **Container‑friendly build scripts** that cross‑compile on x86‑64 and emit reproducible binaries.
* **One‑step installer** that flashes the patched bootloader and lays down a clean Debian rootfs on the X8’s 16 GB eMMC.

---

**Author:** Alexander La Barge
**Contact:** [alex@labarge.dev](mailto:alex@labarge.dev)
**Date:** 11 June 2025
**License:** MIT
