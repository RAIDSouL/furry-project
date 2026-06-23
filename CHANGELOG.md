# Changelog / Dev Log

โปรเจกต์ **Furry Project** — Godot 4.7 (Forward+, Jolt Physics, D3D12)
ฉากหลัก: `scenes/Gameplay.tscn`

---

## 2026-06-24 — Isometric mode, project restructure, multiplayer groundwork

### โหมดกล้องที่ 2 — Isometric click-to-move (Lost Ark style)

- ปุ่มสลับโหมดมุมขวาบน หรือกด `Tab` → สลับ **TPS ↔ ISO**
- **ISO**: กล้อง 3/4 มุมก้ม (`IsoCamera` ตามตัวละคร), **คลิกขวา**บนพื้น = เดินไปจุดนั้น
  (raycast จากกล้องหา floor), ตัวละครหันหน้าตามทิศ, anim เดิน/วิ่งตามความเร็ว;
  คลิกซ้ายเว้นไว้เผื่อโจมตี/เลือกเป้าทีหลัง
- **TPS**: เหมือนเดิม (WASD + เมาส์ + dodge/jump/sprint) — กล้อง/โหมด/เมาส์เป็นของ local

### จัดโครงสร้างไฟล์

- แยก Player เป็น prefab **`scenes/player.tscn`** (Gameplay instance มาใช้ — spawn ซ้ำได้)
- ย้าย scene เข้าโฟลเดอร์ `scenes/` → main scene = `scenes/Gameplay.tscn`
- animation idle/walk/run ฝังอยู่ใน `scenes/player.tscn` แล้ว (ติดไปกับ prefab)
- `.gitignore` ปรับตามมาตรฐาน Godot 4 (`.import/`, `export_presets.cfg`, `*.translation`, mono)

### Multiplayer groundwork (Phase 1)

- เป้าหมาย: **co-op 3 คน** · transport = **ENet (direct IP)** · **client-authoritative**
- ใส่ `is_multiplayer_authority()` guard ใน `player.gd` → local peer เท่านั้นที่อ่าน input /
  คุมกล้อง / แสดง HUD (single-player ยังเล่นได้ปกติ)
- **ค้างไว้ (Phase 2)**: NetworkManager (host / join by IP), หน้าเมนู Host/Join,
  MultiplayerSpawner (เกิด player ต่อ peer), MultiplayerSynchronizer (sync position/ทิศ/anim/HP),
  ทำให้ remote player เล่นอนิเมชันจากค่าที่ sync

---

## 2026-06-12 — Player movement system (Naraka / GBF Relink inspired)

สร้างระบบตัวละครเล่นได้แบบ third-person ครบวงจร ขับเคลื่อนด้วย state machine
อ้างอิงดีไซน์จาก `PLAYER_SYSTEM.md` (ปรับมาใช้กับ Godot)

### ปุ่มควบคุม (โหมด TPS)

| ปุ่ม | การทำงาน |
| --- | --- |
| `W A S D` | เดิน (อิงทิศกล้อง) |
| `Left Ctrl` | สลับ sprint (วิ่ง — **ไม่กินสตามินา**) |
| `Left Shift` | dodge (พุ่งหลบ + i-frame + กินสตามินา + chain ได้) |
| `Space` (แตะ) | กระโดดเตี้ย |
| `Space` (ค้าง) | กระโดดสูง (variable height) |
| `Mouse` | หมุนกล้อง (third-person, SpringArm) |
| `Esc` | ปลดล็อกเมาส์ |

### State machine — `scripts/player.gd`

4 สเตท: **Idle / Move / Jump / Dodge** ป้อนด้วย single-slot input buffer (0.15s)

- **Movement**: camera-relative, smooth accel (`accel_time` 0.1s) แต่หยุดคม (`stop_time` 0.05s + snap) ไม่มีอาการไถล, auto-rotate หันตามทิศ
- **Jump**: coyote time 0.15s, variable height (ปล่อยตอนพุ่งขึ้น = ตัดความเร็ว 50%), cooldown 0.1s, ควบคุมกลางอากาศได้เต็มที่
- **Stamina** (max 100): regen 15/s หลังหน่วง 1.0s — **เฉพาะ dodge เท่านั้นที่กินสตามินา** (sprint ฟรี)
- **Dodge**: decel 20→5 m/s ใน 0.35s, i-frame ช่วง 0.18s แรก, ทิศ = input ที่กด (ไม่กด = ทิศที่หันอยู่)
- **Chain dodge**: กดซ้ำใน 1.0s → cost ไต่ `20 → 35 → 50` (เต็มถัง dodge ติดได้ 2 ครั้ง)
- **Air dodge (GBF Relink style)**: กลางอากาศ dodge ได้ **ครั้งเดียว** ต้องแตะพื้นก่อนถึงจะ dodge อากาศได้อีก
- **Health** (max 100): `take_damage()` + `is_invincible()` พร้อมให้ระบบ combat เรียกใช้ (ยังไม่มี damage source)

ค่าทั้งหมดปรับได้ใน Inspector ที่โหนด `Player` (กลุ่ม Movement / Jump / Stamina / Dodge / Health)
ยกเว้น `DODGE_COSTS` (chain cost) เป็น `const` ในสคริปต์

### Animation — retargeted จาก Mixamo

โมเดล `models/vrc1.glb` (VRoid humanoid, 63 bones) จาก Sketchfab (CC-BY)
ท่าจาก Mixamo (FBX, In Place) ถูก **retarget แบบ bake เอง** (global-rotation transfer
ชดเชยความต่างของ rest pose) เข้า skeleton ของโมเดล แล้วฝังเป็น Animation ในซีนตัวละคร

- `idle.fbx`, `walking.fbx`, `run.fbx` → animation `idle` / `walk` / `run`
- `AnimTree` (BlendSpace1D) blend idle(0) → walk(1) → run(2) ตามความเร็วที่ตั้งใจ
- ระหว่าง dodge: freeze ท่าไว้ก่อน (ยังไม่มีท่า dodge จริง — TODO)

### ฉาก / สภาพแวดล้อม

- **Floor** (StaticBody3D + Jolt collision) 60×60 + กำแพงล่องหน 4 ด้าน (กันตกขอบ)
- **Grid shader** `shaders/grid.gdshader` — กริด world-space เส้นทุก 1m + เส้นหนาทุก 10m (กะระยะได้)
- Sun (DirectionalLight + เงา) + WorldEnvironment (procedural sky)
- HUD: แถบ HP (แดง) + Stamina (ฟ้า) + ปุ่มสลับโหมด

### Debug

`scripts/player.gd` print `[STATE] <state> | stam | hp | chain [I-FRAME]` เมื่อเปลี่ยนสเตท
ดูได้ใน Output panel ตอนรัน

### TODO / placeholder

- ท่า dodge animation (ตอนนี้ freeze ท่าไว้)
- ระบบ combat / damage source (โครง Health + i-frame พร้อมแล้ว)
- ท่า jump / fall animation (ตอนนี้ใช้ blend เดิน/วิ่งกลางอากาศ)
- multiplayer co-op (Phase 2 — ดู entry ล่าสุด)

---

## เครื่องมือ

โปรเจกต์ใช้ **Godot MCP Pro** (addon ใน `addons/godot_mcp/` + Node.js server) เป็นบริดจ์
ให้ AI (Claude) แก้ scene/script/shader และรันทดสอบในตัว editor ได้โดยตรง
ดูรายละเอียดใน `CLAUDE.md`
