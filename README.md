# 280-ZZZAP (1976)

**280-ZZZAP** is a 1976 driving arcade game developed by **Dave Nutting Associates (DNA)** and published by **Midway**.

![280-ZZZAP marquee](images/280-zzzap-marquee.jpg)


| Topic | Description |
| --- | --- |
| Native architecture | Reset and frame interrupt vectors, register-preserving RST helpers, native game routines |
| Game engine | Steering, road/pylon data, timing, collisions, score and high-score |
| Graphics and text | Bitmap graphics and localized text in English, German, French and Spanish |
| Hardware | 8080 inputs/outputs, working RAM, framebuffer and sound-board netlist |

## Build

Linux:

```sh
./build.sh
```

Windows:

```bat
build.bat
```

MAME:

```sh
mame 280zzzap -rompath roms -window -skip_gameinfo
```

## Original ROMs: MAME set 1

| Device | CPU addresses | Size | SHA-1 |
| --- | --- | ---: | --- |
| `zzzaph` | `$0000–$03FF` | 1024 | `b9cf16eb037ada73631ed24297e9e3b3bf6ab3cd` |
| `zzzapg` | `$0400–$07FF` | 1024 | `b2e2497e421e79a411d07ebf2eed2bb8dc227003` |
| `zzzapf` | `$0800–$0BFF` | 1024 | `206bf2575696c4b14437f3db37a215ba33211943` |
| `zzzape` | `$0C00–$0FFF` | 1024 | `ae5cf4481ee4b78ca0d2f4d560d295e922aa04a7` |
| `zzzapd` | `$1000–$13FF` | 1024 | `972475f80253bb0d24773a10aec26a12f28e7c23` |
| `zzzapc` | `$1400–$17FF` | 1024 | `ffa6bb84ef1f7c2d72fd26c24bd33aa014aeab7e` |

## Memory organization

| Address range | Use |
| --- | --- |
| `$0000–$17FF` | Six 1 KB program ROM devices |
| `$1800–$1FFF` | Unpopulated ROM window |
| `$2000–$23FF` | 1 KB working RAM: driving state, timers, score, pylon and road tables |
| `$2400–$3FFF` | 7 KB raster video RAM |

![280-ZZZAP Intel 8080 memory map](images/280zzzap-memory-map.svg)

The 8080's I/O instructions address control and sound ports separately from memory. In particular: `IN $00` reads start/coin/gear/pedal, `IN $01` reads steering, and `IN $02` reads DIP switches. Do not treat the text-localization table as a programming-language interpreter.

## Architecture

The ROM starts at `$0000`; interrupt entries at `$0008` and `$0010` feed the shared handler at `$069E`. 

`RST $18` / `RST $20` pair saves and restores registers. 

`RST $30` consumes an inline byte and advances the caller's return address. 

**Execution model: 8080 assembly.** The CPU executes instructions in the six program ROMs. 

Reset initializes the game; interrupt entries at `$0008` and `$0010` enter a common native handler at `$069E`. 

Native routines handle steering, timing, road/pylon generation, graphics, scoring and output. 

`RST` services save/restore registers or consume an inline argument

`SELECT_LOCALE_POINTER` at `$1000` reads DIP-switch bits from input port `$02`, selects one of the four pointer entries at `$123F`, and returns the message-table pointer for English, German, French, or Spanish. 

`DISPLAY_TEXT_BY_LOCALE` handles display of the selected text. This is a data-table lookup, not opcode dispatch or a programming-language selector.


## References

- [280-ZZZAP game logic schematic](docs/280_ZZZap_Game_Logic_(0610-00907A).pdf)
- [280-ZZZAP wiring diagram, December 1, 1976](docs/280_ZZZap_Wiring_Diagram_(12_1_1976).pdf)
- [German-language 280-ZZZAP documentation](docs/280-Zzzap-deutsch-german.pdf)
- [MAME Midway 8080 driver](https://github.com/mamedev/mame/blob/master/src/mame/midw8080/mw8080bw.cpp)
