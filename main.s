;6502 servo project.
; vasm6502_oldstyle -Fbin -pad=0xff -dotdir -o main.bin main.s
; minipro -p 2816 -w /morfiles/programming/asm/6502/6502servo/main.bin


; the memory on this system is shadowed to be accessed from 0000-FFFF
; 
;  0000-07FF Real memory
;  0800-3FFF repeats
;
;  4000-400F 6522 #1
;  4010-401F 6522 #2
;  4020-7FFF repeats
;
;  8000-8003 8255
;  8004-DFFF repeats
;
;  C000-F7FF repeats of...
;  F800-FFFF repeat of memory

; becasue the 6502 likes to do dummy writes to 0xFFFF
; we need some fancy address decoding ;]


P6522A   = $4000
P6522B   = $4010
P8255    = $8000


VIA_PORTB  = $00
VIA_PORTA  = $01
VIA_DDRB   = $02
VIA_DDRA   = $03

VIA_T1CL   = $04
VIA_T1CH   = $05
VIA_T1LL   = $06
VIA_T1LH   = $07

VIA_T2CL   = $08
VIA_T2CH   = $09

VIA_SR     = $0A
VIA_ACR    = $0B
VIA_PCR    = $0C
VIA_IFR    = $0D
VIA_IER    = $0E
VIA_ORA2   = $0F

; ------------------------------------------
; I'm going to abstract this all to high memory
; Ram: (page 0)  0xF800 - 0xF8FF (R/W)
; Stack:         0xF900 - 0xF9FF
; Program:       0xFA00 - 0xFFFF (RO)

; === this is page 0 stuff ===
  ; get assembler to offset image properly
  .org $F800
  .byte $00
  
Delay_ctr0 = $00 
Delay_ctr1 = $01

TxD        = $02
TxMask     = $03
RxD        = $04
RxMask     = $05


; ------------------------------------------
; page 1 (F900-F9FF) is used by the stack


; ------------------------------------------
  .org $FA00 ;code starts here!

reset:
  ldx #$FF  ; init stack
  txs     
  
init:  
  stx P6522A+VIA_DDRB  ; port B output  
  
  jsr TimerInit   ; initialize timer
  lda #$00
  sta TxMask
  
main:  


  brk   ; trigger interrupt routine
  nop
  nop

  jsr Delay1
 
printMessage:
  ldx #0          ; reset offset pointer
  
busy2:
  lda message,x   ; send chars
  beq msgdone
  jsr sendChar
  inx
  jmp busy2
msgdone:
  lda #$0A
  jsr sendChar

 jmp main


infinite:           ; wait (this should be a halt)
  jmp infinite


;---------------------------------------------------------------------

EdgeIRQInit:
  

  rts


TimerInit:
                       ; set up interrupts


  lda #$40             ; continious, XXXX squarewave out on PB7 XXX
  sta P6522A+VIA_ACR
  
;  lda #$41             ; timer value, write lsb first (833 for 1200 baud (0x0341))
  lda #$66              ; 0x0068 for 9600 baud.
  sta P6522A+VIA_T1LL
;  lda #$03
  lda #$00
  sta P6522A+VIA_T1LH
  
 ; sta P6522A+VIA_T1CH  ; This actually -STARTS- the timer, reading T1CL won't  
 
  
  
 
 
  rts


; ------------------------------------------
Delay1:
  lda #$FF
  sta Delay_ctr0
dloup1:
  dec Delay_ctr0
  bne dloup1
  rts

Delay2:
  lda #$FF
  sta Delay_ctr1
dloup2:
  jsr Delay1
  dec Delay_ctr1
  bne dloup2
  rts
 
 
;------------------------------------------------------------------------
; the code rewrites the jsr for whatever function needs to be performed
; in the loop, but the high appearance of the memory is not writable
; subtracting $C000 is the same memory address, but in the writable appearance
;
sendChar:

 sta TxD              ; save data to be transmitted
 
 lda #$01             ; set up shift mask
 sta TxMask
 
 lda #$40             ; continious interrupts
 sta P6522A+VIA_ACR
 lda P6522A+VIA_T1CL  ; clear any interrupt flags
 
 lda P6522A+VIA_T1LH
 sta P6522A+VIA_T1CH  ; This actually -STARTS- the timer, reading T1CL won't  
  
 lda #<txStart        ; reset handler fn.
 sta txFunNext-$C000
 lda #>txStart
 sta txFunNext+1-$C000   
  

sendCharLoup:    
 jsr txBitDelay       ; wait for time
 
 .byte $20           ; jsr [nextfn]              ; do thing
txFunNext:
 .byte <txStart 
 .byte >txStart
 
 
 lda TxMask
 bne sendCharLoup
 
 rts


; ------------------------------------------
; use the timer to do a bit delay
; T1, freerunning
; poll IFR bit 6
; should be able to do this with interrupts, but its not working...

txBitDelay: 
 
 lda P6522A+VIA_T1CL  ; clear interrupt flag
 
 lda #$40   ; wait for flag
txDelayWait:          
 bit P6522A+VIA_IFR
 beq txDelayWait 
 
 rts





; ------------------------------------------
txStart:
  lda #$FE              ; clear txd bit
  and P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB  
  
  lda #<txBit           ; set up next handler fn
  sta txFunNext-$C000
  lda #>txBit
  sta txFunNext+1-$C000  

  
  rts
 
 

; ------------------------------------------
txBit:
  lda TxMask          ; check current bit
  bit TxD
  
  beq txZero
  
  lda #$01             ; set txd bit
  ora P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB
  bne txPP             ; will always branch (ora was not zero)
  
txZero:  
  lda #$FE              ; clear txd bit
  and P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB  

txPP:  
  asl TxMask
  beq txNextFn   ; if there are no more bits left, change the handler fn.
  
  rts
  
txNextFn:
  dec TxMask    ; set TxMask to 0xFF

  lda #<txStop
  sta txFunNext-$C000
  lda #>txStop
  sta txFunNext+1-$C000 
  rts  
  

; ------------------------------------------ 
; the timing of the stop bit is actually the latency of 
;  the start bit ;]
txStop:
  lda #$01             ; set txd bit
  ora P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB
                       ; disable timer
  inc TxMask           ; stop
  lda #$40             ; disable T1 interrupt
  sta P6522A+VIA_IER

  rts 
  
 
 
 
; ------------------------------------------ 
mt_irq:
;  pha

  lda #$02             ; toggle bit 1 of port B
  eor P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB  

;  pla
  rti 



message: 
  .asciiz "6522 Bit banged 9600 baud serial By Rue Mohr"

 

;INTERUPT VECTORS

  .org $FFFA
  ; boot
  .word reset
  
  ; NMI
  .word mt_irq
  
  ; INT
  .word mt_irq
 
 
