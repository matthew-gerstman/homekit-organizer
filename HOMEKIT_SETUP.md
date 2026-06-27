# Matthew's HomeKit Setup - Syracuse

> Generated: December 19, 2025

## Overview

| Metric | Value |
|--------|-------|
| **Home Name** | Syracuse |
| **Total Accessories** | 162 |
| **Rooms** | 10 |
| **Unassigned Accessories** | 18 (scenes/automations) |
| **Home Assistant Bridge Accessories** | 130 |

## The Problem

You have **130 accessories dumped into a "Home Assistant" room** from your Home Assistant HomeKit Bridge. This is exactly what `homekit-organizer` was built to fix!

---

## Rooms & Accessories

### 🏠 Default Room - Unassigned (18)
*These appear to be scenes/automations, not physical devices:*

| Accessory | Category | Status |
|-----------|----------|--------|
| Bedroom Arctic aurora | Other | ✓ |
| Bedroom Galaxy | Other | ✓ |
| Bedroom Scarlet dream | Other | ✓ |
| Bedroom Tokyo | Other | ✓ |
| Bedtime | Other | ✓ |
| Chill | Other | ✓ |
| Early Riser | Other | ✓ |
| Good Morning | Other | ✓ |
| Good Night | Other | ✓ |
| Living room | Other | ✓ |
| Office | Other | ✓ |
| Princess | Other | ✓ |
| Rec Room | Other | ✓ |
| Sleep Mode | Other | ✓ |
| Sync Lights | Other | ✓ |
| TV Time | Other | ✓ |
| USA | Other | ✓ |
| Unassigned Smart Away | Other | ✓ |

### 🌳 Backyard (4)
*Outdoor cameras - all currently offline*

| Accessory | Category | Status |
|-----------|----------|--------|
| Back | IP Camera | ✗ |
| Deck | IP Camera | ✗ |
| Deck Left | IP Camera | ✗ |
| Deck Right | IP Camera | ✗ |

### 🛏️ Bedroom (1)

| Accessory | Category | Status |
|-----------|----------|--------|
| TV | Television | ✓ |

### 🚪 Front (3)
*Front entrance cameras - currently offline*

| Accessory | Category | Status |
|-----------|----------|--------|
| Front Door | Video Doorbell | ✗ |
| Front Door Hallway F0DA | IP Camera | ✗ |
| Front Flood Light | IP Camera | ✗ |

### 🚗 Garage (1)

| Accessory | Category | Status |
|-----------|----------|--------|
| Garage | IP Camera | ✗ |

### 🏠 Home Assistant Bridge (130)
*⚠️ All dumped into one room - needs organization!*

#### Physical Lights (Need Room Assignment)

**Bedroom Lights:**
- Bedroom Ceiling
- Bedroom TV Lights
- Leah's Sconce
- Matthew's Sconce
- SleepNumber Master Bedroom Light 3
- Master Bathroom Vanity Lights

**Living Room Lights:**
- Living Room TV Lights
- Dining Room Chandelier (currently in Living Room)
- Hue play gradient lightstrip 1
- Play gradient tube 1
- Table lamp
- Window Lamp
- Hue Sana Top
- Hue Sana Bottom

**Kitchen Lights:**
- Kitchen (main)

**Office Lights:**
- Hydra Lamp
- Doctor Who Lamp
- Japanese Lamp
- Gold Edison Lamp
- Owl Lamp
- Rose Lamp
- Slytherin Lamp
- Monkey/Monkeys
- Pixar 2

**Ima's Room Lights:**
- Ima Ceiling
- Ima Nightstand

**Guest Room Lights:**
- Guest Room Ceiling

**Laundry Room Lights:**
- Laundry Room Ceiling

**Rec Room Lights:**
- Rec Ceiling 1-6 (6 lights)

**Outdoor Lights:**
- Outdoor Lightstrip Center
- Outdoor Lightstrip Left
- Outdoor Lightstrip Right
- Backyard Lights
- Landing Lights
- Festavia permanent 1
- Festavia string lights 1-2

**Utility:**
- Electrical Room
- Front Closet
- Server Closet

#### Scenes (from Hue/Home Assistant)
*These are scene presets, not physical devices:*

