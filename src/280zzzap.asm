;*******************************************************************************
; 280-ZZZAP (1976)
;*******************************************************************************
; Dave Nutting Associates / Midway — original Intel 8080 arcade ROM.
; MAME set 1: six 1 KB original devices at $0000–$17FF.
; Original ROM bytes are the authority for instructions, data and addresses.
;
; CPU       : Intel 8080
; Build     : project tools/zmac v1.3; six SHA-1 device checks
; Memory    : $2000–$23FF working RAM, $2400–$3FFF display RAM
; Graphics  : bitmap rows annotated left-to-right as bit 7 to bit 0
;*******************************************************************************
 
        ORG $0000

;*******************************************************************************
; RESET / INTERRUPT / RST SERVICES
;*******************************************************************************

; Clear the audio latch and enter the native boot routine.
RESET_ENTRY:
        NOP
        NOP
        XOR A
        OUT ($05),A
        JP BOOT_DIAGNOSTIC_SELECTOR

; First IRQ phase preserves registers and supplies C=0.
IRQ_PHASE_ZERO:
        PUSH AF
        PUSH BC
        PUSH DE
        LD C,$00
        JP IRQ_COMMON_HANDLER

; Second IRQ phase preserves registers and supplies C=1.
IRQ_PHASE_ONE:
        PUSH AF
        PUSH BC
        PUSH DE
        LD C,$01
        JP IRQ_COMMON_HANDLER

; RST $18 saves CPU context using the stack and HL.
RST18_SAVE_CONTEXT:
        EX (SP),HL
        PUSH DE
        PUSH BC
        PUSH AF
        JP (HL)

EXTENDED_PLAY_DIP_SETTINGS:
        DB $25,$30,$20  ; extended-play game settings

; RST $20 restores saved context and returns to the native caller.
RST20_RESTORE_CONTEXT:
        POP HL
        POP AF
        POP BC
        POP DE
        POP HL
        RET

RST20_TRAILING_BYTES:
        DB $35,$00  ; original ROM alignment

RST28_INLINE_WAIT:
        JP RST_WAIT_INLINE_TICKS

INITIAL_FRAME_LINK:
        DB $05  ; frame count
        DW SPRITE_FRAME_02  ; sprite address and next node
        DW $0414

; Read the inline message argument located after the caller's RST instruction.
RST30_INLINE_MESSAGE:
        EX (SP),HL
        LD A,(HL)
        INC HL
        EX (SP),HL
        CALL TEXT_STEP_0F91
        LD (HL),A

UPDATE_BOTTOM_MESSAGES:
        RST $18
        LD HL,$205E
        LD A,(HL)
        INC HL
        OR (HL)
        AND $1F
        JP Z,CLEAR_MESSAGE_BAND
        LD BC,$1DFF
        CALL FILL_SCREEN_BAND
        LD HL,$205E
        LD A,(HL)
        CALL TEXT_STEP_0F5E
        INC HL
        LD A,(HL)
        CALL TEXT_STEP_0F5E
        RST $20

ERASE_MESSAGE_BAND:
        LD BC,$1DFF
        JP FILL_SCREEN_BAND

CLEAR_MESSAGE_BAND:
        LD BC,$1D00
        CALL FILL_SCREEN_BAND
        RST $20

;*******************************************************************************
; RAM AND ROM DIAGNOSTICS
;*******************************************************************************

; Choose the hardware diagnostic or the game startup according to DIP bits.
BOOT_DIAGNOSTIC_SELECTOR:
        IN A,($02)
        AND $0C
        CP $04
        JP NZ,GAME_INITIALIZE
        LD B,$01
        LD DE,$0000

RAM_TEST_START:
        LD HL,$2000

RAM_TEST_WRITE_READ:
        OUT ($07),A
        LD (HL),B
        LD A,(HL)
        XOR B
        JP Z,RAM_TEST_NEXT_ADDRESS
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,RAM_TEST_ODD_ERROR
        OR D
        LD D,A
        JP RAM_TEST_NEXT_ADDRESS

RAM_TEST_ODD_ERROR:
        OR E
        LD E,A

RAM_TEST_NEXT_ADDRESS:
        INC HL
        LD A,H
        CP $40
        JP NZ,RAM_TEST_WRITE_READ

RAM_TEST_REVERSE_SWEEP:
        OUT ($07),A
        DEC HL
        LD A,H
        CP $1F
        JP Z,RAM_TEST_FINAL_SWEEP
        LD A,(HL)
        XOR B
        JP Z,RAM_TEST_COMPLEMENT
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,RAM_TEST_REVERSE_ODD_ERROR
        OR D
        LD D,A
        JP RAM_TEST_COMPLEMENT

RAM_TEST_REVERSE_ODD_ERROR:
        OR E
        LD E,A

RAM_TEST_COMPLEMENT:
        LD A,B
        CPL
        LD (HL),A
        XOR (HL)
        JP Z,RAM_TEST_REVERSE_SWEEP
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,RAM_TEST_COMPLEMENT_ODD_ERROR
        OR D
        LD D,A
        JP RAM_TEST_REVERSE_NEXT

RAM_TEST_COMPLEMENT_ODD_ERROR:
        OR E
        LD E,A

RAM_TEST_REVERSE_NEXT:
        JP RAM_TEST_REVERSE_SWEEP

RAM_TEST_FINAL_SWEEP:
        OUT ($07),A
        INC HL
        LD A,H
        CP $40
        JP Z,RAM_TEST_NEXT_PATTERN
        LD A,B
        CPL
        XOR (HL)
        JP Z,RAM_TEST_CLEAR_NEXT
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,RAM_TEST_FINAL_ODD_ERROR
        OR D
        LD D,A
        JP RAM_TEST_CLEAR_NEXT

RAM_TEST_FINAL_ODD_ERROR:
        OR E
        LD E,A

RAM_TEST_CLEAR_NEXT:
        XOR A
        LD (HL),A
        JP RAM_TEST_FINAL_SWEEP

RAM_TEST_NEXT_PATTERN:
        LD A,B
        RLCA
        LD B,A
        JP NC,RAM_TEST_START
        LD A,D
        OR E
        JP Z,ROM_CHECKSUM_BEGIN
        EX DE,HL
        LD SP,HL
        LD DE,$2000
        LD B,$00

RAM_TEST_FAILURE_LINE:
        LD HL,$0000
        ADD HL,SP
        LD C,$10

RAM_TEST_FAILURE_PIXEL:
        XOR A
        ADD HL,HL
        JP C,RAM_TEST_FAILURE_WRITE
        CPL

RAM_TEST_FAILURE_WRITE:
        LD (DE),A
        INC DE
        LD A,$18
        LD (DE),A
        INC DE
        DEC C
        JP NZ,RAM_TEST_FAILURE_PIXEL
        DEC B
        JP NZ,RAM_TEST_FAILURE_LINE
        JP DIAGNOSTIC_FAILURE_HALT

; Calculate checksums for each of the six original ROM devices.
ROM_CHECKSUM_BEGIN:
        LD SP,$2400
        LD HL,$280C
        PUSH HL
        LD HL,$0000
        LD DE,$0159

ROM_CHECKSUM_NEXT_DEVICE:
        LD BC,$0400
        XOR A

ROM_CHECKSUM_NEXT_BYTE:
        ADD A,(HL)
        OUT ($07),A
        INC HL
        DEC C
        JP NZ,ROM_CHECKSUM_NEXT_BYTE
        DEC B
        JP NZ,ROM_CHECKSUM_NEXT_BYTE
        AND A
        JP Z,ROM_CHECKSUM_ADVANCE_DEVICE
        LD A,(DE)
        EX (SP),HL
        EX DE,HL
        PUSH BC
        CALL DRAW_GLYPH
        POP BC
        EX DE,HL
        EX (SP),HL

ROM_CHECKSUM_ADVANCE_DEVICE:
        INC DE
        LD A,H
        CP $18
        JP NZ,ROM_CHECKSUM_NEXT_DEVICE
        POP HL
        LD A,L
        CP $0C
        JP Z,RESET_ENTRY

DIAGNOSTIC_FAILURE_HALT:
        OUT ($07),A
        JP DIAGNOSTIC_FAILURE_HALT

ROM_TEST_CHIP_LETTERS:
        DB "HGFEDC"  ; ROM diagnostic chip letters H G F E D C

; Clear the framebuffer using the CPU stack for block writes.
CLEAR_VIDEO_RAM:
        LD BC,$E000

FILL_SCREEN_BAND:
        LD DE,$4000

FILL_SCREEN_WITH_STACK:
        LD HL,$0000
        ADD HL,SP
        EX DE,HL
        DI
        LD SP,HL
        EX DE,HL
        LD A,B
        LD B,C

FILL_SCREEN_SIXTEEN_WORDS:
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        DEC A
        JP NZ,FILL_SCREEN_SIXTEEN_WORDS
        LD SP,HL
        EI
        RET

;*******************************************************************************
; DISPLAY FONT: 48 GLYPHS WITH INLINE PIXEL ROWS
;*******************************************************************************

FONT_BASE:

; 8x10 character bitmap for code $30
FONT_CHAR_30:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $31
FONT_CHAR_31:
        DB $18  ; ...##...
        DB $1C  ; ...###..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $3C  ; ..####..

; 8x10 character bitmap for code $32
FONT_CHAR_32:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $60  ; .##.....
        DB $7C  ; .#####..
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; 8x10 character bitmap for code $33
FONT_CHAR_33:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $60  ; .##.....
        DB $38  ; ..###...
        DB $78  ; .####...
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $34
FONT_CHAR_34:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....

; 8x10 character bitmap for code $35
FONT_CHAR_35:
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $36
FONT_CHAR_36:
        DB $3C  ; ..####..
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $37
FONT_CHAR_37:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $70  ; .###....
        DB $30  ; ..##....
        DB $38  ; ..###...
        DB $18  ; ...##...
        DB $1C  ; ...###..
        DB $0C  ; ....##..
        DB $0C  ; ....##..

; 8x10 character bitmap for code $38
FONT_CHAR_38:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $39
FONT_CHAR_39:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7C  ; .#####..
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $7C  ; .#####..
        DB $3C  ; ..####..

; 8x10 character bitmap for code $3A
FONT_CHAR_3A:
        DB $00  ; ........
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $00  ; ........

; 8x10 character bitmap for code $3B
FONT_CHAR_3B:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $FF  ; ########
        DB $FF  ; ########

; 8x10 character bitmap for code $3C
FONT_CHAR_3C:
        DB $7F  ; .#######
        DB $7F  ; .#######
        DB $7F  ; .#######
        DB $7F  ; .#######
        DB $7F  ; .#######
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $FF  ; ########
        DB $FF  ; ########

; 8x10 character bitmap for code $3D
FONT_CHAR_3D:
        DB $1F  ; ...#####
        DB $7F  ; .#######
        DB $1F  ; ...#####
        DB $DF  ; ##.#####
        DB $1F  ; ...#####
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $FF  ; ########
        DB $FF  ; ########

; 8x10 character bitmap for code $3E
FONT_CHAR_3E:
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $18  ; ...##...
        DB $18  ; ...##...

; 8x10 character bitmap for code $3F
FONT_CHAR_3F:
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $00  ; ........
        DB $00  ; ........
        DB $18  ; ...##...
        DB $18  ; ...##...

; 8x10 character bitmap for code $40
FONT_CHAR_40:
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........

; 8x10 character bitmap for code $41
FONT_CHAR_41:
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; 8x10 character bitmap for code $42
FONT_CHAR_42:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.

; 8x10 character bitmap for code $43
FONT_CHAR_43:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $44
FONT_CHAR_44:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.

; 8x10 character bitmap for code $45
FONT_CHAR_45:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; 8x10 character bitmap for code $46
FONT_CHAR_46:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.

; 8x10 character bitmap for code $47
FONT_CHAR_47:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $76  ; .###.##.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $48
FONT_CHAR_48:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; 8x10 character bitmap for code $49
FONT_CHAR_49:
        DB $3C  ; ..####..
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $3C  ; ..####..

; 8x10 character bitmap for code $4A
FONT_CHAR_4A:
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $4B
FONT_CHAR_4B:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $76  ; .###.##.
        DB $3E  ; ..#####.
        DB $1E  ; ...####.
        DB $1E  ; ...####.
        DB $3E  ; ..#####.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; 8x10 character bitmap for code $4C
FONT_CHAR_4C:
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; 8x10 character bitmap for code $4D
FONT_CHAR_4D:
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $FF  ; ########
        DB $FF  ; ########
        DB $DB  ; ##.##.##
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $C3  ; ##....##

