;*******************************************************************************
; 280-ZZZAP (1976)
;*******************************************************************************
; Native Intel 8080 arcade program for Midway hardware.
;
; Developer : Dave Nutting Associates
; Publisher : Midway
; CPU       : Intel 8080
; Original  : zzzaph / zzzapg / zzzapf / zzzape / zzzapd / zzzapc
; Build     : zmac v1.3
;
; The first ROM's reset, interrupt, restart and message-update entries are
; reconstructed below from original device zzzaph, addresses $0000–$0063.
; Additional ROM routines will be integrated at their original addresses.
;*******************************************************************************

        ORG $0000

; Clear audio output 2 and enter the native boot sequence.
RESET_ENTRY:
        NOP
        NOP
        XOR A
        OUT ($05),A
        JP $0064

; First interrupt phase: preserve registers and select phase 0.
IRQ_PHASE_ZERO:
        PUSH AF
        PUSH BC
        PUSH DE
        LD C,$00
        JP $069E

; Second interrupt phase: preserve registers and select phase 1.
IRQ_PHASE_ONE:
        PUSH AF
        PUSH BC
        PUSH DE
        LD C,$01
        JP $069E

; Save register context, resume execution at the RST caller.
; The return address is exchanged with HL before the register save.
RST18_SAVE_REGISTER_CONTEXT:
        EX (SP),HL
        PUSH DE
        PUSH BC
        PUSH AF
        JP (HL)

; Three per-game extended-time parameter bytes used by the time service.
EXTENDED_TIME_SETTINGS:
        DB $25,$30,$20

; Complementary RST service: drop the service return address and restore
; the saved registers, then return to the preceding native caller.
RST20_RESTORE_REGISTER_CONTEXT:
        POP HL
        POP AF
        POP BC
        POP DE
        POP HL
        RET

; Two bytes between the restore service and next restart vector.
RST20_TRAILING_BYTES:
        DB $35,$00

; Native restart jump to the display routine at $0F16.
RST28_DISPLAY_SERVICE:
        JP $0F16

; Five-byte linked drawing record:
;   byte 0     duration/countdown
;   bytes 1–2  bitmap record pointer
;   bytes 3–4  next drawing record pointer
INITIAL_DRAWING_RECORD:
        DB $05
        DW $04B4
        DW $0414

; Consume one inline byte following the caller's RST $30 instruction.
; Advancing the saved return address skips the argument on return.
RST30_INLINE_MESSAGE_UPDATE:
        EX (SP),HL
        LD A,(HL)
        INC HL
        EX (SP),HL
        CALL $0F91
        LD (HL),A

; Update the two bottom screen-message slots.
; Mask bits 0–4 of either slot to test whether a message is active.
MESSAGE_UPDATE_BOTTOM_SLOTS:
        RST $18
        LD HL,$205E
        LD A,(HL)
        INC HL
        OR (HL)
        AND $1F
        JP Z,MESSAGE_CLEAR_BOTTOM_LINES

; Prepare the message field, then render the active slot contents.
MESSAGE_SHOW_BOTTOM_LINES:
        LD BC,$1DFF
        CALL $0162

        LD HL,$205E
        LD A,(HL)
        CALL $0F5E
        INC HL
        LD A,(HL)
        CALL $0F5E
        RST $20

; Clear the field to white and return through the drawing service.
MESSAGE_FILL_BOTTOM_WHITE:
        LD BC,$1DFF
        JP $0162

; Clear the field to black when both message slots are empty.
MESSAGE_CLEAR_BOTTOM_LINES:
        LD BC,$1D00
        CALL $0162
        RST $20

;*******************************************************************************
; Native boot initialization follows at $0064.
;*******************************************************************************
