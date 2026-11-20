# 280-ZZZAP — Native Engine and DNA Development Lineage

**DNA software architecture · 2026-11-20 · v20261120-0001**

## Original evidence

This analysis is grounded in the **original 280-ZZZAP (1976) ROM set 1**, distributed across six 1 KB devices:

| ROM | CPU address | CRC32 |
| --- | --- | --- |
| `zzzaph` | `$0000–$03FF` | `1fa86e1c` |
| `zzzapg` | `$0400–$07FF` | `9639bc6b` |
| `zzzapf` | `$0800–$0BFF` | `adc6ede1` |
| `zzzape` | `$0C00–$0FFF` | `472493d6` |
| `zzzapd` | `$1000–$13FF` | `4c240ee1` |
| `zzzapc` | `$1400–$17FF` | `6e85aeaf` |

**Hardware:** Intel 8080, with working RAM `$2000–$23FF` and raster video RAM `$2400–$3FFF`.

## Native program architecture

280-ZZZAP uses native 8080 instructions for interrupt handling, startup, input processing, scoring, road display, and the driving game loop. The ROM also contains service routines reached using CPU restart instructions. These are native callable helpers, rather than a demonstrated independent command-stream interpreter.

### Reset and interrupt entries

```asm
RESET_ENTRY:                         ; $0000
        NOP
        NOP
        XOR A
        OUT ($05),A
        JP BOOT_START

IRQ_PHASE_ZERO:                      ; $0008
        PUSH AF
        PUSH BC
        PUSH DE
        LD C,$00
        JP IRQ_COMMON_HANDLER

IRQ_PHASE_ONE:                       ; $0010
        PUSH AF
        PUSH BC
        PUSH DE
        LD C,$01
        JP IRQ_COMMON_HANDLER
```

`BOOT_START` is at `$0064`; both interrupt phases enter the common routine at `$069E`. The two `C` values select interrupt phases.

### Register-preserving restart services

```asm
RST18_SAVE_CONTEXT:                  ; $0018
        EX (SP),HL
        PUSH DE
        PUSH BC
        PUSH AF
        JP (HL)

RST20_RESTORE_CONTEXT:               ; $0020
        POP HL
        POP AF
        POP BC
        POP DE
        POP HL
        RET
```

These two routines implement a compact CPU-stack and register-save convention. Their surrounding bytes contain inline data, so the source reconstruction must distinguish instructions from tables precisely.

### Inline-byte argument service

```asm
RST30_INLINE_ARGUMENT:               ; $0030
        EX (SP),HL
        LD A,(HL)
        INC HL
        EX (SP),HL
        CALL INLINE_ARGUMENT_HELPER
        LD (HL),A
```

At `$0030`, the return address on the CPU stack provides access to an inline operand; incrementing that address advances past the parameter. The helper call targets `$0F91`.

## Screen-text localization

The ROM contains four sets of screen text: English, German, French, and Spanish. The native selector at `$1000` uses DIP-switch bits read through input port `$02`, then retrieves a word pointer. The ROM pointer table at `$123F` contains:

```asm
LOCALE_POINTER_TABLE:                ; $123F
        DW $124D
        DW $13F0
        DW $1551
        DW $16B3
```

Each pointer identifies the address used to locate messages for that language. This is **display-text localization**, not an interpreted game-word dictionary.

Original English text includes `MAX CURVE 160 MPH`, `EXTENDED TIME`, `SHIFT GEAR INTO LOW SPEED`, `INSERT COIN`, `GAME OVER`, and `DATSUN 280 ZZZAP`. High-bit markers terminate the encoded strings; the original bytes must be preserved exactly.

## Road, steering and game-state data

The program maintains road state and vehicle/gameplay variables in working RAM. The following names are reverse-engineering targets to confirm through native readers and writers:

| RAM region | Analysis target |
| --- | --- |
| `$2020` | Interrupt input sample |
| `$2023` | Attract / gameplay / extended-time state |
| `$2025–$2028` | Pylon table pointers |
| `$203A` | Steering sample / transformed steering value |
| `$203D–$203E` | BCD score |
| `$2062–$20CF` | First pylon record table |
| `$20D0–$213D` | Second pylon record table |
| `$2145–$2244` | First expanded road table |
| `$2245–$2344` | Second expanded road table |

The ROM includes compressed/delta-coded source data used for expanded road tables. Data representations in the new assembly should be named by the actual decoding routine and include the encoding structure, rather than raw unexplained bytes.

## DNA architecture context

280-ZZZAP demonstrates a **native-engine design** within Dave Nutting Associates' broader development history. In parallel, other DNA titles used game-command interpreters, and the later Astrocade BIOS and TERSE development environments supported their own standardized execution mechanisms.

The useful comparison is the engineering technique: compact ROM data, native helpers, frame servicing, and register/stack conventions. A native `RST` helper and a localized text pointer table each serve specific purposes; neither alone establishes the command-stream execution model of TERSE.

## Reverse-engineering acceptance criteria

1. Recover original 8080 instructions with stable, meaningful routine labels.
2. Separate native code from strings, font graphics, game drawings, pointer tables, and compressed road records.
3. Use descriptive section headers, blank lines, and inline bitmap rows in the style established by the project's assembly reference.
4. Reassemble the full `$0000–$17FF` image using `tools/zmac` v1.3.
5. Verify every one of the six 1 KB ROM SHA-1 checksums against the original archive.
6. Exercise the resulting `roms/280zzzap.zip` in MAME.

## Original documentation and emulator references

- `roms/original/280zzzap.zip` — original program ROM set 1
- `roms/original/280zzzapa.zip` — separate set 2
- [280-ZZZAP game logic](280_ZZZap_Game_Logic_(0610-00907A).pdf)
- [280-ZZZAP wiring diagram](280_ZZZap_Wiring_Diagram_(12_1_1976).pdf)
- [MAME Midway Intel 8080 driver](https://github.com/mamedev/mame/blob/master/src/mame/midw8080/mw8080bw.cpp)
