; MIG Inspector by M.G.

; Displays the MIG RAM from the Apple IIc Plus
; this is used by the 3.5 drive firmware and the
; accelerator.

; When run, 4 pages of the MIG RAM are displayed and
; are left at $1000 when the program is exited.

; Keys:
; Arrows - change pages in view
; 0 - 9 - jump to page n*7, 0 = page 0, 9 = page 63
; ESC - quit
; ~ - Jump to page 0 and copy all 2K of the MIG to
; $1000-$17FF.
;
; The program will exit with ERR if the machine is not
; a IIc Plus (this behavior can be changed).
;
; There are some build options below.

.psc02                        ; IIc Plus ship with a 65C02
.code

; build options
SKIPROMID = 1                 ; Skip ROM identification.  Lets you use on a 
                              ; non-IIc Plus, but obviously isn't useful beyond 
                              ; some testing purposes

SMALLVER  = 0                 ; Make a smaller mig inspector implies SKIPROMID
                              ; this option is useful in case you need to type
                              ; it in by hand.  Removes left/right arrows,
                              ; digit jumps, and tilde.

; entry points
COut1     = $fdf0
TabV      = $fb5b             ; vertical tab to A register, set CV
PrByte    = $fdda             ; print A as hex
Home      = $fc58             ; clear screen
VTab      = $fc22             ; vertical tab to CV
PrErr     = $ff2d             ; print "ERR"
KeyIn     = $fd1b             ; get keypress in A

; locs
CH        = $24               ; cursor horizontal
CV        = $25               ; cursor vertical
Buffer    = $1000             ; buffer for data from MIG
ROMBank   = $c028             ; ROM bank toggle
MigBase   = $ce00             ; MIG base address
MigRAM    = MigBase           ; location of RAM window in MIG
MigPage0  = MigBase+$A0       ; location to set window to 0
MigPageI  = MigBase+$20       ; location to increment window
BufPtr    = $06               ; buffer pointer
MigPage   = $08               ; desired MIG RAM page #

          .org  $2000
          
          cld

.if SKIPROMID | SMALLVER
          ; omit ROM identification
.else
          lda   $fbb3           ; first check for Apple IIc
          cmp   #$06
          bne   badid
          lda   $fbc0
          cmp   #$00
          bne   badid
          lda   $fbbf           ; check for Plus
          cmp   #$05
          beq   init            ; all good!
badid:    jmp   PrErr
.endif

init:     stz   MigPage
          lda   #$91
          jsr   COut1           ; go to 40 cols if 80 col firmware active
          jsr   Home

.if SMALLVER
          ; omit credit message
.else
          lda   #23
          jsr   TabV
          ldy   #$00
:         lda   mmsg,y
          beq   dispmig
          eor   #$80
          jsr   COut1
          iny
          bra   :-
mmsg:     .byte "MIG Inspector by M.G.  11/09/2017"
          .byte $00
.endif

dispmig:  jsr   get4mig         ; 4 mig pages to buffer
          jsr   d4page
uinput:   lda   #' '+$80
          jsr   KeyIn
          cmp   #$8b            ; up arrow
          bne   :+
goup:     dec   MigPage
          bra   dispmig
:         cmp   #$8a            ; down arrow
          bne   :+
godn:     inc   MigPage
          bra   dispmig
.if SMALLVER
          ; omit left/right arrows and tilde
.else
:         cmp   #$88            ; left arrow
          beq   goup
          cmp   #$95            ; right arrow
          beq   godn
          cmp   #'~'+$80        ; tilde - git all MIG RAM to $1000
          bne   :+
          jsr   getallmig
          bra   dispmig
.endif
.if SMALLVER
          ; no 0-9 jump
:         cmp   #$9b
          bne   uinput
          rts
.else
:         cmp   #$9b            ; escape
          bne   jump
          rts
jump:     sbc   #$b0            ; check for digit for page jump
          bmi   uinput          ; nope
          cmp   #10             ; 10 or bigger?
          bcs   uinput          ; also nope
          sta   MigPage         ; compute digit * 7
          asl                   ; * 2
          asl                   ; * 4
          asl                   ; * 8
          sec
          sbc   MigPage         ; * 7
          sta   MigPage
          bra   dispmig
.endif

; display 4 MIG pages on screen
.proc     d4page
          jsr   rsetbptr
          lda   #$00
          jsr   TabV
          ldx   #$00
:         stz   CH
          txa
          clc
          adc   MigPage
          and   #$3f
          jsr   PrByte
          lda   #':'+$80
          jsr   COut1
          jsr   d4line
          inc   CV
          jsr   VTab
          inx
          cpx   #$04
          bne   :-
          rts
.endproc

; display 4 lines at BufPtr, inc bufptr as we go
; assume CV is where we want it to be
.proc     d4line
          phx
          ldx   #$03
:         jsr   dline
          inc   CV
          jsr   VTab
          lda   #$08
          jsr   addbptr
          dex
          bpl   :-
          plx
          rts
.endproc

; display 1 line at BufPtr
.proc     dline
          lda   #4
          sta   CH
          ldy   #$00            ; start hex display
:         lda   (BufPtr),y
          jsr   PrByte
          lda   #' '+$80
          jsr   COut1
          iny
          cpy   #$08            ; done?
          bne   :-              ; nope, next hex
          ldy   #$00            ; start ASCII display
:         lda   (BufPtr),y
          ora   #$80
          cmp   #' '+$80        ; space
          bcs   :+              ; if not ctrl char
          lda   #'.'+$80        ; if so, use dot
:         jsr   COut1
          iny
          cpy   #$08            ; done?
          bne   :--             ; nope, next ASCII
          rts
.endproc

; reset BufPtr.  Preserves regs.
.proc     rsetbptr
          pha
          lda   #<Buffer
          sta   BufPtr
          lda   #>Buffer
          sta   BufPtr+1
          pla
          rts
.endproc

; add A to BufPtr
.proc     addbptr
          clc
          adc   BufPtr
          bcc   done
          inc   BufPtr+1
done:     sta   BufPtr
          rts
.endproc

.if SMALLVER
          ; omit getallmig
.else
; copy all mig pages (2048 bytes) to (bufptr)          
.proc     getallmig
          stz   MigPage
          ldx   #$3f
          bra   getxmig
.endproc
.endif

; copy 4 mig pages (128 bytes) to (bufptr)          
.proc     get4mig
          ldx #$03
          ; fall through
.endproc

; copy x+1 mig pages (x*32 bytes) to (bufptr)
.proc     getxmig
          lda   MigPage
          and   #$3f            ; enforce range
          sta   MigPage
          sta   ROMBank         ; mig only visible when alt ROM switched in
          jsr   setmigpg
          jsr   rsetbptr
:         jsr   copymig
          lda   #$20
          jsr   addbptr         ; next buffer segment
          bit   MigPageI        ; next MIG page
          dex
          bpl   :-
          sta   ROMBank
          rts
.endproc

; copy one mig page (32 bytes) to (bufptr)
; preserves x
.proc     copymig
          phy
          ldy   #$1f
:         lda   MigRAM,y
          sta   (BufPtr),y
          dey
          bpl   :-
          ply
          rts
.endproc

; set MIG page to the the one specified
; in MigPage.  Preserves regs.
.proc     setmigpg
          phx
          bit   MigPage0
          ldx   MigPage
          beq   done
:         bit   MigPageI
          dex
          bne   :-
done:     plx
          rts
.endproc
