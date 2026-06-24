# Changelog / Dev Log

โปรเจกต์ **Furry Project** — Godot 4.7 (Forward+, Jolt Physics, D3D12)
ฉากหลัก: `scenes/Gameplay.tscn`

---

## 2026-06-25 — Combat: melee attack + training dummy (co-op synced)

ของเล่นชิ้นแรกของระบบ combat — **ตีได้ มอนสเตอร์เลือดลด** ทั้ง single-player และ co-op

### ท่าโจมตีผู้เล่น — `scripts/player.gd`
- เพิ่มสเตต **ATTACK** ในสเตตแมชชีน (Idle/Move/Jump/Dodge/**Attack**)
- **คลิกซ้าย** (โหมด TPS) = ฟัน 1 ครั้ง — ล็อกการเคลื่อนที่ระหว่างสวิง (`attack_duration` 0.45s),
  จังหวะโดน (`attack_strike` 0.18s) ยิง sphere ไปข้างหน้า (`attack_range`/`attack_radius`)
  หาเป้าบน physics layer 3 (enemy hurtbox) แล้วส่งดาเมจ
- **dodge cancel ได้**: กด dodge ระหว่างฟัน → ยกเลิกท่าทันที (จัดการโดย dodge trigger เดิม)
- ค่าปรับได้ใน Inspector กลุ่ม **Attack** (damage 25 / duration / strike / range / radius)
- ยังไม่มีท่าฟันจริง — freeze ท่าไว้ก่อนเหมือน dodge (TODO)

### มอนสเตอร์ตัวแรก — `scenes/dummy.tscn` + `scripts/dummy.gd`
- **Training dummy** ยืนนิ่ง (StaticBody3D) มี **HP bar 3D** ลอยเหนือหัว (billboard ตามกล้อง,
  หลอดวิ่งจากซ้าย) + **hit flash** ขาววาบตอนโดน
- HP หมด → ล้มหาย ปิด collision/hurtbox แล้ว **respawn อัตโนมัติ** หลัง `respawn_delay` (3s)
- **server-authoritative**: เฉพาะ server (หรือ local peer ตอน solo) เท่านั้นที่คิดดาเมจ/นับ
  respawn; `_health` sync ผ่าน `MultiplayerSynchronizer` → ทุกเครื่องเห็นเลือด/flash ตรงกัน

### Combat flow (client-authoritative players → server-authoritative monsters)
- ผู้ตี (peer ไหนก็ได้) ตรวจชนเองในเครื่อง แล้วเรียก `take_damage.rpc_id(1, dmg)` ส่งให้ server
  คิดดาเมจ — กัน desync, ไม่มีใครยิงเลือดมั่วได้ (offline solo: RPC รันในเครื่องเอง)
- hurtbox = physics layer 3, ท่าฟันใช้ `intersect_shape` mask layer 3 — body ผู้เล่น (layer 1) ไม่โดน

### โครงสร้างฉาก
- `Gameplay.tscn`: เพิ่ม `Monsters` (container) + `MonsterSpawner` (MultiplayerSpawner)
  คู่กับของเดิม; `gameplay.gd` spawn dummy ฝั่ง server/solo (3 ตัวหน้าจุดเกิดผู้เล่น)

### TODO
- ท่าฟัน/คอมโบจริง (ตอนนี้ฟันเดี่ยว freeze ท่า), attack ในโหมด ISO (ตอนนี้เฉพาะ TPS),
  มอนสเตอร์ที่ขยับ/ตีกลับ (ดู entry ก่อนหน้าเรื่อง AI)

---

## 2026-06-24 — Multiplayer Phase 2 (co-op networking)

ต่อจาก groundwork — ตอนนี้ **co-op 1–4 คนเชื่อมต่อ/spawn/sync ได้จริง** (ENet, direct IP,
client-authoritative + server relay)

### Transport — `scripts/network_manager.gd` (autoload `NetworkManager`)
- `host()` / `join(ip)` / `leave()` ผ่าน `ENetMultiplayerPeer`, port **24565**, สูงสุด **4 คน**
- เป็น transport ล้วน — การ spawn/รับสัญญาณทำใน `gameplay.gd` ผ่าน `multiplayer.*` signals

### Session controller — `scripts/gameplay.gd` (ติดที่ root ของ `Gameplay.tscn`)
- หน้าเมนู **Host / Join (มีช่องกรอก IP) / Single Player** + แถบ Status (`NetworkUI`)
- **server เป็นคนสั่ง spawn** player ต่อ peer (ตั้งชื่อโหนด = peer id), `MultiplayerSpawner`
  replicate ไปทุก client (รวม late-join), despawn เมื่อ peer หลุด
- Single Player = host ที่ไม่มีใคร join (ใช้ spawn path เดียวกัน ไม่ต้องแยกเคส)
- จัดการ `connected_to_server` / `connection_failed` / `server_disconnected` → กลับเมนู

### Per-player networking — `scenes/player.tscn` + `scripts/player.gd`
- `MultiplayerSynchronizer` sync **position + ทิศโมเดล (`Sketchfab_Scene:rotation`) +
  anim blend (`AnimTree:parameters/blend_position`)**
- authority อิงชื่อโหนด: `_enter_tree()` → `set_multiplayer_authority(name.to_int())`
  (consistent ทุก peer; ชื่อไม่ใช่ตัวเลข = standalone ใช้ค่า default → single-player ยังเล่นได้)
- remote player: ปิดทั้งสองกล้อง + คง AnimTree active (เล่น anim จากค่า blend ที่ sync มา)
- HUD (HP/Stamina/ปุ่มโหมด) ผูกเฉพาะ local player — หาโหนดผ่าน `current_scene` (เพราะ player
  อยู่ใต้ container `Players` แล้ว ไม่ใช่ลูกตรงของ root)

### โครงสร้างฉาก
- `Gameplay.tscn`: `Players` (container) + `PlayerSpawner` (MultiplayerSpawner) + `NetworkUI`
  แทน static Player instance เดิม

### หมายเหตุการทดสอบ
- single-player (ปุ่ม Single Player) ทดสอบผ่าน editor แล้ว — spawn/กล้อง/HUD/anim ปกติ
- การเชื่อมต่อจริง 2–3 เครื่อง: host เครื่องนึง, อีกเครื่องกรอก IP แล้วกด Join
  (รันหลาย instance พร้อมกันเพื่อทดสอบในเครื่องเดียวได้)

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
- **(ทำต่อใน Phase 2 ด้านบนแล้ว)**: NetworkManager, เมนู Host/Join, MultiplayerSpawner,
  MultiplayerSynchronizer, remote player เล่น anim จากค่าที่ sync

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
