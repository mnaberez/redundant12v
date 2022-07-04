;ATtiny212
;1 VCC
;2 PA6 TX -> MAX232CPE  T1IN 11 -> T1OUT 14 -> DB9 TX 2
;3 PA7 RX <- MAX232CPE R1OUT 12 <-  R1IN 13 <- DB9 RX 3
;4 PA1
;5 PA2
;6 UPDI
;7 EXTCLK
;8 GND    -> DB9 GND 5

    .area code (abs)

    .include "tn212def.asm"

    .org PROGMEM_START
    rjmp reset

    .org PROGMEM_START+INT_VECTORS_SIZE

reset:
  	;Initialize stack pointer
    ldi r16, RAMEND & 0xFF
    out CPU_SPL, r16
    ldi r16, RAMEND >> 8
    out CPU_SPH, r16

  	;Disable clock prescaler
  	clr r16
  	ldi r17, CPU_CCP_IOREG_gc
  	sts CPU_CCP, r17					        ;Unlock Protected I/O Registers
  	sts CLKCTRL_MCLKCTRLB, r16			  ;Disable clock prescaler

  	;Switch to external 1.8432 MHz oscillator
  	ldi r16, CLKCTRL_CLKSEL_EXTCLK_gc	;EXTCLK 1.8432 MHz external clock
  	sts CPU_CCP, r17					        ;Unlock Protected I/O Registers
  	sts CLKCTRL_MCLKCTRLA, r16			  ;Use EXTCLK for main clock

main:
    rcall uart_init

loop:
    rcall uart_chrin
    cpi r16, '\r            ;received '\r'?
    brne loop               ;no: ignore and wait for next char

    ;received '\r'
    ;send status like "PS0=OK,PS1=OK\r\n"

    ldi r16, 0              ;power supply 0
    rcall check_ps          ;check it
    rcall send_ps_status    ;print "PS0=OK" or "PS0=FAIL"

    ldi r16, ',
    rcall uart_chrout

    ldi r16, 1              ;power supply 1
    rcall check_ps          ;check it
    rcall send_ps_status    ;print "PS1=OK" or "PS1=FAIL"

    ldi r16, '\r
    rcall uart_chrout
    ldi r16, '\n
    rcall uart_chrout

    rjmp loop

;Check if a power supply is up or down
;R16=power supply number (0-1)
;Preserves R16
;Returns status in R17 (0=ok,1=fail)
check_ps:
    push r16
    rcall delay_25ms
    pop r16
    ldi r17, 0
    ret

;Send "PSn=OK" or "PSn=FAIL"
;R16=power supply number (0-1)
;R17=status (0=ok, 1=fail)
send_ps_status:
    push r17            ;push status
    push r16            ;push power supply number

    ldi r16, 'P
    rcall uart_chrout
    ldi r16, 'S
    rcall uart_chrout
    pop r16             ;pop power supply number
    ori r16, 0x30       ;convert to ascii
    rcall uart_chrout
    ldi r16, '=
    rcall uart_chrout

    pop r16             ;pop status
    cpi r16, 0
    brne fail           ;branch if status is not ok

    ldi r16, 'O
    rcall uart_chrout
    ldi r16, 'K
    rcall uart_chrout
    ret
fail:
    ldi r16, 'F
    rcall uart_chrout
    ldi r16, 'A
    rcall uart_chrout
    ldi r16, 'I
    rcall uart_chrout
    ldi r16, 'L
    rcall uart_chrout
    ret

uart_init:
    ;#define F_CPU 1843200
    ;#define USART0_BAUD_RATE(BAUD_RATE) ((float)(F_CPU * 64 / (16 * (float)BAUD_RATE)) + 0.5)
    ;USART0.BAUD = (uint16_t)USART0_BAUD_RATE(9600);
    clr r16
    sts USART0_BAUDL, r16
    ldi r16, 0x03
    sts USART0_BAUDH, r16

  	;USART0.CTRLC = USART_CMODE_ASYNCHRONOUS_gc /* Asynchronous Mode */
  	;	 | USART_CHSIZE_8BIT_gc /* Character size: 8 bit */
  	;	 | USART_PMODE_DISABLED_gc /* No Parity */
  	;	 | USART_SBMODE_1BIT_gc; /* 1 stop bit */
    ldi r16, USART_NORMAL_CMODE_ASYNCHRONOUS_gc | USART_NORMAL_CHSIZE_8BIT_gc | USART_NORMAL_PMODE_DISABLED_gc | USART_NORMAL_SBMODE_1BIT_gc
    sts USART0_CTRLC, r16

    ;PORTA.DIR &= ~PIN7_bm;  // pa7 = rx
    ;PORTA.DIR |= PIN6_bm;   // pa6 = tx
    lds r16, PORTA_base + PORT_DIR_offset
    andi r16, 0b01111111 ;pa7 = rx
    ori  r16, 0b01000000 ;pa6 = tx
    sts PORTA_base + PORT_DIR_offset, r16

    ;USART0.CTRLB |= USART_TXEN_bm | USART_TXEN_bm;
    lds r16, USART0_CTRLB
    ori r16, USART_TXEN_bm | USART_RXEN_bm
    sts USART0_CTRLB, r16
    ret


uart_chrin:
    ;while (!(USART0.STATUS & USART_RXCIF_bm)) {}
    lds r16, USART0_STATUS
    sbrs r16, USART_RXCIF_bp
    rjmp uart_chrin
    ;return USART0.RXDATAL;
    lds r16, USART0_RXDATAL
    ret


uart_chrout:
    ;while (!(USART0.STATUS & USART_DREIF_bm)) {}
    lds r17, USART0_STATUS
    sbrs r17, USART_DREIF_bp
    rjmp uart_chrout
    ;USART0.TXDATAL = c;
    sts USART0_TXDATAL, r16
    ret


;Wait 25ms.  Destroys R16-R18
delay_25ms:
    ldi r18, 25
wait3:
    rcall delay_1ms
    dec r18
    brne wait3
    ret

;Wait 1ms.  Destroy R16-R17
delay_1ms:
    ldi r16, 6
wait2:
    ldi r17, 0xc5
wait:
    dec r17 ; Decrement r17
    brne wait ; Branch if r17<>0
    dec r16
    brne wait2
    ret