; 8x10 character bitmap for code $4E
FONT_CHAR_4E:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $6E  ; .##.###.
        DB $6E  ; .##.###.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $76  ; .###.##.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; 8x10 character bitmap for code $4F
FONT_CHAR_4F:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $50
FONT_CHAR_50:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.

; 8x10 character bitmap for code $51
FONT_CHAR_51:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $5C  ; .#.###..

; 8x10 character bitmap for code $52
FONT_CHAR_52:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; 8x10 character bitmap for code $53
FONT_CHAR_53:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7C  ; .#####..
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $54
FONT_CHAR_54:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...

; 8x10 character bitmap for code $55
FONT_CHAR_55:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; 8x10 character bitmap for code $56
FONT_CHAR_56:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...

; 8x10 character bitmap for code $57
FONT_CHAR_57:
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $DB  ; ##.##.##
        DB $FF  ; ########
        DB $FF  ; ########
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $C3  ; ##....##
        DB $C3  ; ##....##

; 8x10 character bitmap for code $58
FONT_CHAR_58:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; 8x10 character bitmap for code $59
FONT_CHAR_59:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...

; 8x10 character bitmap for code $5A
FONT_CHAR_5A:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $70  ; .###....
        DB $38  ; ..###...
        DB $1C  ; ...###..
        DB $0E  ; ....###.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; 8x10 character bitmap for code $5B
FONT_CHAR_5B:
        DB $11  ; ...#...#
        DB $55  ; .#.#.#.#
        DB $55  ; .#.#.#.#
        DB $55  ; .#.#.#.#
        DB $11  ; ...#...#
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $F7  ; ####.###
        DB $F7  ; ####.###

; 8x10 character bitmap for code $5C
FONT_CHAR_5C:
        DB $11  ; ...#...#
        DB $57  ; .#.#.###
        DB $51  ; .#.#...#
        DB $5D  ; .#.###.#
        DB $11  ; ...#...#
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $F7  ; ####.###
        DB $F7  ; ####.###

; 8x10 character bitmap for code $5D
FONT_CHAR_5D:
        DB $15  ; ...#.#.#
        DB $55  ; .#.#.#.#
        DB $51  ; .#.#...#
        DB $57  ; .#.#.###
        DB $17  ; ...#.###
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $F7  ; ####.###
        DB $F7  ; ####.###

; 8x10 character bitmap for code $5E
FONT_CHAR_5E:
        DB $11  ; ...#...#
        DB $5D  ; .#.###.#
        DB $51  ; .#.#...#
        DB $55  ; .#.#.#.#
        DB $11  ; ...#...#
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $F7  ; ####.###
        DB $F7  ; ####.###

; 8x10 character bitmap for code $5F
FONT_CHAR_5F:
        DB $11  ; ...#...#
        DB $55  ; .#.#.#.#
        DB $51  ; .#.#...#
        DB $55  ; .#.#.#.#
        DB $11  ; ...#...#
        DB $FF  ; ########
        DB $77  ; .###.###
        DB $77  ; .###.###
        DB $F7  ; ####.###
        DB $F7  ; ####.###

;*******************************************************************************
; NATIVE CHARACTER AND NUMERIC RENDERING
;*******************************************************************************

DRAW_BCD_DIGITS:
        LD A,(HL)
        AND $F0
        JP NZ,DRAW_STEP_0375
        LD A,$40
        CALL DRAW_GLYPH
        JP DRAW_LOAD_037C

DRAW_NEXT_DIGIT:
        LD A,(HL)

DRAW_STEP_0375:
        RLCA
        RLCA
        RLCA
        RLCA
        CALL DRAW_MASK_037D

DRAW_LOAD_037C:
        LD A,(HL)

DRAW_MASK_037D:
        AND $0F
        ADD A,$30

DRAW_GLYPH:
        AND $7F
        CP $30
        LD B,$00
        JP NC,DRAW_GLYPH_PIXEL_ROWS
        LD C,A
        EX DE,HL
        ADD HL,BC
        EX DE,HL
        RET

DRAW_GLYPH_PIXEL_ROWS:
        PUSH HL
        PUSH DE
        CALL FIND_FONT_CHARACTER
        LD A,H
        CP $3B
        LD A,$00
        JP C,DRAW_LOAD_039D
        CPL

DRAW_LOAD_039D:
        LD C,A

DRAW_STEP_039E:
        PUSH BC
        LD A,(DE)
        INC DE
        XOR C
        LD (HL),A
        LD BC,$0020
        ADD HL,BC
        POP BC
        DEC B
        JP NZ,DRAW_STEP_039E
        POP DE
        INC DE
        POP HL
        RET

DRAW_LOAD_03B0:
        LD B,$00

FIND_FONT_CHARACTER:
        SUB $30
        LD C,A
        LD H,B
        LD L,C
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,BC
        ADD HL,BC
        LD BC,$0186
        ADD HL,BC
        LD B,$0A
        EX DE,HL
        RET

DISPLAY_CRASH_CAPTION:
        CALL ROAD_CODEC_STEP_1088
        AND $1C
        LD C,A
        LD B,$00
        LD HL,$0FA5
        ADD HL,BC
        LD DE,$2800
        LD B,$04

DRAW_CALL_03D5:
        CALL DRAW_IMPACT_GLYPH
        LD A,E
        ADD A,$08
        LD E,A
        INC HL
        DEC B
        JP NZ,DRAW_CALL_03D5
        RET

DRAW_IMPACT_GLYPH:
        LD A,(HL)
        RST $18
        CALL DRAW_LOAD_03B0

DRAW_STEP_03E7:
        PUSH HL
        LD A,(DE)
        INC DE

DRAW_STEP_03EA:
        RRA
        CALL C,DRAW_STEP_03FA
        INC HL
        AND A
        JP NZ,DRAW_STEP_03EA
        POP HL
        INC H
        DEC B
        JP NZ,DRAW_STEP_03E7
        RST $20

DRAW_STEP_03FA:
        PUSH HL
        PUSH DE
        PUSH BC
        PUSH AF
        LD BC,$08FF
        LD DE,$0020

DRAW_LOAD_0404:
        LD (HL),C
        ADD HL,DE
        DEC B
        JP NZ,DRAW_LOAD_0404
        RST $20

;*******************************************************************************
; LINKED ANIMATED DRAWING RECORDS
;*******************************************************************************

ANIMATION_LINKED_RECORDS:
        DB $6D,$FF  ; duration and step
        DW $0419  ; next frame descriptor
        DB $05  ; frame count
        DW SPRITE_FRAME_01  ; sprite data and next record
        DW INITIAL_FRAME_LINK

; Timed animation linked node at $0414
ANIMATION_NODE_414:
        DB $05  ; frame count
        DW SPRITE_FRAME_03  ; sprite address; linked record
        DW $040F

; Timed animation linked node at $0419
ANIMATION_NODE_419:
        DB $3B,$00  ; duration and step
        DW $0427  ; next frame descriptor
        DB $13  ; frame count
        DW SPRITE_FRAME_04  ; sprite data and next record
        DW $0422

; Timed animation linked node at $0422
ANIMATION_NODE_422:
        DB $27  ; frame count
        DW SPRITE_FRAME_05  ; sprite address; linked record
        DW $0422

; Timed animation linked node at $0427
ANIMATION_NODE_427:
        DB $36,$FE,$35,$04  ; short animation node

; Timed animation linked node at $042B
ANIMATION_NODE_42B:
        DB $03  ; frame count
        DW SPRITE_FRAME_01  ; sprite address; linked record
        DW $0430

; Timed animation linked node at $0430
ANIMATION_NODE_430:
        DB $03  ; frame count
        DW SPRITE_FRAME_02  ; sprite address; linked record
        DW $0439

; Timed animation linked node at $0435
ANIMATION_NODE_435:
        DB $7F,$00,$00,$00  ; short animation node

; Timed animation linked node at $0439
ANIMATION_NODE_439:
        DB $03  ; frame count
        DW SPRITE_FRAME_03  ; sprite address; linked record
        DW $042B

;*******************************************************************************
; FIVE LARGE BITMAP FRAMES
;*******************************************************************************

SPRITE_FRAME_01:
; Large sprite 1: 3 bytes/row × 38 rows
        DB $03,$26  ; width bytes, height rows
        DW RESET_ENTRY  ; screen placement offset
        DB $80,$01,$00  ; #....... .......# ........
        DB $80,$07,$00  ; #....... .....### ........
        DB $E0,$0F,$00  ; ###..... ....#### ........
        DB $BC,$1F,$00  ; #.####.. ...##### ........
        DB $E6,$1B,$00  ; ###..##. ...##.## ........
        DB $67,$1B,$00  ; .##..### ...##.## ........
        DB $7F,$0F,$03  ; .####### ....#### ......##
        DB $EE,$81,$07  ; ###.###. #......# .....###
        DB $3C,$C0,$0F  ; ..####.. ##...... ....####
        DB $10,$FC,$1F  ; ...#.... ######.. ...#####
        DB $10,$C0,$0F  ; ...#.... ##...... ....####
        DB $20,$40,$0F  ; ..#..... .#...... ....####
        DB $40,$E0,$0F  ; .#...... ###..... ....####
        DB $80,$F0,$0F  ; #....... ####.... ....####
        DB $80,$C1,$0F  ; #....... ##.....# ....####
        DB $80,$C1,$07  ; #....... ##.....# .....###
        DB $00,$03,$03  ; ........ ......## ......##
        DB $00,$83,$07  ; ........ #.....## .....###
        DB $00,$FE,$3F  ; ........ #######. ..######
        DB $00,$FE,$7F  ; ........ #######. .#######
        DB $00,$E0,$EF  ; ........ ###..... ###.####
        DB $00,$80,$CF  ; ........ #....... ##..####
        DB $00,$80,$CF  ; ........ #....... ##..####
        DB $00,$80,$CF  ; ........ #....... ##..####
        DB $00,$80,$CF  ; ........ #....... ##..####
        DB $00,$80,$DF  ; ........ #....... ##.#####
        DB $00,$C0,$DF  ; ........ ##...... ##.#####
        DB $00,$C0,$1F  ; ........ ##...... ...#####
        DB $00,$E0,$1F  ; ........ ###..... ...#####
        DB $00,$F0,$0E  ; ........ ####.... ....###.
        DB $00,$70,$0E  ; ........ .###.... ....###.
        DB $00,$38,$0E  ; ........ ..###... ....###.
        DB $00,$38,$1C  ; ........ ..###... ...###..
        DB $00,$30,$38  ; ........ ..##.... ..###...
        DB $00,$70,$70  ; ........ .###.... .###....
        DB $00,$60,$60  ; ........ .##..... .##.....
        DB $00,$60,$60  ; ........ .##..... .##.....
        DB $00,$78,$78  ; ........ .####... .####...

SPRITE_FRAME_02:
; Large sprite 2: 3 bytes/row × 37 rows
        DB $03,$25  ; width bytes, height rows
        DW RST20_RESTORE_CONTEXT  ; screen placement offset
        DB $80,$01,$00  ; #....... .......# ........
        DB $80,$07,$00  ; #....... .....### ........
        DB $E0,$0F,$00  ; ###..... ....#### ........
        DB $BC,$19,$00  ; #.####.. ...##..# ........
        DB $F6,$19,$00  ; ####.##. ...##..# ........
        DB $FF,$1F,$03  ; ######## ...##### ......##
        DB $EF,$8F,$07  ; ###.#### #...#### .....###
        DB $EE,$C1,$0F  ; ###.###. ##.....# ....####
        DB $3C,$FC,$1F  ; ..####.. ######.. ...#####
        DB $10,$C0,$0F  ; ...#.... ##...... ....####
        DB $20,$40,$0F  ; ..#..... .#...... ....####
        DB $40,$E0,$0F  ; .#...... ###..... ....####
        DB $80,$F0,$0F  ; #....... ####.... ....####
        DB $80,$C1,$0F  ; #....... ##.....# ....####
        DB $80,$C1,$07  ; #....... ##.....# .....###
        DB $00,$03,$03  ; ........ ......## ......##
        DB $00,$83,$07  ; ........ #.....## .....###
        DB $00,$FE,$0F  ; ........ #######. ....####
        DB $00,$FE,$0F  ; ........ #######. ....####
        DB $00,$E0,$0F  ; ........ ###..... ....####
        DB $00,$80,$0F  ; ........ #....... ....####
        DB $00,$80,$0F  ; ........ #....... ....####
        DB $00,$80,$0F  ; ........ #....... ....####
        DB $00,$80,$0F  ; ........ #....... ....####
        DB $00,$80,$1F  ; ........ #....... ...#####
        DB $00,$80,$1F  ; ........ #....... ...#####
        DB $00,$80,$1F  ; ........ #....... ...#####
        DB $00,$80,$1F  ; ........ #....... ...#####
        DB $00,$80,$0F  ; ........ #....... ....####
        DB $00,$80,$07  ; ........ #....... .....###
        DB $00,$80,$07  ; ........ #....... .....###
        DB $00,$80,$07  ; ........ #....... .....###
        DB $00,$80,$03  ; ........ #....... ......##
        DB $00,$00,$03  ; ........ ........ ......##
        DB $00,$00,$03  ; ........ ........ ......##
        DB $00,$00,$03  ; ........ ........ ......##
        DB $00,$C0,$03  ; ........ ##...... ......##

