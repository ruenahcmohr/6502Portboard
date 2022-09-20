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

  ;--  Notes on 6522 T2 --      
  ;  
  ;  - The divider ONLY comes off the 8 bits of the counter
  ;  - loading T2CH will reload from the latch
  ;  - the first interval is wasted on pre-high time.
  ;  - the first interval starts after the completion of the last interval
  ;
  ;--


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
  
  .org $F800
  .byte $00   ; get assembler to offset image properly
  
Delay_ctr0 = $00 
Delay_ctr1 = $01

TxD        = $02
TxMask     = $03
RxD_T      = $04
RxDR       = $05

BRInput    = $06
BROutput   = $07

StrPtrL    = $08
StrPtrH    = $09

; ------------------------------------------
; page 1 (F900-F9FF) is used by the stack


; ===========================| code begin |==================================
  .org $FA00 ;code starts here!

reset:
  sei       ; interrupts off!
  ldx #$FF  ; init stack
  txs     
  
init:  
  stx P6522A+VIA_DDRB  ; port B all output  
  
  jsr Timer1Init        ; init serial transmitter stuff. PB0 is TxD serial line
  lda #$00
  sta TxMask
  lda #$01             ; set txd bit, PB0 on 6522
  ora P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB
  
  jsr ShiftInit        ; init serial reciever stuff
  jsr EdgeIRQInit 
  
  
    
 ; ---------------------------| main loup |-------------------------------- 
main:  

  lda #$02             ; toggle bit 1 of port B (heartbeat for me)
  eor P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB  
  

  jsr Delay1
 
;  lda #<message
;  sta StrPtrL
;  lda #>message
;  sta StrPtrH
 
;  jsr PrintString
 
 jsr getChar
 jsr sendChar
 
 

 jmp main


infinite:           ; wait (this should be a halt)
  jmp infinite





;---------------------------| initialize 6522 shift register for serial Rx|----------------------------
;
; Don't enable the interrupt!
;
ShiftInit:

  lda #$35            ; the tme here doesn't matter, the edge interrupt adjusts it.
  sta P6522A+VIA_T2CL

  lda #$04            ; shift register under T2 timing.
  ora P6522A+VIA_ACR
  sta P6522A+VIA_ACR  

  rts

;---------------------------| initialize 6522 edge interrupts for serial Rx|----------------------------
EdgeIRQInit:
  ; PCR = 001-----
  lda #$20            ; falling edge interrupt on CB2
  ora P6522A+VIA_PCR
  sta P6522A+VIA_PCR
  lda #$88
  sta P6522A+VIA_IFR  ; clear  CB2 interrupt flag
  sta P6522A+VIA_IER  ; enable CB2 interrupt 
  cli                 ; enable system interrupts
  
  rts


;---------------------------| initialize 6522 T2 for serial Tx|----------------------------
Timer1Init:
                       
  lda #$40             ; continious interrupt mode
  ora P6522A+VIA_ACR
  sta P6522A+VIA_ACR
  
  ; timer value, write lsb first 
  ;  833 for 1200 baud (0x0341)
  ;* 102 for 9600 baud (0x0066)
  lda #$66              
  sta P6522A+VIA_T1LL
  lda #$00
  sta P6522A+VIA_T1LH
       
  rts
  
;---------------------------| initialize 6522 T1 for serial Rx|----------------------------  
Timer2Init:
   ; its pretty dynamic, so I won't bother with any code here
  rts  
  
  
; ===================| print string |===================
PrintString:
  ldy #0          ; reset offset pointer  
PSLoup:
  lda (StrPtrL),y   ; send chars
  beq msgdone
  jsr sendChar
  iny
  jmp PSLoup
msgdone:
  lda #$0A
  jsr sendChar
  rts

;  ===================| fixed delays |===================
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
 
 
; ==================| BIT REVERSE BY Chuck (kinda >:/ ) |===================
BitRev: 
          ldx #8         ; 8 bits
BRLoop:   rol BRInput    ; bit into Carry
          ror BROutput   ; Carry into output
          dex            ; loop 8x
          bne BRLoop
          rts
 

;=======================| Serial Tx function set |======================
;
; awe well now you did it, your locking us into getting a character from the 
; serial port... OK...
;
getChar:
  lda #$00  ; clear out 'buffer'
  sta RxDR

SerialRxWait:  
  lda RxDR
  beq SerialRxWait
  
  ; ok, now is the fun part, we have to reverse the bits
  lda RxD_T
  sta BRInput
  jsr BitRev
  lda BROutput
  rts 
 
 
;=======================| Serial Tx function set |======================
;
; the code rewrites the jsr for whatever function needs to be performed
; in the loop, but the high appearance of the memory is not writable
; subtracting $C000 is the same memory address, but in the writable appearance
;



; -----------| Bit delay |----------------
; use the timer to do a bit delay
; T1, freerunning
; poll IFR bit 6
; should be able to do this with interrupts, but its not working...
; which doesn't really matter, cause what else you gonna do while your waiting for
; your character to send? REALLY.

txBitDelay: 
 
 lda P6522A+VIA_T1CL  ; clear interrupt flag
 
 lda #$40   ; wait for T1 rollover flag
txDelayWait:          
 bit P6522A+VIA_IFR
 beq txDelayWait 
 
 rts


