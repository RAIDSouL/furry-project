# Furry Project

เกม 3D third-person บน **Godot 4.6** — ตัวละคร furry พร้อมระบบการเคลื่อนที่สไตล์
แอ็กชัน (วิ่ง / dodge + i-frame / chain dodge / air dodge) ได้แรงบันดาลใจจาก
*Naraka: Bladepoint* และ *Granblue Fantasy: Relink*

> ฉากหลัก: `Gameplay.tscn` · Renderer: **Forward+** · Physics: **Jolt** · Windows driver: **D3D12**

---

## ความต้องการ

- **Godot 4.6** (หรือใหม่กว่า) — เอนจินคือ toolchain ทั้งหมด ไม่มี build step แยก
- *(ไม่บังคับ)* **Node.js 18+** — เฉพาะถ้าจะใช้ Godot MCP Pro (บริดจ์ให้ AI ช่วยแก้ในเอดิเตอร์)

## เริ่มต้นใช้งาน

```sh
git clone https://github.com/RAIDSouL/furry-project.git
cd furry-project
godot --editor --path .      # เปิดในเอดิเตอร์
```

กด **▶ (F5)** เพื่อรัน — `Gameplay.tscn` ถูกตั้งเป็น main scene แล้ว
หรือรันตรงจากคอมมานด์ไลน์:

```sh
godot --path .
```

## ปุ่มควบคุม

| ปุ่ม | การทำงาน |
| --- | --- |
| `W A S D` | เดิน (อิงทิศกล้อง) |
| `Left Ctrl` | สลับวิ่ง (sprint — ไม่กินสตามินา) |
| `Left Shift` | dodge (หลบ + i-frame + กินสตามินา, chain ได้, กลางอากาศได้ 1 ครั้ง) |
| `Space` | กระโดด (แตะ = เตี้ย, ค้าง = สูง) |
| `Mouse` | หมุนกล้อง |
| `Esc` | ปลดล็อกเมาส์ |

รายละเอียดระบบทั้งหมด + ค่าที่ปรับได้ ดูที่ [CHANGELOG.md](CHANGELOG.md)

## โครงสร้างโปรเจกต์

```
Gameplay.tscn          ฉากหลัก (player, floor, walls, light, HUD)
scripts/player.gd      ตัวควบคุมตัวละคร (state machine)
shaders/grid.gdshader  พื้นกริด world-space (1m / 10m)
models/                โมเดลตัวละคร (.glb)
animations/            ท่าจาก Mixamo (.fbx) ใช้ bake retarget
addons/godot_mcp/      Godot MCP Pro (ดู CLAUDE.md)
```

## พัฒนาด้วย AI (ไม่บังคับ)

โปรเจกต์ติดตั้ง **Godot MCP Pro** ไว้ — บริดจ์ WebSocket ให้ Claude แก้ scene/script/
shader และรันทดสอบในเอดิเตอร์ได้โดยตรง วิธีตั้งค่าและใช้งานอยู่ใน [CLAUDE.md](CLAUDE.md)

## เครดิต

- **โมเดลตัวละคร "VRC1"** โดย *取名字好难啊* (Sketchfab) — สัญญาอนุญาต **CC-BY 4.0** (ต้องให้เครดิตผู้สร้าง)
- **อนิเมชัน** จาก [Mixamo](https://www.mixamo.com/) (Adobe)
- เอนจิน [Godot](https://godotengine.org/)