SPRITE_FRAME_03:
; Large sprite 3: 3 bytes/row × 38 rows
        DB $03,$26  ; width bytes, height rows
        DW RESET_ENTRY  ; screen placement offset
        DB $80,$01,$00  ; #....... .......# ........
        DB $80,$07,$00  ; #....... .....### ........
        DB $E0,$0D,$00  ; ###..... ....##.# ........
        DB $F8,$1D,$00  ; #####... ...###.# ........
        DB $9E,$1F,$00  ; #..####. ...##### ........
        DB $9F,$1B,$00  ; #..##### ...##.## ........
        DB $FF,$0F,$03  ; ######## ....#### ......##
        DB $F6,$81,$07  ; ####.##. #......# .....###
        DB $3C,$C0,$0F  ; ..####.. ##...... ....####
        DB $10,$FC,$1F  ; ...#.... ######.. ...#####
        DB $10,$C0,$0F  ; ...#.... ##...... ....####
        DB $20,$40,$0F  ; ..#..... .#...... ....####
        DB $40,$E0,$0F  ; .#...... ###..... ....####
        DB $80,$F0,$0F  ; #....... ####.... ....####
        DB $80,$C1,$0F  ; #....... ##.....# ....####
        DB $80,$C1,$07  ; #....... ##.....# .....###
        DB $00,$03,$03  ; ........ ......## ......##
        DB $00,$83,$07  ; ........ #.....## .....###
        DB $00,$FE,$0F  ; ........ #######. ....####
        DB $00,$FE,$1F  ; ........ #######. ...#####
        DB $00,$E0,$3F  ; ........ ###..... ..######
        DB $00,$80,$6F  ; ........ #....... .##.####
        DB $00,$80,$6F  ; ........ #....... .##.####
        DB $00,$80,$6F  ; ........ #....... .##.####
        DB $00,$80,$6F  ; ........ #....... .##.####
        DB $00,$80,$3F  ; ........ #....... ..######
        DB $00,$80,$1F  ; ........ #....... ...#####
        DB $00,$80,$1F  ; ........ #....... ...#####
        DB $00,$C0,$1F  ; ........ ##...... ...#####
        DB $00,$C0,$1F  ; ........ ##...... ...#####
        DB $00,$C0,$07  ; ........ ##...... .....###
        DB $00,$E0,$03  ; ........ ###..... ......##
        DB $00,$E0,$19  ; ........ ###..... ...##..#
        DB $00,$E0,$1C  ; ........ ###..... ...###..
        DB $00,$60,$38  ; ........ .##..... ..###...
        DB $00,$60,$70  ; ........ .##..... .###....
        DB $00,$60,$60  ; ........ .##..... .##.....
        DB $00,$78,$78  ; ........ .####... .####...

SPRITE_FRAME_04:
; Large sprite 4: 4 bytes/row × 31 rows
        DB $04,$1F  ; width bytes, height rows
        DW $00DF  ; screen placement offset
        DB $00,$00,$30,$00  ; ........ ........ ..##.... ........
        DB $00,$00,$78,$00  ; ........ ........ .####... ........
        DB $00,$00,$FC,$00  ; ........ ........ ######.. ........
        DB $00,$C0,$FF,$01  ; ........ ##...... ######## .......#
        DB $33,$03,$FC,$00  ; ..##..## ......## ######.. ........
        DB $33,$03,$F4,$00  ; ..##..## ......## ####.#.. ........
        DB $CC,$00,$FE,$00  ; ##..##.. ........ #######. ........
        DB $CC,$00,$FF,$00  ; ##..##.. ........ ######## ........
        DB $33,$03,$FC,$00  ; ..##..## ......## ######.. ........
        DB $33,$03,$7C,$00  ; ..##..## ......## .#####.. ........
        DB $CC,$00,$30,$00  ; ##..##.. ........ ..##.... ........
        DB $CC,$00,$F8,$00  ; ##..##.. ........ #####... ........
        DB $FF,$FF,$FF,$1F  ; ######## ######## ######## ...#####
        DB $00,$F0,$FF,$3F  ; ........ ####.... ######## ..######
        DB $00,$00,$FF,$70  ; ........ ........ ######## .###....
        DB $00,$00,$FC,$E0  ; ........ ........ ######.. ###.....
        DB $00,$00,$FC,$C0  ; ........ ........ ######.. ##......
        DB $00,$00,$F8,$81  ; ........ ........ #####... #......#
        DB $00,$00,$F8,$81  ; ........ ........ #####... #......#
        DB $00,$00,$F8,$81  ; ........ ........ #####... #......#
        DB $00,$00,$FC,$03  ; ........ ........ ######.. ......##
        DB $00,$00,$FC,$03  ; ........ ........ ######.. ......##
        DB $00,$00,$DE,$03  ; ........ ........ ##.####. ......##
        DB $00,$00,$8E,$03  ; ........ ........ #...###. ......##
        DB $00,$00,$07,$07  ; ........ ........ .....### .....###
        DB $00,$80,$03,$0E  ; ........ #....... ......## ....###.
        DB $00,$80,$01,$FC  ; ........ #....... .......# ######..
        DB $00,$80,$01,$F8  ; ........ #....... .......# #####...
        DB $00,$80,$01,$80  ; ........ #....... .......# #.......
        DB $00,$80,$01,$80  ; ........ #....... .......# #.......
        DB $00,$E0,$01,$80  ; ........ ###..... .......# #.......

SPRITE_FRAME_05:
; Large sprite 5: 4 bytes/row × 31 rows
        DB $04,$1F  ; width bytes, height rows
        DW $00DF  ; screen placement offset
        DB $9F,$0F,$30,$00  ; #..##### ....#### ..##.... ........
        DB $93,$0D,$78,$00  ; #..#..## ....##.# .####... ........
        DB $83,$0D,$FC,$00  ; #.....## ....##.# ######.. ........
        DB $83,$CD,$FF,$01  ; #.....## ##..##.# ######## .......#
        DB $9B,$0D,$FC,$00  ; #..##.## ....##.# ######.. ........
        DB $93,$0D,$F4,$00  ; #..#..## ....##.# ####.#.. ........
        DB $9F,$0F,$FE,$00  ; #..##### ....#### #######. ........
        DB $00,$00,$FC,$00  ; ........ ........ ######.. ........
        DB $00,$20,$F8,$00  ; ........ ..#..... #####... ........
        DB $00,$80,$7C,$00  ; ........ #....... .#####.. ........
        DB $00,$00,$30,$00  ; ........ ........ ..##.... ........
        DB $00,$00,$F8,$00  ; ........ ........ #####... ........
        DB $FF,$FF,$FF,$1F  ; ######## ######## ######## ...#####
        DB $33,$E3,$FF,$3F  ; ..##..## ###...## ######## ..######
        DB $33,$03,$FF,$70  ; ..##..## ......## ######## .###....
        DB $CC,$00,$FC,$E0  ; ##..##.. ........ ######.. ###.....
        DB $CC,$00,$FC,$C0  ; ##..##.. ........ ######.. ##......
        DB $33,$03,$F8,$81  ; ..##..## ......## #####... #......#
        DB $33,$03,$F8,$81  ; ..##..## ......## #####... #......#
        DB $CC,$00,$F8,$81  ; ##..##.. ........ #####... #......#
        DB $CC,$00,$FC,$03  ; ##..##.. ........ ######.. ......##
        DB $00,$00,$FC,$03  ; ........ ........ ######.. ......##
        DB $00,$00,$DE,$03  ; ........ ........ ##.####. ......##
        DB $00,$00,$8E,$03  ; ........ ........ #...###. ......##
        DB $00,$00,$07,$07  ; ........ ........ .....### .....###
        DB $00,$80,$03,$0E  ; ........ #....... ......## ....###.
        DB $00,$80,$01,$FC  ; ........ #....... .......# ######..
        DB $00,$80,$01,$F8  ; ........ #....... .......# #####...
        DB $00,$80,$01,$80  ; ........ #....... .......# #.......
        DB $00,$80,$01,$80  ; ........ #....... .......# #.......
        DB $00,$E0,$01,$80  ; ........ ###..... .......# #.......

SPRITE_TRAILING_BYTE:
        DB $E0  ; last graphics byte

;*******************************************************************************
; INTERRUPT AND NATIVE ROAD ENGINE
;*******************************************************************************

; Dispatch frame service after reading cabinet inputs.
IRQ_COMMON_HANDLER:
        PUSH HL
        IN A,($00)
        LD B,A
        IN A,($00)
        XOR B
        AND $40
        JP NZ,IRQ_GAME_PHASE_DISPATCH
        LD A,B
        LD HL,$2020
        XOR (HL)
        LD (HL),B
        AND $40
        JP Z,IRQ_GAME_PHASE_DISPATCH
        LD A,B
        AND $40
        JP NZ,IRQ_GAME_PHASE_DISPATCH
        INC HL
        LD (HL),$01

IRQ_GAME_PHASE_DISPATCH:
        LD HL,$2024
        LD A,(HL)
        XOR C
        JP NZ,IRQ_RESTORE_REGISTERS
        LD A,(HL)
        LD HL,$06D2
        PUSH HL
        AND A
        JP NZ,GAME_FRAME_ADVANCE
        JP DRIVING_FRAME_UPDATE

ROAD_LOAD_06D2:
        LD HL,$2024
        LD A,(HL)
        INC A
        AND $01
        LD (HL),A

IRQ_RESTORE_REGISTERS:
        POP HL
        POP DE
        POP BC
        POP AF
        EI
        RET

DRIVING_FRAME_UPDATE:
        LD A,($2022)
        AND A
        JP M,ANIM_CALL_0A9D
        RET Z
        RRCA
        JP NC,ROAD_LOAD_0831
        LD HL,($2027)
        CALL PYLON_LOAD_09C9
        CALL PYLON_LOAD_09C9
        CALL PYLON_LOAD_09C9
        CALL PYLON_LOAD_09C9
        CALL PYLON_LOAD_09C9
        CALL PYLON_LOAD_09C9
        LD BC,$0020
        CALL PYLON_LOAD_09E5
        CALL PYLON_LOAD_09E5
        CALL PYLON_LOAD_09E5
        CALL PYLON_LOAD_09E5
        CALL PYLON_LOAD_09E5
        CALL PYLON_LOAD_09E5
        LD HL,($2025)
        CALL PYLON_DRAW_MASKED
        CALL PYLON_DRAW_MASKED
        CALL PYLON_DRAW_MASKED
        CALL PYLON_DRAW_MASKED
        CALL PYLON_DRAW_MASKED
        CALL PYLON_DRAW_MASKED
        CALL PYLON_LOAD_0A33
        CALL PYLON_LOAD_0A33
        CALL PYLON_LOAD_0A33
        CALL PYLON_LOAD_0A33
        CALL PYLON_LOAD_0A33
        CALL PYLON_LOAD_0A33
        CALL PYLON_POSITION_UPDATE
        LD A,($213E)
        LD HL,$2143
        DEC (HL)
        JP P,ROAD_LOAD_076D
        LD (HL),$03
        LD HL,$213E
        LD A,(HL)
        INC HL
        CP (HL)
        JP Z,ROAD_LOAD_076D
        JP C,ROAD_LOAD_0766
        CP $04
        JP NC,ROAD_STEP_0761
        XOR A
        JP ROAD_DECREMENT_076B

ROAD_STEP_0761:
        SUB $04
        JP ROAD_DECREMENT_076B

ROAD_LOAD_0766:
        LD E,A
        LD A,($205A)
        ADD A,E

ROAD_DECREMENT_076B:
        DEC HL
        LD (HL),A

