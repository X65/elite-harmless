; "Elite" C64 disassembly / "Elite DX", cc0 2018, see LICENSE.txt
; "Elite" is copyright / trademark David Braben & Ian Bell, All Rights Reserved
; <github.com/Kroc/EliteDX>
;===============================================================================

; "elite_init.asm" : contains intialisation code and graphics data

.include        "c64.asm"
.include        "elite_consts.asm"

;-------------------------------------------------------------------------------

.zeropage

ZP_COPY_TO      := $18
ZP_COPY_FROM    := $1a

;-------------------------------------------------------------------------------

.segment        "CODE_INIT"
.export         __CODE_INIT__:absolute = 1

_75e4:                                                                  ;$75E4
        ; this code will switch the VIC-II bank to $4000..$8000;
        ; all graphics to be displayed (characters, sprites, bitmaps)
        ; must therfore exist within this memory range

        ; the program file on disk uses the bitmap screen area ($4000..$6000)
        ; to store some code & data, which gets relocated during this routine.
        ; this is so that the disk file can be smaller by making use of space
        ; that would otherwise consist mostly of zeroes

        ; copy $4000..$5600 to $0700..$1D00:

        ; oddly, $4000..$4800 would be the character set, however only graphics
        ; for $4400..$4700 are defined, therefore the [used] character graphics
        ; get copied to $0B00..$0E00 (the rest is other data)
        
        ldx # $16               ; size of block-copy -- 22 x 256 = 5'632 bytes
        lda #< $0700
        sta ZP_COPY_TO+0
        lda #> $0700
        sta ZP_COPY_TO+1
        lda #< $4000
        sta ZP_COPY_FROM+0
        lda #> $4000
        jsr copy_bytes

        ;-----------------------------------------------------------------------

        ; disable interrupts:
        ; (we'll be configuring screen & sprites)
        sei
    
        ; change the C64's memory layout:
        ; bits 0-2 of the processor port ($01) control the memory banks,
        ; a value of of %xxxxx100 turns off all ROM shadows (KERNAL, BASIC,
        ; and character ROM) enabling all 64 KB RAM for use
        lda CPU_CONTROL         ; get the current processor port value
        and # %11111000         ; reset bottom 3 bits and keep top 5 unchanged
        ora # MEM_64K           ; turn all ROM shadows off, gives 64K of RAM
        sta CPU_CONTROL

        ; relocate part of the binary payload in "gma4.prg" --
        ; copy $5600..$7F00 to $D000..$F900 -- note that includes this code!

        ldx # $29               ; size of block-copy -- 41 x 256 = 10'496 bytes
        lda #< $d000
        sta ZP_COPY_TO+0
        lda #> $d000
        sta ZP_COPY_TO+1
        lda #< $5600
        sta ZP_COPY_FROM+0
        lda #> $5600
        jsr copy_bytes

        ; switch the I/O area back on:
        lda CPU_CONTROL         ; get the current processor port value
        and # %11111000         ; reset bottom 3 bits, top 5 unchanged 
        ora # MEM_IO_ONLY       ; switch I/O on, BASIC & KERNAL ROM off
        sta CPU_CONTROL

        lda $dd02               ; read Port A ($DD00) data-direction register
        ora # %00000011         ; set bits 0/1 to R+W, all others read-only
        sta $dd02

        ; set the VIC-II to get screen / sprite
        ; data from the zone $4000-$7FFF

        lda $dd00               ; read the serial bus / VIC-II bank state
        and # %11111100         ; keep current value except bits 0-1 (VIC bank)
        ora # ELITE_VIC_DD00    ; set bits 0-1 to %10: bank 1, $4000..$8000
        sta $dd00

        ; enable interrupts and non-maskable interrupts generated by the A/B
        ; system timers. the bottom two bits control CIA timers A & B, and
        ; writes to $DC0D control normal interrupts, and writes to $DD0D
        ; control non-maskable interrupts
        lda # %00000011
        sta $dc0d               ; interrupt control / status register
        sta $dd0d               ; non-maskable interrupt register

        ; set up VIC-II memory:
        ; NOTE: during loading, the bitmap screen is not set at the same
        ;       location as it will be when the game begins?
        ;
        ; %1000xxxx = set text/colour screen to VIC+$2000,
        ;             colour map    @ $6000..$6400
        ; %xxxx000x = set character set to VIC+$0000
        ;             bitmap screen @ $4000..$6000
        ; %xxxxxxx1 = N/A! (but included in the original source)
        ;
        lda # ELITE_TXTSCR_D018 | %00000001
        sta VIC_MEMORY          ;=$d018, VIC-II memory control register

        lda # BLACK
        sta VIC_BORDER          ; set border colour black
        lda # BLACK
        sta VIC_BACKGROUND      ; set background colour black

        ; set up the bitmap screen:
        ; - bit 0-2: raster scroll (default value)
        ; - bit   3: 25 rows
        ; - bit   4: screen on
        ; - bit   5: bitmap mode on
        ; - bit 6-7: extended mode off / raster interrupt off
        lda # %00111011
        sta $d011

        ; further screen setup:
        ; - bit 0-2: horizontal scroll (0)
        ; - bit   3: 38 columns (borders inset)
        ; - bit   4: multi-color mode off
        lda # %11000000
        sta $d016

        ; disable all sprites
        lda # %00000000
        sta VIC_SPRITE_ENABLE

        ; set sprite 2 colour to brown
        lda # BROWN
        sta $d029
        ; set sprite 3 colour to medium-grey
        lda # GREY
        sta $d02a
        ; set sprite 4 colour to blue
        lda # BLUE
        sta $d02b
        ; set sprite 5 colour to white
        lda # WHITE
        sta $d02c
        ; set sprite 6 colour to green
        lda # GREEN
        sta $d02d
        ; set sprite 7 colour to brown
        lda # BROWN
        sta $d02e

        ; set sprite multi-colour 1 to orange
        lda # ORANGE
        sta $d025
        ; set sprite multi-colour 2 to yellow
        lda # YELLOW
        sta $d026

        ; set all sprites to single-colour
        ; (the trumbles are actually multi-colour,
        ;  so this must be changed at some point)
        lda # %00000000
        sta VIC_SPRITE_MULTICOLOR

        ; set all sprites to double-width, double-height
        lda # %11111111
        sta $d017               ; sprite double-height register
        sta $d01d               ; sprite double-width register

        ; set sprites' X 8th bit to 0;
        ; i.e all X-positions are < 256
        lda # $00
        sta $d010

        ; roughly centre sprite 0 on screen
        ; (crosshair?)
        ldx # 161
        ldy # 101
        stx VIC_SPRITE0_X
        sty VIC_SPRITE0_Y
        
        ; setup (but don't display) the trumbles
        lda # 18
        ldy # 12
        sta VIC_SPRITE1_X
        sty VIC_SPRITE1_Y
        asl a                   ; double x-position (=36)
        sta VIC_SPRITE2_X
        sty VIC_SPRITE2_Y
        asl a                   ; double x-position (=72)
        sta VIC_SPRITE3_X
        sty VIC_SPRITE3_Y
        asl a                   ; double x-position (=144)
        sta VIC_SPRITE4_X
        sty VIC_SPRITE4_Y
        lda # 14
        sta VIC_SPRITE5_X
        sty VIC_SPRITE5_Y
        asl a                   ; double x-position (=28)
        sta VIC_SPRITE6_X
        sty VIC_SPRITE6_Y
        asl a                   ; double x-position (=56)
        sta VIC_SPRITE7_X
        sty VIC_SPRITE7_Y

        ; set sprite priority: only sprite 1 is behind screen
        lda # %0000010
        sta VIC_SPRITE_PRIORITY

        ; clear the bitmap screen:
        ;-----------------------------------------------------------------------
        ; erase $4000-$6000

        lda # $00
        sta ZP_COPY_TO+0
        tay 
        ldx #> ELITE_BITMAP_ADDR

_76d8:  stx ZP_COPY_TO+1
:       sta (ZP_COPY_TO), y
        iny 
        bne :-
        ldx ZP_COPY_TO+1
        inx 
        cpx # $60
        bne _76d8

        ; erase $6000-$6800 (the two colour maps)
        ;-----------------------------------------------------------------------

        lda # $10
_76e8:  stx ZP_COPY_TO+1
:       sta (ZP_COPY_TO), y
        iny 
        bne :-
        ldx ZP_COPY_TO+1
        inx 
        cpx #> $6800
        bne _76e8

        ; copy 279 bytes of data to $66d0-$67E7
        ;-----------------------------------------------------------------------

        lda #< $66d0
        sta ZP_COPY_TO+0
        lda #> $66d0
        sta ZP_COPY_TO+1
        lda #< _783a
        sta ZP_COPY_FROM+0
        lda #> _783a
        jsr _7827

        ; set the screen-colours for the menu-screen:
        ; (high-resolution section only, no HUD)
        ;-----------------------------------------------------------------------

        lda #< ELITE_MENUSCR_COLOR_ADDR
        sta ZP_COPY_TO+0
        lda #> ELITE_MENUSCR_COLOR_ADDR
        sta ZP_COPY_TO+1

        ldx # 25                ; 25-rows

        ; colour the borders yellow down the sides of the view-port:

        ; yellow fore / black back colour
_7711:  lda # .color_nybbles( YELLOW, BLACK )
        ldy # 36                ; set the colour on column 37
        sta (ZP_COPY_TO), y
        ldy # 3                 ; set the colour on column 4
        sta (ZP_COPY_TO), y
        dey

        ; colour the area outside the viewport black
        lda # .color_nybbles( BLACK, BLACK )
:       sta (ZP_COPY_TO), y     ; set columns 2, 1 & 0 to black
        dey 
        bpl :-

        ldy # 37                ; begin at column 38
        sta (ZP_COPY_TO), y     ; set column 38 black
        iny 
        sta (ZP_COPY_TO), y     ; and column 39
        iny 
        sta (ZP_COPY_TO), y     ; and column 40
    
        ; move to the next row
        ; (add 40 columns)
        lda ZP_COPY_TO+0
        clc 
        adc # 40
        sta ZP_COPY_TO+0
        bcc :+
        inc ZP_COPY_TO+1
:       dex                     ; repeat for 25 rows
        bne _7711

        ; set the screen-colours for the high-resolution
        ; bitmap portion of the main flight-screen
        ;-----------------------------------------------------------------------

        lda #< ELITE_MAINSCR_COLOR_ADDR
        sta ZP_COPY_TO+0
        lda #> ELITE_MAINSCR_COLOR_ADDR
        sta ZP_COPY_TO+1

        ldx # $12               ; 18 rows

_7745:  lda # .color_nybbles( YELLOW, BLACK )
        ldy # 36
        sta (ZP_COPY_TO), y
        ldy # 3
        sta (ZP_COPY_TO), y
        dey
        lda # $00

_7752:  sta (ZP_COPY_TO), y
        dey 
        bpl _7752
        ldy # $25
        sta (ZP_COPY_TO), y
        iny 
        sta (ZP_COPY_TO), y
        iny 
        sta (ZP_COPY_TO), y
        lda ZP_COPY_TO+0
        clc 
        adc # 40
        sta ZP_COPY_TO+0
        bcc _776c
        inc ZP_COPY_TO+1
_776c:
        dex 
        bne _7745

        ; set yellow colour across the bottom row of the menu-screen
        ; write $70 from $63e4 to $63c4
        lda # .color_nybbles( YELLOW, BLACK )
        ldy # $1f               ; we'll write 31 chars (colour-cells)
:       sta ELITE_MENUSCR_COLOR_ADDR + (24 * 40) + 4, y
        dey 
        bpl :-

        ; set screen colours for the mult-colour bitmap
        ;-----------------------------------------------------------------------

        ; set $d800-$dc00 (colour RAM) to black
        lda # $00
        sta ZP_COPY_TO+0
        tay 
        ldx #> $d800
        stx ZP_COPY_TO+1

        ldx # $04               ; 4 x 256 = 1'024 bytes
_7784:  sta (ZP_COPY_TO), y
        iny 
        bne _7784
        inc ZP_COPY_TO+1
        dex 
        bne _7784

        ; colour the HUD:
        ;-----------------------------------------------------------------------
        ; copy 279? bytes from $795a to $d0da
        ; multi-colour bitmap colour nybbles

        lda #< $dad0
        sta ZP_COPY_TO+0
        lda #> $dad0
        sta ZP_COPY_TO+1
        lda #< $795a
        sta ZP_COPY_FROM+0
        lda #> $795a
        jsr _7827

        ; write $07 to $d802-$d824

        ldy # $22
        lda # $07
_77a3:  sta $d802,y
        dey 
        bne _77a3

        ; sprite indicies
        lda # $a0
        sta $63f8
        sta $67f8
        lda # $a4
        sta $63f9
        sta $67f9
        lda # $a5
        sta $63fa
        sta $67fa
        sta $63fc
        sta $67fc
        sta $63fe
        sta $67fe
        lda # $a6
        sta $63fb
        sta $67fb
        sta $63fd
        sta $67fd
        sta $63ff
        sta $67ff

        ;-----------------------------------------------------------------------

        lda CPU_CONTROL         ; get processor port state
        and # %11111000         ; retain everything except bits 0-2 
        ora # MEM_IO_KERNAL     ; I/O & KERNAL ON, BASIC OFF
        sta CPU_CONTROL

        ;-----------------------------------------------------------------------

        ; copy $7D7A..$867A to $EF90-$F890 (under the KERNAL ROM)
        ; -- HUD (backup?)

        ; get the location of the HUD data from the linker configuration
        ; TODO: calc size -- is wrong here due to HUD data being trimmed
.import __DATA_HUD_LOAD__, __DATA_HUD_SIZE__

        cli 

        ; number of whole pages to copy. note that, the lack of a rounding-up
        ; divide is fixed by adding just shy of one page before dividing,
        ; instead of just adding one to the result. this means that a round
        ; number of bytes, e.g. $1000 would not calculate as one more page
        ; than necessary 
        ldx #< ((__DATA_HUD_SIZE__ + 255) / 256)

        ; TODO: the copy-to location comes after the hull data,
        ;       handle this positioning in the linker config
        lda #< $ef90
        sta ZP_COPY_TO+0
        lda #> $ef90
        sta ZP_COPY_TO+1
        lda #< __DATA_HUD_LOAD__
        sta ZP_COPY_FROM+0
        lda #> __DATA_HUD_LOAD__
        jsr copy_bytes

        ;-----------------------------------------------------------------------

        ; copy $7A7A..$7B7A to $6800..$6900
        ; SPRITES!

        ldy # $00
_77ff:  lda $7a7a, y
        sta $6800, y
        dey 
        bne _77ff

        ; copy $7B7A..$7C7A to $6900..$6A00
        ; two sprites, plus a bunch of unknown data

_7808:  lda $7b7a, y
        sta $6900, y
        dey 
        bne _7808

        ;-----------------------------------------------------------------------

        ; NOTE: this memory address has been modified to say `jmp $038a`
        ; (part of 'loader/stage1.asm', GMA1.PRG)
        jmp $ce0e


.proc   copy_bytes                                                      ;$7814
        ;=======================================================================
        ; copies bytes from one address to another in 256 byte blocks
        ;
        ; $18/$19 = pointer to address to copy to
        ;     $1a = low-byte of address to copy from
        ;       A = high-byte of address to copy from (gets placed into $1b)
        ;       X = number of 265-byte blocks to copy

        sta ZP_COPY_FROM+1
        ldy # $00

:       lda (ZP_COPY_FROM), y                                           ;$7818
        sta (ZP_COPY_TO), y
        dey 
        bne :-
        inc ZP_COPY_FROM+1
        inc ZP_COPY_TO+1
        dex 
        bne :-
        rts

.endproc

.proc   _7827                                                           ;$7827
        ;=======================================================================
        ; copy 256-bytes using current parameters
        ldx # $01
        jsr copy_bytes

        ; copy a further 22 bytes
        ldy # $17
        ldx # $01
:       lda (ZP_COPY_FROM), y                                           ;$7830
        sta (ZP_COPY_TO), y
        dey 
        bpl :-
        ldx # $00
        rts

.endproc

;===============================================================================

; this is the decrypted version of the data in "gma4.prg"
; note: the first 279 bytes are copied via _7827 above

_783a:
        .byte   $00, $00, $00, $07, $17, $17, $74, $74                  ;$783A
        .byte   $74, $74, $27, $27, $27, $27, $27, $27
        .byte   $27, $27, $27, $27, $27, $27, $27, $27                  ;$784A
        .byte   $27, $27, $27, $27, $67, $27, $27, $27
        .byte   $27, $27, $37, $37, $07, $00, $00, $00                  ;$785A
        .byte   $00, $00, $00, $07, $17, $17, $24, $24
        .byte   $24, $24, $27, $27, $27, $27, $27, $27                  ;$786A
        .byte   $27, $27, $27, $27, $27, $27, $27, $27
        .byte   $27, $27, $67, $67, $67, $67, $23, $23                  ;$787A
        .byte   $23, $23, $37, $37, $07, $00, $00, $00
        .byte   $00, $00, $00, $07, $37, $37, $29, $29                  ;$788A
        .byte   $29, $29, $27, $27, $27, $27, $27, $27
        .byte   $27, $27, $27, $27, $27, $27, $27, $27                  ;$789A
        .byte   $27, $27, $27, $27, $67, $27, $23, $23
        .byte   $23, $23, $37, $37, $07, $00, $00, $00                  ;$78AA
        .byte   $00, $00, $00, $07, $37, $37, $28, $28
        .byte   $28, $28, $27, $27, $27, $27, $27, $27                  ;$78BA
        .byte   $27, $27, $27, $27, $27, $27, $27, $27
        .byte   $27, $27, $27, $27, $27, $27, $24, $24                  ;$78CA
        .byte   $24, $24, $17, $17, $07, $00, $00, $00
        .byte   $00, $00, $00, $07, $37, $37, $2a, $2a                  ;$78DA
        .byte   $2a, $2a, $27, $27, $27, $27, $27, $27
        .byte   $27, $27, $27, $27, $27, $27, $27, $27                  ;$78EA
        .byte   $27, $27, $27, $27, $27, $27, $24, $24
        .byte   $24, $24, $17, $17, $07, $00, $00, $00                  ;$78FA
        .byte   $00, $00, $00, $07, $37, $37, $2d, $2d
        .byte   $2d, $2d, $27, $07, $27, $27, $27, $27                  ;$790A
        .byte   $27, $27, $27, $27, $27, $27, $27, $27
        .byte   $27, $27, $27, $27, $07, $27, $24, $24                  ;$791A
        .byte   $24, $24, $17, $17, $07, $00, $00, $00
        .byte   $00, $00, $00, $07, $c7, $c7, $07, $07                  ;$792A
        .byte   $07, $07, $27, $07, $27, $27, $27, $27
        .byte   $27, $27, $27, $27, $27, $27, $27, $27                  ;$793A
        .byte   $27, $27, $27, $27, $07, $27, $24, $24
        .byte   $24, $24, $17, $17, $07, $00, $00, $00                  ;$794A
        .byte   $60, $d3, $66, $1d, $a0, $40, $b3, $d3
        .byte   $00, $00, $00, $00, $05, $05, $05, $05                  ;$795A
        .byte   $05, $05, $0d, $0d, $0d, $0d, $0d, $0d
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $0d, $0d                  ;$796A
        .byte   $0d, $0d, $05, $05, $05, $05, $05, $05
        .byte   $05, $05, $05, $05, $00, $00, $00, $00                  ;$797A
        .byte   $00, $00, $00, $00, $05, $05, $05, $05
        .byte   $05, $05, $0d, $0d, $0d, $0d, $0d, $0d                  ;$798A
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $0d, $0d
        .byte   $0d, $0d, $05, $05, $05, $05, $05, $05                  ;$799A
        .byte   $05, $05, $05, $05, $00, $00, $00, $00
        .byte   $00, $00, $00, $00, $05, $05, $05, $05                  ;$79AA
        .byte   $05, $05, $0d, $0d, $0d, $0d, $0d, $0d
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $0d, $0d                  ;$79BA
        .byte   $0d, $0d, $05, $05, $05, $05, $05, $05
        .byte   $05, $05, $05, $05, $00, $00, $00, $00                  ;$79CA
        .byte   $00, $00, $00, $00, $05, $05, $05, $05
        .byte   $05, $05, $0d, $0d, $0d, $0d, $0d, $0d                  ;$79DA
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $0d, $0d
        .byte   $0d, $0d, $0d, $05, $05, $05, $05, $05                  ;$79EA
        .byte   $05, $05, $05, $05, $00, $00, $00, $00
        .byte   $00, $00, $00, $00, $05, $05, $05, $05                  ;$79FA
        .byte   $05, $05, $0d, $0d, $0d, $0d, $0d, $0d
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $0d, $0d                  ;$7A0A
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $05, $05
        .byte   $05, $05, $05, $05, $00, $00, $00, $00                  ;$7A1A
        .byte   $00, $00, $00, $00, $05, $05, $05, $05
        .byte   $05, $05, $0d, $0d, $0d, $0d, $0d, $0d                  ;$7A2A
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $0d, $0d
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $05, $05                  ;$7A3A
        .byte   $05, $05, $05, $05, $00, $00, $00, $00
        .byte   $00, $00, $00, $00, $0f, $0f, $07, $07                  ;$7A4A
        .byte   $07, $07, $0d, $0d, $0d, $0d, $0d, $0d
        .byte   $0d, $03, $03, $03, $03, $03, $0d, $0d                  ;$7A5A
        .byte   $0d, $0d, $0d, $0d, $0d, $0d, $07, $07
        .byte   $07, $07, $05, $05, $00, $00, $00, $00                  ;$7A6A
        .byte   $8d, $18, $8f, $50, $46, $7e, $a4, $f4

;-------------------------------------------------------------------------------

.include        "elite_sprites.asm"

        ; some data that comes after the sprites, but isn't sprites.
        ; this block gets copied along with the sprites to $6800+
        ; -- purpose unknown
        
        .byte   $38, $35, $25, $67, $fa, $b5, $a5, $a2                  ;$7C3A
        .byte   $22, $c1, $df, $eb, $77, $ce, $f4, $07
        .byte   $37, $cf, $33, $4d, $a5, $89, $76, $cd                  ;$7C4A
        .byte   $6d, $69, $8d, $56, $cd, $94, $98, $f6
        .byte   $b8, $ce, $14, $13, $d1, $98, $ce, $b1                  ;$7C5A
        .byte   $77, $ce, $f4, $1c, $b1, $40, $68, $30
        .byte   $87, $cd, $a9, $90, $b2, $08, $c1, $db                  ;$7C6A
        .byte   $cf, $33, $49, $80, $6b, $ca, $3a, $cf

;-------------------------------------------------------------------------------

        .byte   $33, $8d, $49, $ea, $53, $29, $2c, $2f                  ;$7C7A
        .byte   $87, $c4, $a0, $70, $96, $90, $b3, $38
        .byte   $b9, $53, $9a, $91, $ae, $2e, $70, $f8                  ;$7C8A
        .byte   $c8, $1b, $7c, $a1, $d1, $37, $2b, $4c
        .byte   $97, $f3, $4f, $73, $ad, $d2, $39, $71                  ;$7C9A
        .byte   $4d, $ee, $f5, $d3, $4f, $e7, $c7, $f5
        .byte   $fe, $05, $d3, $4f, $68, $88, $35, $f9                  ;$7CAA
        .byte   $00, $d3, $4f, $27, $4a, $38, $f6, $fd
        .byte   $d6, $26, $cb, $1b, $bc, $ed, $0b, $33                  ;$7CBA
        .byte   $e9, $f0, $d3, $4f, $62, $85, $38, $f1
        .byte   $f8, $d3, $4f, $30, $56, $3b, $05, $0c                  ;$7CCA
        .byte   $d3, $4f, $68, $90, $98, $cb, $b7, $34
        .byte   $ed, $01, $08, $d3, $4f, $07, $2f, $3d                  ;$7CDA
        .byte   $d1, $d8, $d3, $4f, $62, $83, $36, $db
        .byte   $e2, $db, $2b, $07, $71, $1a, $93, $4f                  ;$7CEA
        .byte   $f8, $34, $d4, $33, $6f, $51, $ce, $d5
        .byte   $ea, $66, $8d, $af, $37, $04, $2b, $fe                  ;$7CFA
        .byte   $d7, $03, $2a, $f7, $d0, $06, $0d, $db
        .byte   $ad, $a5, $2f, $ce, $a4, $2e, $ce, $a3                  ;$7D0A
        .byte   $4d, $06, $60, $d2, $5b, $bc, $9d, $13
        .byte   $4f, $a8, $cd, $3a, $f7, $1e, $3e, $17                  ;$7D1A
        .byte   $f4, $fb, $dd, $b2, $4c, $97, $35, $ea
        .byte   $45, $c9, $e9, $b0, $2f, $8b, $12, $f7                  ;$7D2A
        .byte   $b6, $8b, $ab, $45, $c9, $e9, $b0, $06
        .byte   $bb, $0b, $36, $e2, $b7, $ab, $cf, $e3                  ;$7D3A
        .byte   $ea, $d9, $29, $a2, $f1, $8f, $b5, $d3
        .byte   $8a, $ce, $f1, $8f, $75, $c4, $14, $0b                  ;$7D4A
        .byte   $56, $0a, $e0, $2b, $35, $e6, $bc, $0c
        .byte   $30, $ea, $44, $96, $1b, $ae, $8a, $ea                  ;$7D5A
        .byte   $0b, $0c, $86, $44, $96, $38, $2c, $36
        .byte   $d3, $4f, $29, $50, $d3, $05, $45, $c9                  ;$7D6A
        .byte   $e9, $b0, $e9, $19, $b5, $0b, $fb, $b9
