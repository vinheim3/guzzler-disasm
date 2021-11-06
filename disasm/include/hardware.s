.define _RAM $c000
.define SCREEN_COLS $20

.define PSG = $7f
.macro PSG_LATCH_DATA
; \1 - channel
; \2 - 1 if volume, 0 if tone/noise
; \3 - data
    .db $80|(\1<<5)|(\2<<4)|\3
.endm
.macro PSG_DATA
    .db \1
.endm
; channels
.define PSG_TONE_0 = 0
.define PSG_TONE_1 = 1
.define PSG_TONE_2 = 2
.define PSG_NOISE = 3
; vol/tone
.define PSG_IS_VOL = 1
.define PSG_IS_TONE = 0

.define VDP_DATA $be
.define VDP_CTRL $bf
.macro VDP_REG_WRITE
    .db \2
    .db $80|\1
.endm
.enum 0
    VDP_REG_CTRL_1 db
    VDP_REG_CTRL_2 db
    VDP_NAME_TBL_ADDR db
    VDP_COLOR_TBL_ADDR db
    VDP_PATT_GEN_TBL_ADDR db
    VDP_SPR_TBL_ADDR db
    VDP_SPR_PATT_GEN_TBL_ADDR db
    VDP_BACKDROP_COLOR db
.ende
.define VDP_CTRL_1_MODE_2 $02
.define VDP_CTRL_2_VRAM_16KB $80
.define VDP_CTRL_2_ENBL_DISPLAY $40
.define VDP_CTRL_2_ENBL_INTS $20
.define VDP_CTRL_2_OBJ16 $02
.define VDP_VRAM_WRITE $4000

.define IO_PORT_AB = $dc
.define INPUT_2 = $5 ; TR
.define INPUT_1 = $4 ; TL
.define INPUT_RIGHT = $3
.define INPUT_LEFT = $2
.define INPUT_DOWN = $1
.define INPUT_UP = $0
.define REMAPPED_2 = $5
.define REMAPPED_DOWN = $4
.define REMAPPED_LEFT = $3
.define REMAPPED_RIGHT = $2
.define REMAPPED_UP = $1
.define REMAPPED_1 = $0

.define IO_PORT_C = $de
.define PORT_C_JOYPADS = $07

.define PPI_CONTROL = $df


; https://www.smspower.org/Development/VDPRegisters
; https://www.smspower.org/uploads/Development/msvdp-20021112.txt
; https://www.smspower.org/Development/Palette
; https://www.smspower.org/forums/17648-SG1000PortDEWriteReadAtBootPattern
; https://www.smspower.org/Development/SN76489?from=Development.PSG