ROAD_LOAD_076D:
        LD E,A
        LD D,$00
        LD HL,($2047)
        LD A,H
        AND A
        JP Z,ROAD_LOAD_077C
        ADD HL,DE
        LD ($2047),HL

ROAD_LOAD_077C:
        LD HL,($2049)
        LD A,H
        AND A
        JP Z,ROAD_STEP_0788
        ADD HL,DE
        LD ($2049),HL

ROAD_STEP_0788:
        EX DE,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        EX DE,HL
        LD HL,($203B)
        ADD HL,DE
        LD ($203B),HL
        LD A,H
        CPL
        AND $1F
        ADD A,$40
        LD ($2003),A
        LD C,D
        LD D,$00
        LD A,($2037)
        CALL STEERING_LOOKUP_CURVE
        PUSH AF
        LD A,B
        LD ($2002),A
        LD A,($2022)
        XOR $03
        JP Z,ROAD_STEP_0830
        LD A,($213E)
        AND A
        JP Z,ROAD_STEP_0830
        LD A,($2037)
        LD B,A
        CALL STEERING_MAGNITUDE_SIGN
        RRCA
        RRCA
        RRCA
        AND $06
        CPL
        INC A
        ADD A,$0B
        CP C
        JP NC,ROAD_STEP_07E8
        CPL
        INC A
        ADD A,C
        INC A
        RRCA
        AND $03
        LD C,A
        LD ($2141),A
        POP AF
        LD A,B
        LD B,D
        AND A
        JP P,ROAD_LOAD_0801
        LD A,C
        CPL
        INC A
        LD C,A
        JP ROAD_CALCULATE_POSITION

ROAD_STEP_07E8:
        XOR A
        LD ($2141),A
        LD A,C
        RRCA
        AND $07
        ADD A,C
        LD A,C
        LD A,($203A)
        CALL STEERING_LOOKUP_CURVE
        LD B,D
        POP DE
        ADD A,D
        LD C,A
        JP P,ROAD_LOAD_0801

ROAD_CALCULATE_POSITION:
        LD B,$FF

ROAD_LOAD_0801:
        LD HL,($2000)
        ADD HL,BC
        LD ($2000),HL
        LD A,H
        AND A
        JP Z,ROAD_LOAD_0822
        LD A,($2022)
        XOR $05
        JP Z,ROAD_LOAD_081A
        LD HL,$2022
        INC (HL)
        RET

ROAD_LOAD_081A:
        LD A,H
        CPL
        LD L,A
        LD H,$00
        LD ($2000),HL

ROAD_LOAD_0822:
        LD A,L
        CALL STEERING_MAGNITUDE_SIGN
        CP $28
        LD A,H
        ADC A,A
        LD ($2140),A
        JP ROAD_LOAD_0831

ROAD_STEP_0830:
        POP AF

ROAD_LOAD_0831:
        LD HL,$2045
        IN A,($00)
        LD (HL),A
        INC HL
        IN A,($01)
        LD (HL),A
        CALL SOUND_TIMER_UPDATE
        LD HL,$203F
        CALL ROAD_LOAD_0849
        INC HL
        CALL ROAD_LOAD_0849
        INC HL

ROAD_LOAD_0849:
        LD A,(HL)
        AND A
        RET Z
        DEC (HL)
        RET

SOUND_TIMER_UPDATE:
        LD HL,$202E
        LD A,(HL)
        AND A
        RET Z
        DEC (HL)
        RET NZ
        LD A,($202D)
        OUT ($05),A
        RET

STEERING_LOOKUP_CURVE:
        AND A
        PUSH AF
        CALL STEERING_MAGNITUDE_SIGN
        LD E,A
        LD HL,$116D
        ADD HL,DE
        LD A,(HL)
        LD B,A
        LD E,C
        LD HL,$122E
        ADD HL,DE
        ADD A,(HL)
        JP P,STEERING_LOOKUP_MAGNITUDE
        LD E,D
        CP $EE
        JP C,PYLON_STEP_0881
        INC E
        JP PYLON_STEP_0881

STEERING_LOOKUP_MAGNITUDE:
        LD E,A
        LD HL,$11AE
        ADD HL,DE
        LD E,(HL)

PYLON_STEP_0881:
        POP AF
        LD A,E
        RET P
        CPL
        INC A
        RET

STEERING_MAGNITUDE_SIGN:
        AND A
        RET P
        CPL
        RET

GAME_FRAME_ADVANCE:
        LD A,($2022)
        AND A
        RET M
        RRCA
        RET NC
        LD HL,($2027)
        LD DE,$0046
        ADD HL,DE
        CALL PYLON_LOAD_09C9
        CALL PYLON_LOAD_09C9
        LD HL,($2025)
        LD DE,$0046
        ADD HL,DE
        CALL PYLON_LOAD_0A5C
        CALL PYLON_LOAD_0A5C
        LD HL,($2027)
        LD DE,$003C
        ADD HL,DE
        CALL PYLON_LOAD_09C9
        CALL PYLON_LOAD_09C9
        LD HL,($2025)
        LD DE,$003C
        ADD HL,DE
        CALL PYLON_LOAD_0A5C
        CALL PYLON_LOAD_0A5C
        LD HL,($2027)
        EX DE,HL
        LD HL,($2025)
        LD ($2027),HL
        EX DE,HL
        LD ($2025),HL
        LD ($2060),HL
        LD A,$05
        OUT ($04),A
        XOR A
        OUT ($03),A
        LD A,($2003)

ROAD_ADVANCE_SEGMENT:
        CALL ROAD_LOOKUP_CURVE
        LD HL,$2003
        LD A,(HL)
        ADD A,$20
        LD (HL),A
        JP NC,ROAD_ADVANCE_SEGMENT
        RET

PYLON_POSITION_UPDATE:
        LD HL,($2060)
        LD A,H
        OR L
        RET Z
        LD A,$05
        OUT ($04),A
        XOR A
        OUT ($03),A
        LD HL,$2003
        LD A,(HL)
        AND $1F
        LD (HL),A
        CALL ROAD_LOOKUP_CURVE
        LD HL,$2003
        LD A,(HL)
        ADD A,$20
        LD (HL),A

ROAD_LOOKUP_CURVE:
        LD C,A
        LD B,$00
        LD HL,$2145
        ADD HL,BC
        LD C,(HL)
        LD A,($2002)
        ADD A,C
        AND A
        JP P,PYLON_LOAD_092B
        CP $EE
        JP NC,PYLON_LOAD_0926
        LD L,B
        JP PYLON_LOAD_0931

PYLON_LOAD_0926:
        LD L,$01
        JP PYLON_LOAD_0931

PYLON_LOAD_092B:
        LD C,A
        LD HL,$11AE
        ADD HL,BC
        LD L,(HL)

PYLON_LOAD_0931:
        LD H,B
        LD A,($2037)
        AND A
        JP P,PYLON_STEP_093F
        XOR A
        SUB L
        LD L,A
        LD A,B
        SBC A,H
        LD H,A

PYLON_STEP_093F:
        EX DE,HL
        LD HL,($2000)
        ADD HL,DE
        LD ($2004),HL
        LD A,($2003)
        LD C,A
        LD HL,$2245
        ADD HL,BC
        LD A,(HL)
        LD ($2008),A
        LD D,A
        LD A,(HL)
        LD HL,$2006
        RRCA
        AND $7F
        LD E,A
        RRCA
        AND $1F
        LD (HL),A
        INC HL
        RRCA
        RRCA
        AND $07
        LD C,A
        INC A
        LD (HL),A
        LD A,D
        LD D,B
        ADD A,E
        LD E,A
        PUSH DE
        LD HL,($2004)
        ADD HL,DE
        PUSH HL
        ADD HL,BC
        LD A,H
        POP HL
        CALL PYLON_MASK_098D
        POP DE
        XOR A
        SUB E
        LD E,A
        LD A,$00
        SBC A,D
        LD D,A
        XOR A
        SUB C
        LD C,A
        LD A,$00
        SBC A,B
        LD B,A
        LD HL,($2004)
        ADD HL,BC
        ADD HL,DE
        LD A,H

PYLON_MASK_098D:
        AND A
        JP NZ,PYLON_LOAD_09BC
        EX DE,HL
        LD HL,($2060)
        LD A,($2007)
        LD (HL),A
        INC HL
        LD A,($2006)
        LD (HL),A
        INC HL
        LD A,E
        OUT ($03),A
        AND $07
        LD (HL),A
        INC HL
        LD A,($2008)
        OUT ($03),A
        IN A,($03)
        LD (HL),A
        INC HL
        XOR A
        OUT ($03),A
        IN A,($03)
        ADD A,$24
        LD (HL),A
        INC HL
        LD ($2060),HL

PYLON_DRAW_RECORD:
        RET

PYLON_LOAD_09BC:
        LD HL,($2060)
        LD (HL),$00
        LD DE,$0005
        ADD HL,DE
        LD ($2060),HL
        RET

PYLON_LOAD_09C9:
        LD A,(HL)
        AND A
        JP Z,PYLON_LOAD_0A61
        INC HL
        LD B,(HL)
        INC HL
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        PUSH HL
        EX DE,HL
        LD DE,$001F

PYLON_LOAD_09DB:
        LD (HL),D
        INC HL
        LD (HL),D
        ADD HL,DE
        DEC B
        JP NZ,PYLON_LOAD_09DB
        POP HL
        RET

PYLON_LOAD_09E5:
        LD A,(HL)
        AND A
        JP Z,PYLON_LOAD_0A61
        INC HL
        LD A,(HL)
        INC HL
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        EX DE,HL

PYLON_LOAD_09F3:
        LD (HL),B
        ADD HL,BC
        DEC A
        JP NZ,PYLON_LOAD_09F3
        EX DE,HL
        RET

PYLON_DRAW_MASKED:
        LD A,(HL)
        AND A
        JP Z,PYLON_LOAD_0A61
        LD C,A
        INC HL
        LD B,(HL)
        INC HL
        LD A,(HL)
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        PUSH HL
        EX DE,HL
        OUT ($04),A
        XOR A
        OUT ($03),A
        LD D,A
        PUSH HL
        LD E,C
        LD HL,$0A94
        ADD HL,DE
        LD A,(HL)
        OUT ($03),A
        IN A,($03)
        LD C,A
        XOR A
        OUT ($03),A
        LD E,$1F
        POP HL

PYLON_LOAD_0A24:
        LD A,(HL)
        OR C
        LD (HL),A
        INC HL
        IN A,($03)
        OR (HL)
        LD (HL),A
        ADD HL,DE
        DEC B
        JP NZ,PYLON_LOAD_0A24

PYLON_DRAW_PIXEL:
        POP HL
        RET

PYLON_LOAD_0A33:
        LD A,(HL)
        AND A
        JP Z,PYLON_LOAD_0A61
        INC HL
        LD B,(HL)
        INC HL
        LD A,(HL)
        OUT ($04),A
        XOR A
        OUT ($03),A
        LD A,$01
        OUT ($03),A
        IN A,($03)
        LD C,A
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        PUSH HL
        EX DE,HL
        LD DE,$0020

PYLON_LOAD_0A52:
        LD A,(HL)
        OR C
        LD (HL),A
        ADD HL,DE
        DEC B
        JP NZ,PYLON_LOAD_0A52
        POP HL
        RET

PYLON_LOAD_0A5C:
        LD A,(HL)
        AND A
        JP NZ,PYLON_LOAD_0A66

PYLON_LOAD_0A61:
        LD DE,$0005
        ADD HL,DE
        RET

PYLON_LOAD_0A66:
        LD C,A
        INC HL
        LD B,(HL)
        INC HL
        LD A,(HL)
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        PUSH HL
        PUSH DE
        OUT ($04),A
        XOR A
        OUT ($03),A
        LD D,A
        LD E,C
        LD HL,$0A94
        ADD HL,DE
        LD A,(HL)
        OUT ($03),A
        IN A,($03)
        LD C,A
        XOR A
        OUT ($03),A
        IN A,($03)
        LD E,$1F
        POP HL

PYLON_LOAD_0A8B:
        LD (HL),C
        INC HL
        LD (HL),A
        ADD HL,DE
        DEC B
        JP NZ,PYLON_LOAD_0A8B
        POP HL
        RET

;*******************************************************************************
; PIXEL MASK TABLE
;*******************************************************************************

PIXEL_BIT_MASK_TABLE:
        DB $01,$03,$07,$0F,$1F,$3F,$7F,$FF  ; cumulative masks: 01 03 07 0F 1F 3F 7F FF

;*******************************************************************************
; PYLON AND ANIMATION LOGIC
;*******************************************************************************