;--------------| Setup and start transmission |-------------
sendChar:

 sta TxD              ; save data to be transmitted
 
 lda #$01             ; set up shift mask
 sta TxMask           
 
 
 lda P6522A+VIA_T1LH  ; This -RESTARTS- the timer, we are now timing the stop bit of the last transmission.
 sta P6522A+VIA_T1CH  
  
 lda #<txStart        ; reset handler fn.
 sta txFunNext-$C000
 lda #>txStart
 sta txFunNext+1-$C000   
  
sendCharLoup:    
 jsr txBitDelay       ; wait for time
 
 .byte $20           ; jsr [nextfn]              ; do thing
txFunNext:           ; I'm running from NVRAM, so the rewrites don't matter
 .byte <txStart      ; this is faster than a call to an indirect jump
 .byte >txStart      ; I suppose I COULD be evil and push a pile of return addresses 
                     ; to the stack and then do an rts }:]  whatever.
 
 lda TxMask          ; TxMask will shift from 0x01 to 0x80, then go to FF, then 00 when everything is done.
 bne sendCharLoup
 
 rts






; -------------| send start bit |------------------
txStart:
  lda #$FE              ; txd bit goes low, using PB0 on the 6522
  and P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB  
  
  lda #<txBit           ; set up next handler fn
  sta txFunNext-$C000
  lda #>txBit
  sta txFunNext+1-$C000  
  
  rts
 
 

; ----------------| transmit a bit |-------------
txBit:
  lda TxMask          ; check current bit
  bit TxD
  
  beq txZero
  
  lda #$01             ; set txd bit, PB0 on 6522
  ora P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB
  bne txPP             ; will always branch (ora was not zero)
  
txZero:  
  lda #$FE              ; clear txd bit, PB0 on 6522
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
  inc TxMask           ; TxMask = 00 (done)


  rts 
  
 
 
 
; //////////////////////////////////// INTERRUPT CODE \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
; 
;  this is all being used for serial recieve
;  due to that, its REALLY time critical
;  I'v coded it for a ~1.024MHz system, other speeds will need the timers adjusted.
;   All adjustments are done with logic capture watching RxD and CB1 while  intermittently 
;   sending the charater 'U' to the 6502 board.
; Good looks like:
; RxD -----____----____----____----____----____--------
; CB1--------____--__--__--__--__--__--__--__--__--__--... (dont mind about its extra cycles...)
;

; **** start of time critical part ****
edge_irq:
  pha

  lda #$08            ; was this becasue of a CB2 edge?
  bit P6522A+VIA_IFR  ; flags mean nothing...
  bit P6522A+VIA_IER  ; <-- if they weren't from enabled interrupts!
  beq IrqCheckTwo          ; if no, exit

;+++++++++++++++++++++++++++++| Edge Interrupt |++++++++++++++++++++++++++++
; - sync and start the timer
; - start the shift register
; - disable the edge detection

  lda #$04             ; "please reload soon" 
  sta P6522A+VIA_T2CL  ; The counter has to actually hit zero for the shift register to 
  sta P6522A+VIA_T2CH  ;  start at the right time. so were loading a short interval and forcing it.
    
  lda #$3E             ; This number accounts for irq service latency too 
                       ; Set this so that the first CB1 rising edge is in the middle of the first
                       ; high cycle when sent the character 'U'       
  sta P6522A+VIA_T2CL  ; ~150% of bit time with latency adjustments 

  lda P6522A+VIA_SR    ; trigger SR transfer (resets mod 8 counter, clear interrupt flag) 

  lda #$32             ; 100% of bit time will be loaded after the ~150% is done.
  sta P6522A+VIA_T2CL  ; 
        
; **** end of time critical part *****
 
  lda #$84
  sta P6522A+VIA_IER  ; enable transfer complete interrupt (was cleared by read of SR)  
  
  lda #$08
  sta P6522A+VIA_IER  ; disable edge interrupts  
  
  bne irqExit         ; always jumps
IrqCheckTwo:  


  lda #$04             ; was this becasue of a transfer complete?
  bit P6522A+VIA_IFR   
  bit P6522A+VIA_IER 
  beq irqExit        ; if no, next check

  ;++++++++++++++++++++++++| Transfer complete |++++++++++++++++++++++++
  ; - disable shift register interrupts
  ; - re-enable edge interrupt
  ; - capture transferred byte
  ; - set "I got one!" flag.
  
  lda #$88
  sta P6522A+VIA_IFR  ; clear the edge flags
  sta P6522A+VIA_IER  ; enable edge interrupts
  
  lda #$04
  sta P6522A+VIA_IER  ; disable transfer complete interrupt (was cleared by read of SR)   
  
  lda P6522A+VIA_SR   ; ugh, its going to start another transfer maybe we can ignore this?... 
  sta RxD_T     
  lda #$01        
  sta RxDR            ; set the data ready flag
  
;  --- clean up and ditch ---
irqExit:
  lda #$0C              ; clear both interrupt flags
  sta P6522A+VIA_IFR
  pla
  rti 


;--------

mt_irq:
  rti


message: 
  .asciiz "6522 Bit banged 9600 baud serial By Rue Mohr Sep 2022"

 

;INTERUPT VECTORS

  .org $FFFA
  ; boot
  .word reset
  
  ; NMI
  .word mt_irq
  
  ; INT
  .word edge_irq
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
; Hey you made to the bottom!
;  I'm a real person, you can talk to me
;  Twitter: @RueNahcMohr
;  IRC: Libera.chat  #robotics
