# 280-ZZZAP: Original ROM Reconstruction Coverage

**Baseline:** MAME `280zzzap` (set 1); original archive `roms/original/280zzzap.zip`.

The source file `src/280zzzap.asm` is a complete-address-space reconstruction for the six-chip 6,144-byte original ROM image. The reconstruction was made directly from the original ROM bytes.

## Static ROM classification

| Category | Bytes | Description |
| --- | ---: | --- |
| Decoded 8080 native instructions | 3,051 | Reset, IRQ, RST, diagnostics, display, road/pylon, frame scheduling and game logic |
| Inline service parameters | 38 | Original data bytes directly following `RST` and native `CALL` service invocations |
| Named static ROM data | 3,055 | Font glyphs, drawing frames, animation records, road data, steering lookups, strings and padding |
| **Total classified** | **6,144** | Full original parent-set address coverage, `$0000–$17FF` |

The static control-flow scan identified **1,739 native instructions**, with **zero overlapping code/data classifications and zero uncovered bytes** in the original image. This establishes the source reconstruction layout. It does not by itself establish all behavioral contracts of every native branch or table field.

## Original ROM devices

| Original device | CPU addresses | CRC32 |
| --- | --- | --- |
| `zzzaph` | `$0000–$03FF` | `1fa86e1c` |
| `zzzapg` | `$0400–$07FF` | `9639bc6b` |
| `zzzapf` | `$0800–$0BFF` | `adc6ede1` |
| `zzzape` | `$0C00–$0FFF` | `472493d6` |
| `zzzapd` | `$1000–$13FF` | `4c240ee1` |
| `zzzapc` | `$1400–$17FF` | `6e85aeaf` |

All six device CRC32s were checked against the original ZIP entries before generating the source. The source generation also checked that its emitted instruction/data spans preserved every original byte in address order.

## Classified source regions

| Address range | Source interpretation |
| --- | --- |
| `$0000–$001C` | Reset and two interrupt-phase entry vectors; context-save RST |
| `$001D–$0037` | Extended-play values, RST helpers, linked animation data, inline message service |
| `$0038–$0158` | Message display, RAM diagnostics, six-device ROM checksums |
| `$0159–$0185` | Diagnostic lettering and stack-based framebuffer fill |
| `$0186–$0365` | Forty-eight 8×10 display font bitmaps, one row per byte with pixel comments |
| `$0366–$040A` | Native glyph, BCD and impact-text rendering |
| `$040B–$043D` | Linked timed animation descriptors |
| `$043E–$069C` | Five variable-width, variable-height graphic frames with inline pixel rows |
| `$069D–$0A94` | Graphics boundary and native IRQ, steering, road and pylon drawing |
| `$0A95–$0A9C` | Cumulative 1/2/3/4/5/6/7/8-bit masks |
| `$0A9D–$0FA4` | Native drawing animation, main game execution, scoring and string services |
| `$0FA5–$0FDE` | Impact captions, text row screen addresses and scoring constants |
| `$0FDF–$10E5` | Native score/time display, localization, random-state and road decompressor routines |
| `$10E6–$123E` | Packed road curves, steering response and speed/step lookup data |
| `$123F–$17FF` | Four language pointer tables and text; encoded high-bit string terminators |

## Assembly style and source verification

- Native 8080 instructions are written as mnemonics with named branch destinations.
- Functional blocks have headers and blank-line separation.
- Text and word-pointer tables are not disguised as instructions.
- Inline operands after relevant restart/service calls remain in source as data.
- Font and large-graphic rows carry `#` and `.` bit-pattern comments.
- Built binaries must match the original six device SHA-1 values.

### Verification commands

```sh
./build.sh
mame 280zzzap -rompath roms -window -skip_gameinfo
```

**Verification PASS — November 20, 2026 (local user test).** The committed `src/280zzzap.asm` assembled successfully with the repository's zmac v1.3 build script. All six output devices matched their original SHA-1 hashes, `roms/280zzzap.zip` was produced successfully, and the user confirmed that the built game runs in MAME.

| Check | Result |
| --- | --- |
| zmac assembly of complete source | PASS |
| `zzzaph` original SHA-1 | PASS |
| `zzzapg` original SHA-1 | PASS |
| `zzzapf` original SHA-1 | PASS |
| `zzzape` original SHA-1 | PASS |
| `zzzapd` original SHA-1 | PASS |
| `zzzapc` original SHA-1 | PASS |
| ZIP packaging | PASS |
| MAME launch and run | PASS (user-reported) |

Byte-for-byte reconstruction and MAME execution are verified; deeper semantic annotation remains a separate RE task.

## Remaining deep RE

Continue tracing the inner loops and consumers of animation descriptors, road/steering table fields, and scoring constants. Replace address-qualified intermediate branch labels with confirmed intent as each caller and state transition is traced. The source is complete in byte coverage; the semantic audit proceeds routine by routine.