ANIM_CALL_0A9D:
        CALL ANIMATION_ADVANCE_RECORD
        CALL DRAW_LARGE_GFX_RECORD
        LD HL,$06DA
        EX (SP),HL
        JP ROAD_LOAD_0831

ANIMATION_ADVANCE_RECORD:
        LD HL,$204B
        DEC (HL)
        JP P,ANIMATION_APPLY_OFFSET
        EX DE,HL
        LD HL,($204D)
        LD B,$09
        CALL ANIM_LOAD_0ADF

ANIMATION_APPLY_OFFSET:
        LD HL,$2054
        LD A,($204C)
        ADD A,(HL)
        LD (HL),A
        INC HL
        LD C,A
        AND $07
        LD (HL),A
        INC HL
        LD A,C
        RRCA
        RRCA
        RRCA
        AND $1F
        ADD A,$A0
        LD (HL),A
        INC HL
        LD (HL),$29
        LD HL,$204F
        DEC (HL)
        RET P
        EX DE,HL
        LD HL,($2052)
        LD B,$05

ANIM_LOAD_0ADF:
        LD A,(HL)
        INC HL
        LD (DE),A
        INC DE
        DEC B
        JP NZ,ANIM_LOAD_0ADF
        RET

DRAW_LARGE_GFX_RECORD:
        LD HL,($2056)
        LD A,H
        OR L
        RET Z
        LD HL,($2058)
        LD A,H
        OR L
        JP Z,ANIM_LOAD_0B08
        LD BC,$0526
        LD DE,$001B

ANIM_LOAD_0AFC:
        LD A,B

ANIM_LOAD_0AFD:
        LD (HL),D
        INC HL
        DEC A
        JP NZ,ANIM_LOAD_0AFD
        ADD HL,DE
        DEC C
        JP NZ,ANIM_LOAD_0AFC

ANIM_LOAD_0B08:
        LD HL,($204D)
        LD A,H
        OR L
        JP NZ,ANIM_LOAD_0B18
        LD A,$01
        LD ($2022),A
        JP ANIM_LOAD_0B52

ANIM_LOAD_0B18:
        LD HL,($2050)
        LD C,(HL)
        INC HL
        LD B,(HL)
        INC HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        PUSH HL
        LD HL,($2056)

DRAW_PYLON_SIDES:
        ADD HL,DE
        LD ($2058),HL
        LD A,($2055)
        OUT ($04),A
        XOR A
        OUT ($03),A
        POP DE

ANIM_STEP_0B34:
        PUSH BC
        PUSH HL

ANIM_LOAD_0B36:
        LD A,(DE)
        INC DE
        OUT ($03),A
        IN A,($03)
        LD (HL),A
        INC HL
        DEC C
        JP NZ,ANIM_LOAD_0B36
        XOR A
        OUT ($03),A
        IN A,($03)
        LD (HL),A
        LD BC,$0020
        POP HL
        ADD HL,BC
        POP BC
        DEC B
        JP NZ,ANIM_STEP_0B34

ANIM_LOAD_0B52:
        LD HL,($2025)
        LD DE,$003C
        ADD HL,DE
        CALL PYLON_DRAW_MASKED
        CALL PYLON_DRAW_MASKED
        RET

ROM_ALIGNMENT:
        DB $7F  ; original ROM alignment

;*******************************************************************************
; GAME SETUP AND PLAY CONTROL
;*******************************************************************************

GAME_INITIALIZE:
        LD BC,$FF00
        LD SP,$2005
        CALL FILL_SCREEN_BAND
        LD SP,$2400
        CALL UNPACK_ROAD_CURVE_DATA
        LD HL,$FFFF
        LD ($2009),HL
        LD ($200B),HL
        CALL TEXT_CALL_0EB3
        EI
        JP TEXT_LOAD_0E1F

GAME_FRAME_SERVICE:
        OUT ($07),A
        LD HL,$2021
        LD A,(HL)
        AND A
        JP Z,UPDATE_GAMEPLAY
        XOR A
        LD (HL),A
        LD B,A
        LD A,$0A
        LD ($202E),A
        LD A,$22
        OUT ($05),A
        IN A,($02)
        RLCA
        AND $06
        LD C,A
        LD HL,$0FCF
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        LD HL,$202F
        INC (HL)
        LD A,(HL)
        CP E
        JP NZ,UPDATE_GAMEPLAY
        LD (HL),B
        INC HL
        LD A,(HL)
        ADD A,D
        LD (HL),A
        LD A,($2023)
        AND A
        JP Z,GAME_LOAD_0C2A

UPDATE_GAMEPLAY:
        CALL UPDATE_COIN_GAME_STATE
        LD A,($2023)
        AND A
        JP Z,GAME_CALL_0C21
        LD HL,$2041
        LD A,(HL)
        AND A
        JP NZ,GAME_LOAD_0C12
        LD (HL),$3C
        LD HL,$2034
        DEC (HL)
        LD HL,$2042
        LD A,(HL)
        ADD A,$99
        DAA
        LD (HL),A
        JP NZ,GAME_CALL_0C0F
        LD A,($2023)
        XOR $03
        JP Z,END_RACE
        IN A,($02)
        RRCA
        RRCA
        RRCA
        AND $06
        LD C,A
        LD B,$00
        LD HL,$001D
        ADD HL,BC
        LD C,(HL)
        LD HL,$203E
        LD A,(HL)
        AND $F0
        DEC HL
        ADD A,(HL)
        RRCA
        RRCA
        RRCA
        RRCA
        CP C
        JP C,END_RACE
        LD A,$03
        LD ($2023),A
        LD A,($2044)
        LD ($2042),A
        RST $30
        DB $81  ; inline argument, not executable code

GAME_CALL_0C0F:
        CALL DISPLAY_GAME_CLOCK

GAME_LOAD_0C12:
        LD HL,$2023
        LD A,(HL)
        CP $01
        RET NZ
        LD A,($203D)
        CP $01
        RET C
        INC (HL)
        RET

GAME_CALL_0C21:
        CALL ROAD_CODEC_STEP_1088
        LD A,($2045)
        AND $80
        RET NZ

GAME_LOAD_0C2A:
        LD HL,$2030
        LD A,(HL)
        AND A
        RET Z
        DEC (HL)
        LD SP,$2400
        XOR A
        LD ($2022),A
        LD HL,($203D)
        LD ($2029),HL
        LD DE,$2032
        LD B,$28

GAME_LOAD_0C43:
        LD (DE),A
        INC DE
        DEC B
        JP NZ,GAME_LOAD_0C43
        LD H,A
        IN A,($02)
        RRCA
        AND $06
        LD L,A
        LD DE,$0FD7
        ADD HL,DE
        LD A,(HL)
        LD ($2042),A
        INC HL
        LD A,(HL)
        LD ($2044),A
        LD A,$00
        LD ($202D),A
        LD A,$20
        OUT ($02),A
        CALL TEXT_CALL_0E98
        LD A,$01
        LD ($2023),A
        LD A,$FF
        LD ($2041),A
        LD A,$F8
        LD ($2048),A
        IN A,($00)
        AND $10
        JP Z,GAME_STEP_0C81
        RST $30
        DB $65  ; inline argument, not executable code

GAME_STEP_0C81:
        RST $28
        DB $04  ; inline argument, not executable code
        LD HL,$040B
        LD ($204D),HL
        LD A,$E0
        LD ($2054),A
        LD A,$FF
        LD ($2022),A
        RST $28
        DB $E8  ; inline argument, not executable code

GAME_CALL_0C95:
        CALL GAME_FRAME_SERVICE
        LD HL,$2140
        LD A,(HL)
        INC HL
        OR (HL)
        JP Z,GAME_CALL_0CB0
        LD A,($213E)
        AND A
        JP Z,GAME_CALL_0CB0
        CALL TEXT_STEP_0F33
        DB $04,$00  ; inline argument, not executable code
        JP GAME_LOAD_0CB5

GAME_CALL_0CB0:
        CALL TEXT_STEP_0F33
        DB $00,$00  ; inline argument, not executable code

GAME_LOAD_0CB5:
        LD HL,$2022
        LD A,(HL)
        XOR $05
        JP NZ,GAME_LOAD_0CC7
        LD A,($2040)
        AND A
        JP NZ,GAME_LOAD_0CC7

GAME_COLLISION_CHECK:
        LD (HL),$01

GAME_LOAD_0CC7:
        LD A,(HL)
        XOR $02
        JP Z,TEXT_LOAD_0E59
        LD HL,$2048
        LD A,(HL)
        AND A
        JP M,GAME_CALL_0CEE
        LD (HL),$F8
        LD HL,($2032)
        INC HL
        LD ($2032),HL
        LD HL,$203E
        LD A,(HL)
        ADD A,$01
        DAA
        LD (HL),A
        JP NC,GAME_CALL_0CEB
        DEC HL
        INC (HL)

GAME_CALL_0CEB:
        CALL DISPLAY_CURRENT_SCORE

GAME_CALL_0CEE:
        CALL GAME_LOAD_0D77
        LD A,($2037)
        CALL STEERING_MAGNITUDE_SIGN
        RRCA
        RRCA
        RRCA
        RRCA
        AND $03
        ADD A,$10
        CALL TEXT_CALL_0F48
        LD A,($2045)
        LD B,A
        AND $0F
        LD D,A
        RLCA
        LD C,A
        RLCA
        ADD A,C
        LD C,A
        LD A,B
        AND $10
        LD A,($213E)
        JP Z,GAME_STEP_0D39
        CP $28
        JP NC,GAME_LOAD_0D27
        RST $30
        DB $65  ; inline argument, not executable code
        LD C,$00
        LD A,$20
        OUT ($02),A
        JP GAME_LOAD_0D4F

GAME_LOAD_0D27:
        LD A,C
        RLCA
        LD C,A
        LD A,D
        OR $10
        OUT ($02),A

UPDATE_GAME_SPEED:
        LD A,$01
        LD ($205A),A
        RST $30
        DB $60  ; inline argument, not executable code
        JP GAME_LOAD_0D4F

GAME_STEP_0D39:
        CP $28
        JP C,GAME_STEP_0D43
        RST $30
        DB $66  ; inline argument, not executable code
        JP GAME_LOAD_0D45

GAME_STEP_0D43:
        RST $30
        DB $60  ; inline argument, not executable code

GAME_LOAD_0D45:
        LD A,D
        OR $20
        OUT ($02),A
        LD A,$02
        LD ($205A),A

GAME_LOAD_0D4F:
        LD A,C
        LD ($213F),A
        LD A,($2046)
        CALL READ_STEERING_INPUT
        CPL
        LD ($203A),A
        JP GAME_CALL_0C95

READ_STEERING_INPUT:
        LD A,($2046)
        CPL
        ADD A,$81
        CP $81
        JP C,GAME_STEP_0D71
        CP $C0
        RET NC
        LD A,$C0

CLAMP_STEERING:
        RET

GAME_STEP_0D71:
        CP $40
        RET C
        LD A,$3F
        RET

GAME_LOAD_0D77:
        LD A,($213E)
        LD B,A
        RRCA
        RRCA
        RRCA
        AND $1F
        CPL
        INC A
        ADD A,B
        LD HL,$2142
        CP (HL)
        RET Z
        JP C,GAME_DECREMENT_0D8F
        INC (HL)
        JP GAME_LOAD_0D90

GAME_DECREMENT_0D8F:
        DEC (HL)

GAME_LOAD_0D90:
        LD A,(HL)
        RRCA
        RRCA
        RRCA
        AND $1F
        ADD A,$A5
        LD E,A
        LD D,$39
        LD A,(HL)
        AND $07
        LD C,A
        LD B,$00
        LD HL,$0A95
        ADD HL,BC
        LD A,(HL)
        CPL
        EX DE,HL
        LD C,$1F
        LD DE,$04FF

GAME_LOAD_0DAD:
        LD (HL),A
        INC HL
        LD (HL),E
        ADD HL,BC
        DEC D
        JP NZ,GAME_LOAD_0DAD
        RET

END_RACE:
        LD SP,$2400
        LD A,$04
        LD ($2022),A
        CALL TEXT_CALL_0E4B
        LD ($2023),A
        CALL DISPLAY_GAME_CLOCK
        CALL READ_INLINE_MESSAGE
        DB $09  ; inline argument, not executable code
        LD HL,($202B)
        EX DE,HL
        LD HL,($203D)
        LD A,L
        CP E
        JP C,GAME_CALL_0DEF
        JP NZ,GAME_LOAD_0DDF
        LD A,D
        CP H
        JP NC,GAME_CALL_0DEF

