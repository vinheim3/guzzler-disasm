.macro ldbc
    ld bc, (\1<<8)+\2
.endm

.define _C = $00
.define _Csharp = $01
.define _D = $02
.define _Dsharp = $03
.define _E = $04
.define _F = $05
.define _Fsharp = $06
.define _G = $07
.define _Gsharp = $08
.define _A = $09
.define _Asharp = $0a
.define _B = $0b

.macro LenVolNote
; \1 - len
; \2 - vol
; \3 - note
; \4 - octave
    .db (\1<<4)|\2
    .db ((\4-1)<<4)|\3
.endm