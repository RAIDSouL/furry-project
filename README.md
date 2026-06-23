# Furry Project

เกม 3D บน **Godot 4.7** — ตัวละคร furry พร้อมระบบการเคลื่อนที่สไตล์แอ็กชัน
(วิ่ง / dodge + i-frame / chain dodge / air dodge) แรงบันดาลใจจาก *Naraka: Bladepoint*
และ *Granblue Fantasy: Relink* + โหมดกล้อง **isometric click-to-move** แบบ *Lost Ark*

> ฉากหลัก: `scenes/Gameplay.tscn` · Renderer: **Forward+** · Physics: **Jolt** · Windows driver: **D3D12**

---

## ความต้องการ

- **Godot 4.7** (หรือใหม่กว่า) — เอนจินคือ toolchain ทั้งหมด ไม่มี build step แยก
- *(ไม่บังคับ)* **Node.js 18+** — เฉพาะถ้าจะใช้ Godot MCP Pro (บริดจ์ให้ AI ช่วยแก้ในเอดิเตอร์)

## เริ่มต้นใช้งาน

```sh
git clone https://github.com/RAIDSouL/furry-project.git
cd furry-project
godot --editor --path .      # เปิดในเอดิเตอร์
```

กด **▶ (F5)** เพื่อรัน — `scenes/Gameplay.tscn` ถูกตั้งเป็น main scene แล้ว

## โหมดเล่น (สลับด้วยปุ่มมุมขวาบน หรือ `Tab`)

- **TPS** — third-person, เดินด้วย WASD + หมุนกล้องด้วยเมาส์
- **ISO** — isometric, **คลิกขวา**บนพื้นเพื่อเดินไปจุดนั้น (สไตล์ Lost Ark)

## ปุ่มควบคุม

| ปุ่ม | การทำงาน |
| --- | --- |
| `Tab` / ปุ่มมุมขวาบน | สลับโหมด TPS ↔ ISO |
| `W A S D` | เดิน (โหมด TPS, อิงทิศกล้อง) |
| คลิกขวา | เดินไปตำแหน่งที่คลิก (โหมด ISO) |
| `Left Ctrl` | สลับวิ่ง (sprint — ไม่กินสตามินา) |
| `Left Shift` | dodge (หลบ + i-frame + กินสตามินา, chain ได้, กลางอากาศได้ 1 ครั้ง) |
| `Space` | กระโดด (แตะ = เตี้ย, ค้าง = สูง) |
| `Mouse` | หมุนกล้อง (โหมด TPS) |
| `Esc` | ปลดล็อกเมาส์ |

รายละเอียดระบบทั้งหมด + ค่าที่ปรับได้ ดูที่ [CHANGELOG.md](CHANGELOG.md)

## โครงสร้างโปรเจกต์

```
scenes/
  Gameplay.tscn        ฉากหลัก (level: floor, walls, light, HUD)
  player.tscn          prefab ตัวละคร (instance ใน Gameplay / spawn ตอน MP)
scripts/player.gd      ตัวควบคุมตัวละคร (state machine + 2 โหมดกล้อง)
shaders/grid.gdshader  พื้นกริด world-space (1m / 10m)
models/                โมเดลตัวละคร (.glb)
animations/            ท่าจาก Mixamo (.fbx) ใช้ bake retarget
addons/godot_mcp/      Godot MCP Pro (ดู CLAUDE.md)
```

## Multiplayer (co-op 1–4 คน)

เชื่อมต่อได้แล้ว — **ENet, direct IP, client-authoritative**, สูงสุด 4 คน (port `24565`)

- เปิดเกม → เมนูจะขึ้น: **Host** (เป็นเซิร์ฟเวอร์), **Join** (กรอก IP ของ host แล้วต่อ),
  หรือ **Single Player** (เล่นคนเดียว)
- ทดสอบในเครื่องเดียว: เปิดเกมหลาย instance — instance แรกกด Host, ที่เหลือกรอก
  `127.0.0.1` แล้วกด Join
- server เป็นคน spawn ตัวละครต่อผู้เล่น, ตำแหน่ง/ทิศ/อนิเมชัน sync ข้ามเครื่องผ่าน
  `MultiplayerSynchronizer`

รายละเอียดสถาปัตยกรรมดูใน [CHANGELOG.md](CHANGELOG.md)

## พัฒนาด้วย AI (ไม่บังคับ)

โปรเจกต์ติดตั้ง **Godot MCP Pro** ไว้ — บริดจ์ WebSocket ให้ Claude แก้ scene/script/
shader และรันทดสอบในเอดิเตอร์ได้โดยตรง วิธีตั้งค่าและใช้งานอยู่ใน [CLAUDE.md](CLAUDE.md)

## เครดิต

- **โมเดลตัวละคร "VRC1"** โดย *取名字好难啊* (Sketchfab) — สัญญาอนุญาต **CC-BY 4.0** (ต้องให้เครดิตผู้สร้าง)
- **อนิเมชัน** จาก [Mixamo](https://www.mixamo.com/) (Adobe)
- เอนจิน [Godot](https://godotengine.org/)