GAME_LOAD_0DDF:
        LD ($202B),HL
        CALL ERASE_MESSAGE_BAND
        CALL TEXT_STEP_0F5A
        DB $6F  ; inline argument, not executable code
        CALL TEXT_STEP_0F5A
        DB $84  ; inline argument, not executable code
        RST $28
        DB $FF  ; inline argument, not executable code

GAME_CALL_0DEF:
        CALL ERASE_MESSAGE_BAND
        CALL TEXT_STEP_0F5A
        DB $62  ; inline argument, not executable code
        LD A,($2034)
        LD C,A
        LD B,$FF
        LD E,B
        LD HL,($2032)

GAME_COMPUTE_RATING:
        LD A,H
        AND A
        JP M,TEXT_LOAD_0E0A
        ADD HL,BC
        INC E
        JP GAME_COMPUTE_RATING

TEXT_LOAD_0E0A:
        LD A,($2035)
        AND A
        LD A,E
        JP NZ,TEXT_STEP_0E13
        INC A

TEXT_STEP_0E13:
        ADD A,$94
        CALL TEXT_STEP_0F5E
        RST $28
        DB $FF  ; inline argument, not executable code
        RST $28
        DB $FF  ; inline argument, not executable code

TEXT_CALL_0E1C:
        CALL TEXT_CALL_0EB3

TEXT_LOAD_0E1F:
        LD A,$0A
        LD ($2031),A

TEXT_CALL_0E24:
        CALL TEXT_CALL_0E4B
        LD A,($2030)
        AND A
        JP Z,TEXT_CALL_0E35
        CALL READ_INLINE_MESSAGE
        DB $08  ; inline argument, not executable code
        JP TEXT_STEP_0E39

TEXT_CALL_0E35:
        CALL READ_INLINE_MESSAGE
        DB $07  ; inline argument, not executable code

TEXT_STEP_0E39:
        RST $28
        DB $FF  ; inline argument, not executable code

GAME_RESULTS_SCREEN:
        CALL READ_INLINE_MESSAGE
        DB $0E  ; inline argument, not executable code
        RST $28
        DB $FF  ; inline argument, not executable code
        LD HL,$2031
        DEC (HL)
        JP NZ,TEXT_CALL_0E24
        JP TEXT_CALL_0E1C

TEXT_CALL_0E4B:
        CALL TEXT_STEP_0F33
        DB $02,$00  ; inline argument, not executable code
        LD A,$02
        LD ($202D),A
        XOR A
        OUT ($02),A
        RET

TEXT_LOAD_0E59:
        LD SP,$2400
        CALL TEXT_STEP_0F33
        DB $03,$3C  ; inline argument, not executable code
        CALL DISPLAY_CRASH_CAPTION
        LD HL,$2035
        INC (HL)
        CALL TEXT_CALL_0F28
        XOR A
        OUT ($02),A
        CALL TEXT_STEP_0F33
        DB $02,$0A  ; inline argument, not executable code
        CALL TEXT_CALL_0F28
        CALL TEXT_STEP_0F33
        DB $0A,$50  ; inline argument, not executable code
        CALL TEXT_CALL_0F28
        CALL TEXT_CALL_0E98
        LD A,($2023)
        CP $01
        LD A,$FF
        JP Z,TEXT_LOAD_0E8D
        LD A,$78

TEXT_LOAD_0E8D:
        LD ($2040),A
        LD A,$05
        LD ($2022),A
        JP GAME_CALL_0C95

TEXT_CALL_0E98:
        CALL GAME_START_PROMPT
        CALL TEXT_STEP_0F5A
        DB $4B  ; inline argument, not executable code
        CALL DISPLAY_GAME_CLOCK
        CALL DISPLAY_CURRENT_SCORE
        LD A,$01
        LD ($2022),A
        LD A,($2023)
        XOR $03
        RET NZ
        RST $30
        DB $81  ; inline argument, not executable code
        RET

TEXT_CALL_0EB3:
        CALL GAME_START_PROMPT
        CALL TEXT_STEP_0F5A
        DB $43  ; inline argument, not executable code
        RST $30
        DB $6C  ; inline argument, not executable code
        RST $30
        DB $8D  ; inline argument, not executable code
        CALL DISPLAY_CURRENT_SCORE
        LD HL,$202B
        LD DE,$3CB9
        CALL TEXT_CALL_0FE5
        LD HL,$2029
        LD DE,$3E99
        CALL TEXT_CALL_0FE5
        LD A,$03
        LD ($2022),A
        LD A,$50
        LD ($213F),A
        RET

GAME_START_PROMPT:
        XOR A
        LD ($2022),A
        CALL CLEAR_VIDEO_RAM
        LD BC,$14FF
        LD DE,$3A80
        CALL FILL_SCREEN_WITH_STACK
        LD HL,$205A
        LD C,$EA
        XOR A

TEXT_LOAD_0EF4:
        LD (HL),A
        INC HL
        DEC C
        JP NZ,TEXT_LOAD_0EF4
        LD A,$01
        LD ($205A),A
        LD HL,$2062
        LD ($2027),HL
        LD HL,$20D0
        LD ($2025),HL
        LD HL,$0080
        LD ($2000),HL
        CALL TEXT_STEP_0F5A
        DB $2A  ; inline argument, not executable code
        RET

RST_WAIT_INLINE_TICKS:
        EX (SP),HL
        LD A,(HL)
        INC HL
        EX (SP),HL
        LD ($203F),A

TEXT_CALL_0F1D:
        CALL GAME_FRAME_SERVICE
        LD A,($203F)
        AND A
        JP NZ,TEXT_CALL_0F1D
        RET

TEXT_CALL_0F28:
        CALL GAME_FRAME_SERVICE
        LD A,($202E)
        AND A
        JP NZ,TEXT_CALL_0F28
        RET

TEXT_STEP_0F33:
        EX (SP),HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        INC HL
        EX (SP),HL
        LD HL,$202E
        LD A,(HL)
        AND A
        RET NZ
        LD (HL),B
        LD A,C
        OUT ($05),A
        RET

READ_INLINE_MESSAGE:
        EX (SP),HL
        LD A,(HL)
        INC HL
        EX (SP),HL

TEXT_CALL_0F48:
        CALL TEXT_STEP_0F91
        LD (HL),A
        PUSH AF
        LD BC,$0A00
        LD DE,$2540
        CALL FILL_SCREEN_WITH_STACK
        POP AF
        JP TEXT_STEP_0F5E

TEXT_STEP_0F5A:
        EX (SP),HL
        LD A,(HL)
        INC HL
        EX (SP),HL

TEXT_STEP_0F5E:
        PUSH HL
        RLCA
        PUSH AF
        RLCA
        RLCA
        RLCA
        AND $0E
        LD C,A
        LD B,$00
        LD HL,$0FC5
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        POP AF
        AND $3E
        JP Z,TEXT_STEP_0F8F
        PUSH DE
        LD C,A
        LD HL,$123F
        CALL SELECT_LOCALE_POINTER
        EX DE,HL
        ADD HL,BC
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL

LOOKUP_MESSAGE_SLOT:
        POP DE

TEXT_LOAD_0F85:
        LD A,(HL)
        CALL DRAW_GLYPH
        LD A,(HL)
        INC HL
        AND A
        JP P,TEXT_LOAD_0F85

TEXT_STEP_0F8F:
        POP HL
        RET

TEXT_STEP_0F91:
        PUSH BC
        PUSH AF
        RLCA
        RLCA
        RLCA
        AND $07
        LD C,A
        LD B,$00
        LD HL,$205B
        ADD HL,BC
        POP AF
        POP BC
        CP (HL)
        RET NZ
        POP HL
        RET

;*******************************************************************************
; IMPACT PHRASES AND DISPLAY TABLES
;*******************************************************************************

IMPACT_CAPTION_CHARACTERS:
        DB "POW?ZAP?WAM?BAM?ZORKBANGBOOMZONK"  ; impact words: POW ZAP WAM BAM ZORK BANG BOOM ZONK

DISPLAY_MESSAGE_ROW_POINTERS:
        DW $2400  ; five text row locations in screen RAM
        DW $3840
        DW $3AC0
        DW $3CA0
        DW $3E80

SCORING_WEIGHT_VALUES:
        DB $01,$01,$01,$02,$02,$01,$02,$03  ; game score/display numeric table

DISPLAY_SCORE_CONSTANTS:
        DB $80,$40,$01,$01,$99,$50,$60,$30  ; game score/display numeric table

;*******************************************************************************
; SCORE, TIMER AND LOCALIZED MESSAGE DRAWING
;*******************************************************************************

DISPLAY_CURRENT_SCORE:
        LD HL,$203D
        LD DE,$3AD9

TEXT_CALL_0FE5:
        CALL DRAW_BCD_DIGITS
        LD A,$3E
        CALL DRAW_GLYPH
        INC HL
        JP DRAW_NEXT_DIGIT

DISPLAY_GAME_CLOCK:
        LD HL,$1247
        CALL SELECT_LOCALE_POINTER
        LD HL,$2042
        JP DRAW_BCD_DIGITS

ROM_ALIGNMENT_BYTES:
        DB $A7,$00,$00  ; original ROM alignment

;*******************************************************************************
; ROM DEVICE ZZZAPD — $1000
;*******************************************************************************

;*******************************************************************************
; LOCALE SELECTOR / ROAD DECODER / RANDOM STATE
;*******************************************************************************

; Read DIP bits and select the localized display-string pointer table.
SELECT_LOCALE_POINTER:
        IN A,($02)
        RLCA
        RLCA
        RLCA
        AND $06
        LD E,A
        LD D,$00
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        RET

UPDATE_COIN_GAME_STATE:
        LD A,($204A)
        AND A
        RET M
        LD HL,$2036
        LD B,(HL)
        LD A,(HL)
        INC HL
        CP (HL)
        JP Z,ROAD_CODEC_ADVANCE_1037
        XOR (HL)
        LD A,B
        JP M,ROAD_CODEC_STEP_102B
        CP (HL)
        JP NC,ROAD_CODEC_ADVANCE_102F

ROAD_CODEC_DECREMENT_1027:
        DEC (HL)
        JP ROAD_CODEC_LOAD_1030

ROAD_CODEC_STEP_102B:
        CP (HL)
        JP NC,ROAD_CODEC_DECREMENT_1027

ROAD_CODEC_ADVANCE_102F:
        INC (HL)

ROAD_CODEC_LOAD_1030:
        LD A,($2039)
        LD ($204A),A
        RET

ROAD_CODEC_ADVANCE_1037:
        INC HL
        LD A,(HL)
        AND A
        JP NZ,ROAD_CODEC_DECREMENT_1027
        LD B,A
        LD A,($2023)
        LD C,A
        RLCA
        ADD A,C
        LD C,A
        LD HL,$107C
        ADD HL,BC
        LD DE,$2036
        CALL ROAD_CODEC_STEP_1088
        AND $07
        JP Z,ROAD_CODEC_LOAD_106F
        CALL ROAD_CODEC_STEP_1088
        AND $7F
        SUB $40
        LD (DE),A
        INC DE
        INC DE
        CALL ROAD_CODEC_STEP_1088
        AND (HL)

ROAD_CODEC_LOAD_1062:
        LD (DE),A
        INC DE
        INC HL
        CALL ROAD_CODEC_STEP_1088
        AND (HL)
        INC HL
        ADD A,(HL)
        ADD A,$FC
        LD (DE),A
        RET

ROAD_CODEC_LOAD_106F:
        LD (DE),A
        INC DE
        INC DE
        CALL ROAD_CODEC_STEP_1088
        AND $3F
        ADD A,$20
        JP ROAD_CODEC_LOAD_1062

;*******************************************************************************
; PACKED TRACK TOKEN FIELDS
;*******************************************************************************

TRACK_TOKEN_FIELD_LAYOUT:
        DB $03,$03,$00,$03,$03,$00,$03,$01  ; packed track field configuration
        DB $02,$03,$00,$03  ; packed track field configuration

;*******************************************************************************
; RANDOM GENERATOR AND ROAD EXPANSION
;*******************************************************************************

ROAD_CODEC_STEP_1088:
        PUSH HL
        PUSH BC
        LD HL,$2009
        LD B,$08
        LD A,(HL)

ROAD_CODEC_STEP_1090:
        RLCA
        RLCA
        RLCA
        XOR (HL)
        RLA
        RLA
        LD HL,$2009
        LD A,(HL)
        RLA
        LD (HL),A
        INC HL
        LD A,(HL)
        RLA
        LD (HL),A
        INC HL
        LD A,(HL)
        RLA
        LD (HL),A
        INC HL
        LD A,(HL)
        RLA
        LD (HL),A
        DEC B
        JP NZ,ROAD_CODEC_STEP_1090
        POP BC
        POP HL
        RET

