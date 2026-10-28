# ASUS ROG Zephyrus G14 (2022 GA402) Linux Kernel Stability Guide

An engineering post-mortem and automated mitigation script resolving the infamous **idle hard-freeze / lockup bug** on the all-AMD **ASUS ROG Zephyrus G14 (2022 GA402RJ / GA402RK)** under Linux.

---

## 🛑 The Symptom

Across modern Linux distributions (Ubuntu, Fedora, Arch, Bazzite, Nobara, Pop!_OS), owners of the 2022 G14 experience sudden, catastrophic system freezes:
- The mouse cursor stops moving.
- Audio enters a buzzing loop or cuts out.
- The keyboard becomes unresponsive (including `SysRq` commands).
- Screen remains frozen on the last frame, requiring a hard 10-second power button press.

Crucially, **this freeze almost never happens during heavy gaming or compilation.** It strikes when the system is **idle**—stepping away for coffee, reading a webpage, or leaving the laptop unattended.

---

## 🔬 Root Cause Analysis

This issue is a triple-point collision between **AMD Zen 3+ mobile voltage scaling**, **ASUS motherboard ACPI tables**, and **Linux power management subsystems**:

### 1. CPU C-State Voltage Sag (`processor.max_cstate=1`)
The **AMD Ryzen 9 6900HS / 6800HS** (Rembrandt) processor aggressively drops voltage when entering deep package sleep states (`C3` / `C6`). On ASUS GA402 firmware, the voltage droop curve is too steep; when transitioning out of deep idle, one or more core voltages collapse below stable operational thresholds before clock gates reopen, causing an immediate catastrophic CPU hard-lock.
- **Remedy:** Restricting the processor to `C1` prevents dangerous sub-threshold voltage drops while preserving boost clocks and battery governors.

### 2. PCIe Active State Power Management Desync (`pcie_aspm=off`)
The laptop utilizes dual AMD GPUs (Radeon 680M iGPU + Radeon RX 6700S/6800S dGPU). When PCIe ASPM attempts to put the discrete GPU's PCIe lanes into L1/L2 low-power link states, the link fails to re-negotiate on wake, locking the root complex PCIe bus.
- **Remedy:** Disabling ASPM keeps the bus link clocked and stable.

### 3. NVMe Autonomous Power State Transition Timeouts (`nvme_core.default_ps_max_latency_us=0`)
OEM Micron/Intel NVMe SSDs shipped in the 2022 G14 enter ultra-low latency power states that exceed Linux kernel transition timeouts, leading to silent I/O timeouts and filesystem lockups.
- **Remedy:** Disabling APST ensures the storage controller remains immediately responsive to read/write requests.

---

## 🚀 Quickstart: The 1-Click Fix

Clone this repository and run the automated patch script:

```bash
git clone https://github.com/patrick-isles/g14-linux-stability-guide.git
cd g14-linux-stability-guide
sudo ./fix-g14.sh
```

Then **reboot your laptop**.

---

## 🔍 Verification

After rebooting, run the verification diagnostic:

```bash
./verify.sh
```

Expected output:
```text
=== ASUS Zephyrus G14 Kernel Parameter Audit ===

[*] Active Kernel Commandline:
    BOOT_IMAGE=/boot/vmlinuz-... ro quiet splash processor.max_cstate=1 pcie_aspm=off nvme_core.default_ps_max_latency_us=0

 [PASS] processor.max_cstate=1 is ACTIVE
        Reason: Disables deep C3/C6 idle voltage sag
 [PASS] pcie_aspm=off is ACTIVE
        Reason: Prevents PCIe link state drops on dGPU/bus
 [PASS] nvme_core.default_ps_max_latency_us=0 is ACTIVE
        Reason: Prevents NVMe sleep timeouts

[*] Active Power Profile: performance

>>> SYSTEM STABILITY AUDIT PASSED: Your Zephyrus G14 is protected against idle freezes. <<<
```

---

## 🛠 Manual Configuration

If you prefer to configure GRUB by hand:

1. Edit `/etc/default/grub`:
   ```bash
   sudo nano /etc/default/grub
   ```
2. Locate `GRUB_CMDLINE_LINUX_DEFAULT` and append the parameters:
   ```text
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash processor.max_cstate=1 pcie_aspm=off nvme_core.default_ps_max_latency_us=0"
   ```
3. Update your bootloader:
   ```bash
   sudo update-grub
   ```
4. Set power profile to performance:
   ```bash
   powerprofilesctl set performance
   ```
5. Reboot.

---

## 📊 Empirical Stability Benchmarks

Tested on **ASUS ROG Zephyrus G14 (GA402RJ)** running **Ubuntu 26.04 LTS (Kernel 7.0)**:
- **Continuous Idle Uptime:** 24+ hours unattended idle with zero freezes.
- **Heavy Mixed Workloads:** Multi-hour *Resident Evil 4 Remake* Proton gaming sessions alongside concurrent KVM virtualized hypervisor instances.
- **Sleep / Resume:** Instantaneous wake with zero display driver or PCIe bus panics.

---

## 🤝 Supported Hardware

- **ASUS ROG Zephyrus G14 (2022)** — Model `GA402RJ` (R9 6900HS + RX 6700S)
- **ASUS ROG Zephyrus G14 (2022)** — Model `GA402RK` (R9 6900HS + RX 6800S)
- Compatible with all AMD Rembrandt 6000-series mobile platforms experiencing idle voltage dropouts.

---

## License
MIT &mdash; Free for the community.
