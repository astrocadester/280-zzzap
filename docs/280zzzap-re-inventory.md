# 280-ZZZAP reverse-engineering inventory

The parent ROM set is `280zzzap`. This inventory records established addresses and definitions to guide the source reconstruction, using the original 6 KB image and the existing architecture audit.

## Parent-set ROM map

| ROM device | CPU address | SHA-1 |
| --- | --- | --- |
| zzzaph | $0000–$03FF | b9cf16eb037ada73631ed24297e9e3b3bf6ab3cd |
| zzzapg | $0400–$07FF | b2e2497e421e79a411d07ebf2eed2bb8dc227003 |
| zzzapf | $0800–$0BFF | 206bf2575696c4b14437f3db37a215ba33211943 |
| zzzape | $0C00–$0FFF | ae5cf4481ee4b78ca0d2f4d560d295e922aa04a7 |
| zzzapd | $1000–$13FF | 972475f80253bb0d24773a10aec26a12f28e7c23 |
| zzzapc | $1400–$17FF | ffa6bb84ef1f7c2d72fd26c24bd33aa014aeab7e |

## Native entry points

| Address | Meaning |
| --- | --- |
| $0000 | Program reset entry |
| $0008 / $0010 | Two IRQ phase vectors |
| $0018 | Register-preserving RST service |
| $0020 | Companion register-restore RST |
| $0030 | Inline-byte operand RST |
| $069E | Shared native IRQ handler |
| $0F78 | Message display selection |
| $0F91 | Inline operand helper called from RST $30 |
| $1000 | Localization lookup based on DIP port $02 |
| $123F | Four locale pointer selections |

## RAM state identified from annotated reconstruction

| Address | Content |
| --- | --- |
| $2020 | Input sample from interrupt |
| $2023 | 0 = attract, 1/2 = game, 3 = extended time |
| $2025–$2028 | Pylon record pointers |
| $2029–$202C | Previous score and high score |
| $203A | Steering value |
| $203D–$203E | BCD player score |
| $2062–$20CF | Pylon table, 22 records × 5 bytes |
| $20D0–$213D | Companion pylon table, 22 records × 5 bytes |
| $2145–$2244 | Road data |
| $2245–$2344 | Companion road data |
| $2400–$3FFF | Video RAM |

## Original ROM text regions

| Address | Data |
| --- | --- |
| $0FA5 | Impact phrases: POW, ZAP, WAM, BAM, ZORK, BANG, BOOM, ZONK |
| $1282 | MAX CURVE 160 MPH |
| $1295 | MAX CURVE 120 MPH |
| $12A7 | MAX CURVE 80 MPH |
| $1360 | DATSUN 280 ZZZAP |
| $143D onward | German localized messages |
| $158A onward | French localized messages |
| $16EC onward | Spanish localized messages |

### Assembly conventions for the RE

Use the original 8080 bytes and the existing project assembler. Prefer descriptive semantic labels and clearly separated routine headers. Keep literal text readable and the encoded terminators byte-exact. For each bitmap, include per-row `#` / `.` pixel comments. Replace raw byte blocks with specifically explained string, word, graphics, structured-record or packed-data representations based on actual consumers. Preserve undocumented fields as numeric values with their usage, not invented names.

The ROM rebuild is complete only once all six device SHA-1s match. The source is not yet present in this branch. The architecture and lineage analysis is in `06-280-ZZZAP-NATIVE-ENGINE-AND-LINEAGE.md` and identifies the native engine, RST services, and localization lookup.