; Expand compressed road curve data into RAM.
UNPACK_ROAD_CURVE_DATA:
        LD HL,$2144
        LD (HL),$35
        LD DE,$10E7
        LD BC,$0040
        CALL DECODE_NEXT_ROAD_DELTA
        INC HL
        EX DE,HL
        LD B,$08
        CALL ANIM_LOAD_0ADF
        EX DE,HL
        DEC HL
        LD BC,$FF3E

DECODE_NEXT_ROAD_DELTA:
        LD A,(DE)
        PUSH DE
        LD D,$04

ROAD_CODEC_STEP_10CD:
        RLCA
        RLCA
        LD E,A
        AND $03
        XOR B
        JP P,ROAD_CODEC_STEP_10D7
        INC A

ROAD_CODEC_STEP_10D7:
        ADD A,(HL)
        INC HL
        LD (HL),A
        DEC D
        LD A,E
        JP NZ,ROAD_CODEC_STEP_10CD
        POP DE
        INC DE
        DEC C
        JP NZ,DECODE_NEXT_ROAD_DELTA
        RET

;*******************************************************************************
; PACKED ROAD AND STEERING TABLES
;*******************************************************************************

ROAD_DELTA_PREFIX_BYTE:
        DB $D5  ; table entry preceding compressed road deltas

ROAD_POSITIVE_DELTA_STREAM:
        DB $25,$55,$55,$15,$15,$15,$04,$51  ; four packed two-bit positive road deltas
        DB $11,$11,$04,$44,$11,$04,$10,$41  ; four packed two-bit positive road deltas
        DB $04,$10,$41,$01,$01,$04,$04,$04  ; four packed two-bit positive road deltas
        DB $04,$04,$01,$01,$00,$40,$10,$04  ; four packed two-bit positive road deltas
        DB $01,$00,$40,$10,$01,$00,$10,$04  ; four packed two-bit positive road deltas
        DB $00,$40,$04,$00,$10,$01,$00,$10  ; four packed two-bit positive road deltas
        DB $00,$40,$01,$00,$10,$00,$40,$01  ; four packed two-bit positive road deltas
        DB $00,$01,$00,$04,$00,$10,$00,$40  ; four packed two-bit positive road deltas

ROAD_NEGATIVE_START_VALUES:
        DB $7F,$79,$74,$70,$6B,$67,$64,$60  ; initial negative road curve values

ROAD_NEGATIVE_DELTA_STREAM:
        DB $FE,$EE,$A6,$99,$65,$55,$55,$54  ; four packed two-bit negative road deltas
        DB $51,$45,$11,$11,$11,$04,$41,$04  ; four packed two-bit negative road deltas
        DB $10,$40,$41,$00,$40,$40,$10,$04  ; four packed two-bit negative road deltas
        DB $00,$40,$04,$00,$10,$00,$10,$00  ; four packed two-bit negative road deltas
        DB $10,$00,$01,$00,$00,$04,$00,$00  ; four packed two-bit negative road deltas
        DB $04,$00,$00,$00,$40,$00,$00,$00  ; four packed two-bit negative road deltas
        DB $10,$00,$00,$00,$00,$40,$00,$00  ; four packed two-bit negative road deltas
        DB $00,$00,$01,$00,$00,$00  ; four packed two-bit negative road deltas

STEERING_CURVE_VALUES:
        DB $81,$8F,$A2,$AD,$B5,$BB,$C0,$C4  ; nonlinear steering response curve
        DB $C8,$CB,$CE,$D0,$D3,$D5,$D7,$D9  ; nonlinear steering response curve
        DB $DB,$DC,$DE,$DF,$E1,$E2,$E3,$E4  ; nonlinear steering response curve
        DB $E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED  ; nonlinear steering response curve
        DB $ED,$EE,$EF,$F0,$F1,$F1,$F2,$F3  ; nonlinear steering response curve
        DB $F4,$F4,$F5,$F6,$F6,$F7,$F7,$F8  ; nonlinear steering response curve
        DB $F9,$F9,$FA,$FA,$FB,$FB,$FC,$FC  ; nonlinear steering response curve
        DB $FD,$FD,$FE,$FE,$FF,$FF,$FF,$FF  ; nonlinear steering response curve
        DB $FF  ; nonlinear steering response curve

STEERING_SPEED_MULTIPLIERS:
        DB $01,$01,$01,$01,$01,$01,$01,$01  ; steering and speed lookup
        DB $01,$01,$01,$02,$02,$02,$02,$02  ; steering and speed lookup
        DB $02,$02,$02,$02,$02,$02,$02,$02  ; steering and speed lookup
        DB $02,$02,$03,$03,$03,$03,$03,$03  ; steering and speed lookup
        DB $03,$03,$03,$04,$04,$04,$04,$04  ; steering and speed lookup
        DB $04,$04,$05,$05,$05,$05,$05,$06  ; steering and speed lookup
        DB $06,$06,$06,$06,$07,$07,$07,$07  ; steering and speed lookup
        DB $08,$08,$08,$09,$09,$09,$0A,$0A  ; steering and speed lookup
        DB $0A,$0B,$0B,$0C,$0C,$0C,$0D,$0D  ; steering and speed lookup
        DB $0E,$0E,$0F,$10,$10,$11,$11,$12  ; steering and speed lookup
        DB $13,$13,$14,$15,$16,$16,$17,$18  ; steering and speed lookup
        DB $19,$1A,$1B,$1C,$1D,$1E,$1F,$20  ; steering and speed lookup
        DB $21,$23,$24,$25,$27,$28,$2A,$2B  ; steering and speed lookup
        DB $2D,$2F,$30,$32,$34,$36,$38,$3A  ; steering and speed lookup
        DB $3C,$3E,$41,$43,$46,$48,$4B,$4E  ; steering and speed lookup
        DB $51,$54,$57,$5A,$5C,$61,$64,$68  ; steering and speed lookup

ROAD_STEP_INDEX:
        DB $00,$01,$13,$1E,$26,$2C,$31,$33  ; road step index
        DB $35,$39,$3B,$3D,$3F,$41,$42,$43  ; road step index
        DB $44  ; road step index

;*******************************************************************************
; FOUR LANGUAGE POINTER AND STRING TABLES
;*******************************************************************************

LOCALE_MESSAGE_BASES:
; language text bases
        DW $124D  ; language text bases
        DW $13F0
        DW $1551
        DW $16B3

LOCALE_SCREEN_ROWS:
; language screen locations
        DW $3AC8  ; language screen locations
        DW $3AC8
        DW $3AC9
        DW $3ACA

ENGLISH_MESSAGE_POINTERS:
; English message pointers
        DW TEXT_EN_EXTENDED_TIM  ; English message pointers
        DW TEXT_EN_YOUR_RATING_TO
        DW TEXT_EN_SCORE
        DW TEXT_EN_YOU_HAVE_SET_A_NEW_RECORD
        DW TEXT_EN_SHIFT_GEAR_INTO_LOW_SPEE
        DW TEXT_EN_SHIFT_TO_HIGH_FOR_MAX_SCO
        DW TEXT_EN_INSERT_COI
        DW TEXT_EN_PUSH_BUTTO
        DW TEXT_EN_GAME_OVE
        DW TEXT_EN_TEXT
        DW TEXT_EN_TIMESCORE
        DW TEXT_EN_HIGH_SCORE
        DW TEXT_EN_PREVIOUS_SCORE
        DW TEXT_EN_DATSUN_ZZZA
        DW TEXT_EN_CONGRATULATIONS
        DW $1293
        DW TEXT_EN_MAX_CURVE_MPH
        DW TEXT_EN_MAX_CURVE_MP
        DW TEXT_EN_MAX_CURVE_MP_12A6
        DW TEXT_EN_ROAD_HO
        DW TEXT_EN_FENDER_BENDE
        DW TEXT_EN_HOT_WHEEL
        DW TEXT_EN_PRO_RACE
        DW TEXT_EN_CHAMPIO
        DW TEXT_EN_CHAMPIO

TEXT_EN_MAX_CURVE_MPH:
        DB $07,"MAX@CURVE@160@MPH",$C0  ; encoded display text; high-bit terminator

TEXT_EN_MAX_CURVE_MP:
        DB $07,"MAX@CURVE@120@MP",$C8  ; encoded display text; high-bit terminator

TEXT_EN_MAX_CURVE_MP_12A6:
        DB $07,"MAX@CURVE@@80@MP",$C8  ; encoded display text; high-bit terminator

TEXT_EN_EXTENDED_TIM:
        DB $0A,"EXTENDED@TIM",$C5  ; encoded display text; high-bit terminator

TEXT_EN_SHIFT_GEAR_INTO_LOW_SPEE:
        DB $04,"SHIFT@GEAR@INTO@LOW@SPEE",$C4  ; encoded display text; high-bit terminator

TEXT_EN_SHIFT_TO_HIGH_FOR_MAX_SCO:
        DB $02,"SHIFT@TO@HIGH@FOR@MAX@SCORE",$BF  ; encoded display text; high-bit terminator

TEXT_EN_INSERT_COI:
        DB $0A,"INSERT@COI",$CE  ; encoded display text; high-bit terminator

TEXT_EN_PUSH_BUTTO:
        DB $0A,"PUSH@BUTTO",$CE  ; encoded display text; high-bit terminator

TEXT_EN_GAME_OVE:
        DB $0C,"GAME@OVE",$D2  ; encoded display text; high-bit terminator

TEXT_EN_TEXT:
        DB $05,"[;",$5C,";];^;_<[<",$5C,"<]<^<_=",$DB  ; encoded display text; high-bit terminator

TEXT_EN_TIMESCORE:
        DB $02,"TIME:",$09  ; encoded display text; high-bit terminator

TEXT_EN_SCORE:
        DB $03,"SCORE",$BA  ; encoded display text; high-bit terminator

TEXT_EN_HIGH_SCORE:
        DB $03,"HIGH@SCORE",$BA  ; encoded display text; high-bit terminator

TEXT_EN_PREVIOUS_SCORE:
        DB $03,"PREVIOUS@SCORE",$BA  ; encoded display text; high-bit terminator

TEXT_EN_DATSUN_ZZZA:
        DB $08,"DATSUN@280@ZZZA",$D0  ; encoded display text; high-bit terminator

TEXT_EN_CONGRATULATIONS:
        DB $08,"CONGRATULATIONS",$BF  ; encoded display text; high-bit terminator

TEXT_EN_YOU_HAVE_SET_A_NEW_RECORD:
        DB $03,"YOU@HAVE@SET@A@NEW@RECORD",$BF  ; encoded display text; high-bit terminator

TEXT_EN_ROAD_HO:
        DB $0A,"1",$02,"ROAD@HO",$C7  ; encoded display text; high-bit terminator

TEXT_EN_FENDER_BENDE:
        DB $08,"2",$02,"FENDER@BENDE",$D2  ; encoded display text; high-bit terminator

TEXT_EN_HOT_WHEEL:
        DB $09,"3",$02,"HOT@WHEEL",$D3  ; encoded display text; high-bit terminator

TEXT_EN_PRO_RACE:
        DB $0A,"4",$02,"PRO@RACE",$D2  ; encoded display text; high-bit terminator

TEXT_EN_CHAMPIO:
        DB $0A,"5",$02,"CHAMPIO",$CE  ; encoded display text; high-bit terminator

TEXT_EN_YOUR_RATING_TO:
        DB $06,"YOUR@RATING@1@TO@5",$BA  ; encoded display text; high-bit terminator
        DB $00,$00,$00  ; encoded display text; high-bit terminator

GERMAN_MESSAGE_POINTERS:
; German message pointers
        DW TEXT_DE_ZEIT_PRAEMI  ; German message pointers
        DW TEXT_DE_RANGFOLGE_BIS
        DW TEXT_DE_PUNKTE
        DW TEXT_DE_NEVEN_REKORD_AUFGESTELL
        DW TEXT_DE_GANG_AUF_LO_SCHALTE
        DW TEXT_DE_GANG_AUF_HI_SCHALTE
        DW TEXT_DE_GELD_EINWERFE
        DW TEXT_DE_KNOPF_DRUECKE
        DW TEXT_DE_SPIELEND
        DW TEXT_EN_TEXT
        DW TEXT_DE_ZEITPUNKTE
        DW TEXT_DE_HOECHSTE_PUNKTZAHL
        DW TEXT_DE_LETZTE_PUNKTZAHL
        DW TEXT_EN_DATSUN_ZZZA
        DW TEXT_DE_GRATULIERESIE_HABEN_EINE
        DW $1293
        DW TEXT_DE_K
        DW TEXT_DE_K_142F
        DW TEXT_DE_K_1436
        DW TEXT_DE_ANFAENGE
        DW TEXT_DE_SPORTFAHRE
        DW TEXT_DE_RENNFAHRE
        DW TEXT_DE_GRAND_PRIX_FAHRE
        DW TEXT_EN_CHAMPIO
        DW TEXT_EN_CHAMPIO
        DB $87,$00,$00,$00  ; encoded display text; high-bit terminator