- Bedroom: City of love, Dimmed, Malibu pink, Nightlight, Nighttime, Shine, Sleepy, Unwind
- Guest room: Bright, Dimmed, Nightlight, Relax
- Ima's Room: Bright, Dimmed, Nightlight
- Kitchen: Concentrate, Energize, Nightlight, Read, Relax
- Laundry room: Concentrate, Energize, Nightlight, Read, Relax
- Living room: City of love, Concentrate, Crocus, Dimmed, Emerald flutter, Energize, Memento, Nebula, Nightlight, Promise, Read, Relax, Rio, Tokyo
- Office: Arctic aurora, Concentrate, Crocus, Dimmed, Emerald flutter, Energize, Nightlight, Read, Relax, Tokyo
- Outdoor: Blue Planet, City of love, Cosmos, Forest adventure, Meriete, Opalite, Orange fields, Prismatic, Snow sparkle, Sparkle, Starlight, Tokyo, USA, Under the tree, Winter beauty
- Rec Room: Concentrate, Energize, Nightlight, Read, Relax
- Other: I'm Tired, Princess, Princess Living Room

### 👧 Ima's Room (1)

| Accessory | Category | Status |
|-----------|----------|--------|
| Ima's Room | Other | ✓ |

### 🧺 Laundry Room (1)

| Accessory | Category | Status |
|-----------|----------|--------|
| Hallway FB96 | IP Camera | ✗ |

### 🛋️ Living Room (2)

| Accessory | Category | Status |
|-----------|----------|--------|
| Dining Room | IP Camera | ✗ |
| Dining Room Chandelier | Other | ✓ |

### 🎮 Rec Room (1)

| Accessory | Category | Status |
|-----------|----------|--------|
| Downstairs | IP Camera | ✗ |

---

## Recommended Organization

Based on your setup, here's a suggested reorganization:

### Create These Rooms (if not exists):
- Master Bedroom
- Master Bathroom
- Office
- Kitchen
- Guest Room
- Outdoor/Backyard

### Move These Accessories:

```yaml
rooms:
  - name: Master Bedroom
    accessories:
      - pattern: "Bedroom Ceiling"
      - pattern: "Bedroom TV Lights"
      - pattern: "Leah's Sconce"
      - pattern: "Matthew's Sconce"
      - pattern: "SleepNumber*"
      
  - name: Master Bathroom
    accessories:
      - pattern: "Master Bathroom*"
      
  - name: Office
    accessories:
      - pattern: "Hydra Lamp"
      - pattern: "Doctor Who Lamp"
      - pattern: "Japanese Lamp"
      - pattern: "Gold Edison Lamp"
      - pattern: "Owl Lamp"
      - pattern: "Rose Lamp"
      - pattern: "Slytherin Lamp"
      - pattern: "Monkey*"
      - pattern: "Pixar*"
      
  - name: Kitchen
    accessories:
      - exact: "Kitchen"
      
  - name: Guest Room
    accessories:
      - pattern: "Guest Room Ceiling"
      
  - name: Rec Room
    accessories:
      - pattern: "Rec Ceiling*"
      
  - name: Outdoor
    accessories:
      - pattern: "Outdoor Lightstrip*"
      - pattern: "Backyard Lights"
      - pattern: "Landing Lights"
      - pattern: "Festavia*"
```

---

## Camera Status

⚠️ **All cameras are showing as offline (✗)**

| Location | Camera | Status |
|----------|--------|--------|
| Backyard | Back | ✗ |
| Backyard | Deck | ✗ |
| Backyard | Deck Left | ✗ |
| Backyard | Deck Right | ✗ |
| Front | Front Door | ✗ |
| Front | Front Door Hallway F0DA | ✗ |
| Front | Front Flood Light | ✗ |
| Garage | Garage | ✗ |
| Laundry | Hallway FB96 | ✗ |
| Living Room | Dining Room | ✗ |
| Rec Room | Downstairs | ✗ |

---

## Statistics

| Category | Count |
|----------|-------|
| IP Cameras | 11 |
| Video Doorbells | 1 |
| Televisions | 1 |
| Bridges | 1 |
| Lights/Other | 148 |

---

## Next Steps

1. **Create a config.yaml** with your desired room organization
2. **Run `homekit-organizer diff`** to preview changes
3. **Run `homekit-organizer apply`** to reorganize

Example config to get started:

```yaml
home: Syracuse

rooms:
  - name: Master Bedroom
    accessories:
      - pattern: "Bedroom*"
      - pattern: "*Sconce"
      - pattern: "SleepNumber*"
      
  - name: Office  
    accessories:
      - pattern: "*Lamp"
      
  - name: Rec Room
    accessories:
      - pattern: "Rec Ceiling*"
```

