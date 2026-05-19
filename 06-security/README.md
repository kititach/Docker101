# Module 06 — Container Security

ทำให้ container ปลอดภัยขึ้นทีละชั้น — defense in depth จาก non-root user ไปจนถึง runtime hardening แบบ production

## Labs ในโมดูลนี้

| Lab | หัวข้อ | สิ่งที่จะได้เรียน |
|-----|--------|-----------------|
| [01-non-root](./01-non-root/) | Non-Root User | USER instruction, numeric UID, file ownership |
| [02-capabilities](./02-capabilities/) | Linux Capabilities | drop ALL + add specific, principle of least privilege |
| [03-readonly-rootfs](./03-readonly-rootfs/) | Read-Only Filesystem | --read-only + tmpfs สำหรับ writable paths |
| [04-image-scanning](./04-image-scanning/) | CVE Scanning | trivy, เปรียบเทียบ vulnerable vs hardened |
| [05-runtime-hardening](./05-runtime-hardening/) | Production Hardening | รวมทุก technique ใน compose.yaml เดียว |

## Threat Model พื้นฐาน

```
ถ้า attacker เจาะ application ใน container ได้ → จะทำอะไรต่อได้?

✓ container เป็น root + default caps + writable rootfs
  → ติดตั้ง tools (apk add), แก้ binaries, persist malware, NET_RAW scan, ฯลฯ

✓ container non-root + drop ALL caps + read-only rootfs + no-new-privileges
  → ติดตั้งอะไรไม่ได้, แก้ไฟล์ระบบไม่ได้, escalate privilege ไม่ได้
  → exploit ที่ทำได้ลดลงมาก
```

## Defense in Depth Layers

```
1. Image layer          — base image ใหม่, scan CVE, sign images
2. Build layer          — multi-stage, ไม่ build tools ใน production image
3. User layer           — non-root, numeric UID
4. Capabilities         — drop ALL, add เฉพาะที่จำเป็น
5. Filesystem layer     — --read-only + tmpfs
6. Runtime options      — no-new-privileges, seccomp, AppArmor
7. Resource layer       — ulimits, memory limit, pids-limit
8. Network layer        — network segmentation (Module 02 Lab 05)
9. Secret layer         — Docker secrets / external vault (Module 04 Lab 04)
10. Monitoring layer    — audit logs, falco (Module 09)
```