TEXT_DE_K:
        DB $0C,"160@K",$CD  ; encoded display text; high-bit terminator

TEXT_DE_K_142F:
        DB $0C,"120@K",$CD  ; encoded display text; high-bit terminator

TEXT_DE_K_1436:
        DB $0D,"80@K",$CD  ; encoded display text; high-bit terminator

TEXT_DE_ZEIT_PRAEMI:
        DB $0A,"ZEIT@PRAEMI",$C5  ; encoded display text; high-bit terminator

TEXT_DE_GANG_AUF_LO_SCHALTE:
        DB $06,"GANG@AUF@LO@SCHALTE",$CE  ; encoded display text; high-bit terminator

TEXT_DE_GANG_AUF_HI_SCHALTE:
        DB $06,"GANG@AUF@HI@SCHALTE",$CE  ; encoded display text; high-bit terminator

TEXT_DE_GELD_EINWERFE:
        DB $09,"GELD@EINWERFE",$CE  ; encoded display text; high-bit terminator

TEXT_DE_KNOPF_DRUECKE:
        DB $09,"KNOPF@DRUECKE",$CE  ; encoded display text; high-bit terminator

TEXT_DE_SPIELEND:
        DB $0B,"SPIELEND",$C5  ; encoded display text; high-bit terminator

TEXT_DE_ZEITPUNKTE:
        DB $02,"ZEIT:",$08  ; encoded display text; high-bit terminator

TEXT_DE_PUNKTE:
        DB $03,"PUNKTE",$BA  ; encoded display text; high-bit terminator

TEXT_DE_HOECHSTE_PUNKTZAHL:
        DB $03,"HOECHSTE@PUNKTZAHL",$BA  ; encoded display text; high-bit terminator

TEXT_DE_LETZTE_PUNKTZAHL:
        DB $03,"LETZTE@PUNKTZAHL",$BA  ; encoded display text; high-bit terminator

TEXT_DE_GRATULIERESIE_HABEN_EINE:
        DB $02,"GRATULIERE?",$02,"SIE@HABEN@EINE",$CE  ; encoded display text; high-bit terminator

TEXT_DE_NEVEN_REKORD_AUFGESTELL:
        DB $04,"NEVEN@REKORD@AUFGESTELL",$D4  ; encoded display text; high-bit terminator

TEXT_DE_ANFAENGE:
        DB $0A,"1",$02,"ANFAENGE",$D2  ; encoded display text; high-bit terminator

TEXT_DE_SPORTFAHRE:
        DB $09,"2",$02,"SPORTFAHRE",$D2  ; encoded display text; high-bit terminator

TEXT_DE_RENNFAHRE:
        DB $09,"3",$02,"RENNFAHRE",$D2  ; encoded display text; high-bit terminator

TEXT_DE_GRAND_PRIX_FAHRE:
        DB $06,"4",$02,"GRAND@PRIX@FAHRE",$D2  ; encoded display text; high-bit terminator

TEXT_DE_RANGFOLGE_BIS:
        DB $07,"RANGFOLGE@1@BIS@5",$BA  ; encoded display text; high-bit terminator

FRENCH_MESSAGE_POINTERS:
; French message pointers
        DW TEXT_FR_TEMPS_SUPPLEMENTAIR  ; French message pointers
        DW TEXT_FR_VOTRE_CATEGORIE
        DW TEXT_EN_SCORE
        DW TEXT_FR_NOUVEAU_RECORD_DE_PIST
        DW TEXT_FR_PASSEZ_LA_PREMIERE_VITESS
        DW TEXT_FR_PASSEZ_LA_SECONDE_VITESS
        DW TEXT_FR_INTRODUISER_FRAN
        DW TEXT_FR_POUSSEZ_LE_BOUTO
        DW TEXT_FR_TERMIN
        DW TEXT_EN_TEXT
        DW TEXT_FR_TEMPSSCORE
        DW TEXT_FR_SCORE_A_BATTRE
        DW TEXT_FR_SCORE_PRECEDENT
        DW TEXT_EN_DATSUN_ZZZA
        DW TEXT_FR_BRAVOVOUS_AVEZ_REALISE_U
        DW $1293
        DW TEXT_DE_K
        DW TEXT_DE_K_142F
        DW TEXT_DE_K_1436
        DW TEXT_FR_REPRENEZ_UNE_LECO
        DW TEXT_FR_AMATEU
        DW TEXT_FR_PROFESSIONE
        DW TEXT_FR_CHAMPIO
        DW TEXT_FR_SUPER_CHAMPIO
        DW TEXT_FR_SUPER_CHAMPIO
        DB $00,$00,$00,$00  ; encoded display text; high-bit terminator

TEXT_FR_TEMPSSCORE:
        DB $02,"TEMPS:",$0B,"SCORE",$BA  ; encoded display text; high-bit terminator

TEXT_FR_TEMPS_SUPPLEMENTAIR:
        DB $06,"TEMPS@SUPPLEMENTAIR",$C5  ; encoded display text; high-bit terminator

TEXT_FR_PASSEZ_LA_PREMIERE_VITESS:
        DB $03,"PASSEZ@LA@PREMIERE@VITESS",$C5  ; encoded display text; high-bit terminator

TEXT_FR_TERMIN:
        DB $0C,"TERMIN",$C5  ; encoded display text; high-bit terminator

TEXT_FR_PASSEZ_LA_SECONDE_VITESS:
        DB $03,"PASSEZ@LA@SECONDE@VITESS",$C5  ; encoded display text; high-bit terminator

TEXT_FR_BRAVOVOUS_AVEZ_REALISE_U:
        DB $02,"BRAVO?",$02,"VOUS@AVEZ@REALISE@U",$CE  ; encoded display text; high-bit terminator

TEXT_FR_NOUVEAU_RECORD_DE_PIST:
        DB $04,"NOUVEAU@RECORD@DE@PIST",$C5  ; encoded display text; high-bit terminator

TEXT_FR_VOTRE_CATEGORIE:
        DB $08,"VOTRE@CATEGORIE",$BA  ; encoded display text; high-bit terminator

TEXT_FR_REPRENEZ_UNE_LECO:
        DB $07,"REPRENEZ@UNE@LECO",$CE  ; encoded display text; high-bit terminator

TEXT_FR_AMATEU:
        DB $0C,"AMATEU",$D2  ; encoded display text; high-bit terminator

TEXT_FR_PROFESSIONE:
        DB $0A,"PROFESSIONE",$CC  ; encoded display text; high-bit terminator

TEXT_FR_CHAMPIO:
        DB $0C,"CHAMPIO",$CE  ; encoded display text; high-bit terminator

TEXT_FR_SUPER_CHAMPIO:
        DB $09,"SUPER@CHAMPIO",$CE  ; encoded display text; high-bit terminator

TEXT_FR_SCORE_A_BATTRE:
        DB $03,"SCORE@A@BATTRE",$BA  ; encoded display text; high-bit terminator

TEXT_FR_SCORE_PRECEDENT:
        DB $03,"SCORE@PRECEDENT",$BA  ; encoded display text; high-bit terminator

TEXT_FR_INTRODUISER_FRAN:
        DB $06,"INTRODUISER@1@FRAN",$C3  ; encoded display text; high-bit terminator

TEXT_FR_POUSSEZ_LE_BOUTO:
        DB $07,"POUSSEZ@LE@BOUTO",$CE  ; encoded display text; high-bit terminator

SPANISH_MESSAGE_POINTERS:
; Spanish message pointers
        DW TEXT_ES_TIEMPO_EXTENDID  ; Spanish message pointers
        DW TEXT_ES_TU_PUNTEO_E
        DW TEXT_ES_PUNTEO
        DW TEXT_ES_HICISTE_UN_NUEVO_RECO
        DW TEXT_ES_CAMBIELO_A_MENOS_VELOCIDA
        DW TEXT_ES_CAMBIELO_AMAS_VELOCIDA
        DW TEXT_ES_PONGA_LA_MONED
        DW TEXT_ES_AGACHA_EL_BOTO
        DW TEXT_ES_JUEGO_TERMINAD
        DW TEXT_EN_TEXT
        DW TEXT_ES_TIEMPOPUNTEO
        DW TEXT_ES_PRIMER_PUEST_17CE
        DW TEXT_ES_SEGUNDO_PUEST_17BE
        DW TEXT_EN_DATSUN_ZZZA
        DW TEXT_ES_FELICITACIONE
        DW $1293
        DW TEXT_DE_K
        DW TEXT_DE_K_142F
        DW TEXT_DE_K_1436
        DW TEXT_ES_LLEVAS_LA_DELANTER
        DW TEXT_ES_VA_EN_SEGUNDO_LUGA
        DW TEXT_ES_LLANTAS_CALIENTE
        DW TEXT_ES_SEGUNDO_PUEST
        DW TEXT_ES_PRIMER_PUEST
        DW TEXT_ES_PRIMER_PUEST
        DB $00,$00,$00,$00  ; encoded display text; high-bit terminator

TEXT_ES_TIEMPOPUNTEO:
        DB $02,"TIEMPO:",$06  ; encoded display text; high-bit terminator

TEXT_ES_PUNTEO:
        DB $03,"PUNTEO",$BA  ; encoded display text; high-bit terminator

TEXT_ES_TIEMPO_EXTENDID:
        DB $08,"TIEMPO@EXTENDID",$CF  ; encoded display text; high-bit terminator

TEXT_ES_CAMBIELO_A_MENOS_VELOCIDA:
        DB $03,"CAMBIELO@A@MENOS@VELOCIDA",$C4  ; encoded display text; high-bit terminator

TEXT_ES_CAMBIELO_AMAS_VELOCIDA:
        DB $04,"CAMBIELO@AMAS@VELOCIDA",$C4  ; encoded display text; high-bit terminator

TEXT_ES_JUEGO_TERMINAD:
        DB $08,"JUEGO@TERMINAD",$CF  ; encoded display text; high-bit terminator

TEXT_ES_FELICITACIONE:
        DB $09,"FELICITACIONE",$D3  ; encoded display text; high-bit terminator

TEXT_ES_HICISTE_UN_NUEVO_RECO:
        DB $05,"HICISTE@UN@NUEVO@RECO",$D2  ; encoded display text; high-bit terminator

TEXT_ES_TU_PUNTEO_E:
        DB $0A,"TU@PUNTEO@E",$D3  ; encoded display text; high-bit terminator

TEXT_ES_LLEVAS_LA_DELANTER:
        DB $06,"LLEVAS@LA@DELANTER",$C1  ; encoded display text; high-bit terminator

TEXT_ES_VA_EN_SEGUNDO_LUGA:
        DB $07,"VA@EN@SEGUNDO@LUGA",$D2  ; encoded display text; high-bit terminator

TEXT_ES_LLANTAS_CALIENTE:
        DB $07,"LLANTAS@CALIENTE",$D3  ; encoded display text; high-bit terminator

TEXT_ES_SEGUNDO_PUEST:
        DB $06  ; encoded display text; high-bit terminator

TEXT_ES_SEGUNDO_PUEST_17BE:
        DB $03,"SEGUNDO@PUEST",$CF  ; encoded display text; high-bit terminator

TEXT_ES_PRIMER_PUEST:
        DB $06  ; encoded display text; high-bit terminator

TEXT_ES_PRIMER_PUEST_17CE:
        DB $03,"PRIMER@PUEST",$CF  ; encoded display text; high-bit terminator

TEXT_ES_PONGA_LA_MONED:
        DB $08,"PONGA@LA@MONED",$C1  ; encoded display text; high-bit terminator

TEXT_ES_AGACHA_EL_BOTO:
        DB $08,"AGACHA@EL@BOTO",$CE  ; encoded display text; high-bit terminator
        DB $FF,$FF  ; encoded display text; high-bit terminator
        DB $FF,$FF  ; encoded display text; high-bit terminator
