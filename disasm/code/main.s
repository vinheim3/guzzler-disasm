.include "include/hardware.s"
.include "include/rominfo.s"
.include "include/constants.s"
.include "include/structs.s"
.include "include/macros.s"
        
.bank $000 slot 0
.org $0

Boot:
; Set interrupt mode to call during vblank
	di                                                              ; $0000
	im 1                                                            ; $0001

; Set SP, then jump
	ld sp, wStackTop                                                ; $0003
	jp Begin1                                                       ; $0006


Begin2:
; Set top score to 010000
	ld a, $01                                                       ; $0009
	ld (wTopScoreDigits+1), a                                       ; $000b

; Set sound to mute, then wait many cycles
	ld a, SND_MUTE                                                  ; $000e
	ld (wSoundToPlay), a                                            ; $0010
	call UpdateSound                                                ; $0013

	call WaitManyCycles                                             ; $0016

; Fill shadow name table with blank tiles
	ld hl, wNameTable                                               ; $0019
	ld de, wNameTable+1                                             ; $001c
	ld bc, _sizeof_wNameTable-1                                     ; $001f
	ld (hl), TILE_BLANK                                             ; $0022
	ldir                                                            ; $0024

; Init VDP
	ld hl, VDPRegisterData                                          ; $0026
	call SetVDPRegsLoadTileDataAndPalettes                          ; $0029

; Clear hardware bg+spr, and check for keyboard
	call ClearNameTableAndSprites                                   ; $002c
	call CheckForAttachedKeyboard                                   ; $002f

; Stay in an infinite loop
-	ei                                                              ; $0032
	jp -                                                            ; $0033


; $0036
	.db $ff, $00


VBlankInterrupt:
	di                                                              ; $0038
	push af                                                         ; $0039

; Reset VDP 2-byte sequence
	in a, (VDP_CTRL)                                                ; $003a

; Process game state only if unpaused
	ld a, (wPauseCounter)                                           ; $003c
	or a                                                            ; $003f
	jr z, @processGameState                                         ; $0040

; Else keep inc'ing counter so we resume after 256 vblanks
	inc a                                                           ; $0042
	ld (wPauseCounter), a                                           ; $0043

	pop af                                                          ; $0046
	ret                                                             ; $0047

@processGameState:
	call ProcessGameState                                           ; $0048

	pop af                                                          ; $004b
	ret                                                             ; $004c


; $004d
	.db $ff, $00, $ff, $df, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	.db $00, $ff, $00, $00, $ff, $00, $ff, $00, $ff


NmiVector:
	push af                                                         ; $0066

; Pausing doesn't do anything if GS_INIT game state, or title screen game state
	ld a, (wGameState)                                              ; $0067
	or a                                                            ; $006a
	jr z, @done                                                     ; $006b

	cp GS_TITLE_SCREEN                                              ; $006d
	jr z, @done                                                     ; $006f

; If in-game, and unpaused, start pause counter
	ld a, (wPauseCounter)                                           ; $0071
	or a                                                            ; $0074
	jr nz, +                                                        ; $0075

	inc a                                                           ; $0077
	ld (wPauseCounter), a                                           ; $0078

; If paused, unpause only once 16 vblanks have finished
+	cp $10                                                          ; $007b
	jr c, @done                                                     ; $007d

	xor a                                                           ; $007f
	ld (wPauseCounter), a                                           ; $0080

@done:
	pop af                                                          ; $0083
	retn                                                            ; $0084


Begin1:
; Clear wram, then jump
	ld hl, _RAM                                                     ; $0086
	ld de, _RAM+1                                                   ; $0089
	ld bc, $03ff                                                    ; $008c
	ld (hl), $00                                                    ; $008f
	ldir                                                            ; $0091

	jp Begin2                                                       ; $0093


WaitManyCycles:
	ld b, $03                                                       ; $0096

@loopB:
	ld hl, $ffff                                                    ; $0098

@loopHL:
	dec hl                                                          ; $009b
	ld a, l                                                         ; $009c
	or a                                                            ; $009d
	jr nz, @loopHL                                                  ; $009e

	cp h                                                            ; $00a0
	jr nz, @loopHL                                                  ; $00a1

	dec b                                                           ; $00a3
	ld a, b                                                         ; $00a4
	or a                                                            ; $00a5
	jr nz, @loopB                                                   ; $00a6

	ret                                                             ; $00a8


CheckForAttachedKeyboard:
; Set control to start checking for keyboard
	ld a, $01                                                       ; $00a9
	out (PPI_CONTROL), a                                            ; $00ab
	ld a, $92                                                       ; $00ad
	out (PPI_CONTROL), a                                            ; $00af

; Write $55 out to keyboard port
	ld a, $55                                                       ; $00b1
	out (IO_PORT_C), a                                              ; $00b3

; If we can read back $55 from it, the keyboard is attached
	in a, (IO_PORT_C)                                               ; $00b5
	cp $55                                                          ; $00b7
	ld a, $01                                                       ; $00b9
	jr z, +                                                         ; $00bb
	xor a                                                           ; $00bd
+	ld (wKeyboardAttached), a                                       ; $00be

; Enable reading from joypads first
	ld a, PORT_C_JOYPADS                                            ; $00c1
	out (IO_PORT_C), a                                              ; $00c3
	ret                                                             ; $00c5


ProcessGameState:
; If GS_INIT game state...
	ld a, (wGameState)                                              ; $00c6
	or a                                                            ; $00c9
	jr nz, @afterInitCheck                                          ; $00ca

; Go to title screen game state, and update top score layout
	ld a, GS_TITLE_SCREEN                                           ; $00cc
	ld (wGameState), a                                              ; $00ce

	ld hl, wTopScoreDigits                                          ; $00d1
	ld de, wTopScoreLayout                                          ; $00d4
	ld bc, _sizeof_wTopScoreDigits                                  ; $00d7
	ldir                                                            ; $00da

@afterInitCheck:
; Perform common vblank funcs, and update sound
	push bc                                                         ; $00dc
	push de                                                         ; $00dd
	call TickVBlank                                                 ; $00de
	call UpdateSound                                                ; $00e1
	pop de                                                          ; $00e4
	pop bc                                                          ; $00e5

; If title screen game state...
	ld a, (wGameState)                                              ; $00e6
	cp GS_TITLE_SCREEN                                              ; $00e9
	jr nz, @inGame                                                  ; $00eb

; Handle its main loop, then once it changes to in-game, update name table + sprites
	call HandleTitleScreen                                          ; $00ed
	call UpdateNameTable                                            ; $00f0
	call UpdateSprites                                              ; $00f3
	ret                                                             ; $00f6

@inGame:
; Split main loop responsibilities every other loop
	ld a, (wVBlankInterruptCounter)                                 ; $00f7
	bit 0, a                                                        ; $00fa
	jr nz, @updateFiresAndNametable                                 ; $00fc

; Update non-dangerous elements, and sprites
	call HandleTimer1Func_PlayerAndCollisions                       ; $00fe
	call HandleTimer2Func_SpecialItem                               ; $0101
	call UpdateSprites                                              ; $0104
	jr @end                                                         ; $0107

@updateFiresAndNametable:
	call UpdateFireEnemies                                          ; $0109
	call AnimateFireHeads                                           ; $010c
	call UpdateNameTable                                            ; $010f

@end:
	call HandleTimer6Func_DeathOrClear                              ; $0112
	ret                                                             ; $0115


VDPRegisterData:
	VDP_REG_WRITE VDP_REG_CTRL_1, VDP_CTRL_1_MODE_2
	VDP_REG_WRITE VDP_REG_CTRL_2, VDP_CTRL_2_VRAM_16KB|VDP_CTRL_2_ENBL_DISPLAY|VDP_CTRL_2_ENBL_INTS|VDP_CTRL_2_OBJ16
	VDP_REG_WRITE VDP_NAME_TBL_ADDR, NAME_TABLE_ADDR>>10
	VDP_REG_WRITE VDP_COLOR_TBL_ADDR, $ff ; all bits 1 for normal operation
	VDP_REG_WRITE VDP_PATT_GEN_TBL_ADDR, $03 ; ???
	VDP_REG_WRITE VDP_SPR_TBL_ADDR, SPRITE_TABLE_ADDR>>7
	VDP_REG_WRITE VDP_SPR_PATT_GEN_TBL_ADDR, $03 ; low 2 bits (mask) 1 for normal operation
	VDP_REG_WRITE VDP_BACKDROP_COLOR, $f0 ; low 4 bits is colour (black)


; HL - points to $10 bytes of VDP register data
SetVDPRegsLoadTileDataAndPalettes:
; Set first 8 internal VDP regs
	ld b, 8*2                                                       ; $0126
	ld c, VDP_CTRL                                                  ; $0128
	otir                                                            ; $012a

; Copy BG to vram at $0000, $0800 and $1000
	ld hl, Gfx_BG                                                   ; $012c
	ld de, VDP_VRAM_WRITE|0                                         ; $012f
	ld bc, $0800                                                    ; $0132
	call SetVDPCtrlAndMemCopyVDP                                    ; $0135

	ld hl, Gfx_BG                                                   ; $0138
	ld bc, $0800                                                    ; $013b
	call MemCopyVDP                                                 ; $013e

	ld hl, Gfx_BG                                                   ; $0141
	ld bc, $0800                                                    ; $0144
	call MemCopyVDP                                                 ; $0147

; Set BG palettes for the above 3 regions
	ld de, VDP_VRAM_WRITE|$2000                                     ; $014a
	call CopyBGPalettes                                             ; $014d

	ld de, VDP_VRAM_WRITE|$2800                                     ; $0150
	call CopyBGPalettes                                             ; $0153

	ld de, VDP_VRAM_WRITE|$3000                                     ; $0156
	call CopyBGPalettes                                             ; $0159

; Copy SPR to vram at $1800
	ld hl, Gfx_Spr                                                  ; $015c
	ld de, VDP_VRAM_WRITE|$1800                                     ; $015f
	ld bc, $0400                                                    ; $0162
	call SetVDPCtrlAndMemCopyVDP                                    ; $0165
	ret                                                             ; $0168


ClearNameTableAndSprites:
; Start writing to name table
	ld a, <(VDP_VRAM_WRITE|NAME_TABLE_ADDR)                         ; $0169
	out (VDP_CTRL), a                                               ; $016b
	ld a, >(VDP_VRAM_WRITE|NAME_TABLE_ADDR)                         ; $016d
	out (VDP_CTRL), a                                               ; $016f

; Fill name table with tile $4b
	ld a, TILE_BLANK                                                ; $0171
	ld bc, $0300                                                    ; $0173
	call MemSetVDP                                                  ; $0176

ClearSprites:
; Start writing to sprite table
	ld a, <(VDP_VRAM_WRITE|SPRITE_TABLE_ADDR)                       ; $0179
	out (VDP_CTRL), a                                               ; $017b
	ld a, >(VDP_VRAM_WRITE|SPRITE_TABLE_ADDR)                       ; $017d
	out (VDP_CTRL), a                                               ; $017f

; Clear out $20-byte sprite table
	xor a                                                           ; $0181
	ld bc, $80                                                      ; $0182
	call MemSetVDP                                                  ; $0185
	ret                                                             ; $0188


; BC - num bytes
; DE - VDP Control
; HL - src addr
SetVDPCtrlAndMemCopyVDP:
	ld a, e                                                         ; $0189
	out (VDP_CTRL), a                                               ; $018a
	ld a, d                                                         ; $018c
	out (VDP_CTRL), a                                               ; $018d

; BC - num bytes
; HL - src addr
MemCopyVDP:
-	ld a, (hl)                                                      ; $018f
	out (VDP_DATA), a                                               ; $0190
	inc hl                                                          ; $0192

	dec bc                                                          ; $0193
	ld a, b                                                         ; $0194
	or c                                                            ; $0195
	jr nz, -                                                        ; $0196

	ret                                                             ; $0198


; A - byte to set
; BC - num bytes
MemSetVDP:
	ld d, a                                                         ; $0199
-	ld a, d                                                         ; $019a
	out (VDP_DATA), a                                               ; $019b

	dec bc                                                          ; $019d
	ld a, b                                                         ; $019e
	or c                                                            ; $019f
	jr nz, -                                                        ; $01a0

	ret                                                             ; $01a2


; DE - VDP Control
CopyBGPalettes:
	ld a, e                                                         ; $01a3
	out (VDP_CTRL), a                                               ; $01a4
	ld a, d                                                         ; $01a6
	out (VDP_CTRL), a                                               ; $01a7

; Copy in palettes for different tile data regions
	ld a, (Palette_Ascii)                                           ; $01a9
	ld bc, $d8                                                      ; $01ac
	call MemSetVDP                                                  ; $01af

	ld a, (Palette_Water)                                           ; $01b2
	ld bc, $0140                                                    ; $01b5
	call MemSetVDP                                                  ; $01b8

	ld a, (Palette_Fire)                                            ; $01bb
	ld bc, $40                                                      ; $01be
	call MemSetVDP                                                  ; $01c1

	ld hl, Palette_Misc                                             ; $01c4
	ld bc, Palette_Misc@end-Palette_Misc                            ; $01c7
	call MemCopyVDP                                                 ; $01ca
	ret                                                             ; $01cd


UpdateNameTable:
	ld hl, wNameTable                                               ; $01ce
	ld de, VDP_VRAM_WRITE|NAME_TABLE_ADDR                           ; $01d1
	ld bc, _sizeof_wNameTable                                       ; $01d4
	call SetVDPCtrlAndMemCopyVDP                                    ; $01d7
	ret                                                             ; $01da


UpdateSprites:
	ld hl, wSprites                                                 ; $01db
	ld de, VDP_VRAM_WRITE|SPRITE_TABLE_ADDR                         ; $01de
	ld bc, _sizeof_wSprites                                         ; $01e1
	call SetVDPCtrlAndMemCopyVDP                                    ; $01e4
	ret                                                             ; $01e7


; Inc frame counter, dec timers, and dec score if enough time passed
TickVBlank:
; Inc frame counter
	ld a, (wVBlankInterruptCounter)                                 ; $01e8
	inc a                                                           ; $01eb
	ld (wVBlankInterruptCounter), a                                 ; $01ec

; B = num timers
	ld hl, wGenericTimers                                           ; $01ef
	ld a, (@numTimers)                                              ; $01f2
	ld b, a                                                         ; $01f5

@nextTimer:
; For every generic timer, if >0, dec it
	ld a, (hl)                                                      ; $01f6
	or a                                                            ; $01f7
	jr z, +                                                         ; $01f8
	dec (hl)                                                        ; $01fa
+	inc hl                                                          ; $01fb

	dec b                                                           ; $01fc
	jr nz, @nextTimer                                               ; $01fd

; Return if not in-game
	ld a, (wGameState)                                              ; $01ff
	cp GS_IN_GAME                                                   ; $0202
	ret nz                                                          ; $0204

; Return if the game is at a stand-still
	ld a, (wInGameStandstillReason)                                 ; $0205
	or a                                                            ; $0208
	ret nz                                                          ; $0209

; Jump if deduction timer is already ticking down
	ld a, (wBonusScoreDeductionTimer)                               ; $020a
	or a                                                            ; $020d
	jr nz, @tickDeductionTimer                                      ; $020e

; Else set timer based on if round is >= 9/6, or not
	ld a, (wRound)                                                  ; $0210
	ld b, $27                                                       ; $0213
	cp $09                                                          ; $0215
	jr nc, @setPtDeductionTimer                                     ; $0217

	ld b, $3b                                                       ; $0219
	cp $06                                                          ; $021b
	jr nc, @setPtDeductionTimer                                     ; $021d

	ld b, $59                                                       ; $021f

@setPtDeductionTimer:
	ld a, b                                                         ; $0221
	ld (wBonusScoreDeductionTimer), a                               ; $0222
	ret                                                             ; $0225

@tickDeductionTimer:
; Dec timer, returning if not yet 0
	dec a                                                           ; $0226
	ld (wBonusScoreDeductionTimer), a                               ; $0227
	ret nz                                                          ; $022a

; If round >= 9, deduct 400 pts
	ld a, (wRound)                                                  ; $022b
	ld b, $04                                                       ; $022e
	cp $09                                                          ; $0230
	jr nc, @afterGettingPtDeduction                                 ; $0232

; If round >= 6, deduct 300 pts
	ld b, $03                                                       ; $0234
	cp $06                                                          ; $0236
	jr nc, @afterGettingPtDeduction                                 ; $0238

; If round >= 3, deduct 200 pts
	ld b, $02                                                       ; $023a
	cp $03                                                          ; $023c
	jr nc, @afterGettingPtDeduction                                 ; $023e

; Else deduct 100 pts
	ld b, $01                                                       ; $0240

@afterGettingPtDeduction:
	call SubtractBHundredsFromBonusScore                            ; $0242

; Update layout, returning if not 0
	push af                                                         ; $0245
	call UpdateCurrScoreDigitsLayout                                ; $0246
	pop af                                                          ; $0249

	or a                                                            ; $024a
	ret z                                                           ; $024b

; Set that everything's stopped due to time out
	ld a, $03                                                       ; $024c
	ld (wInGameStandstillReason), a                                 ; $024e
	ret                                                             ; $0251

@numTimers:
	.db _sizeof_wGenericTimers


HandleTitleScreen:
; Load static part of title screen, and score part of title screen
	call LoadTitleScreenTitleAndCopyright                           ; $0253
	call UpdateShadowScoreRelatedLayout                             ; $0256

; Prefix scores with blank tiles, then update their shadow layout
	ld ix, wTopScoreLayout                                          ; $0259
	call PrefixScoreWithBlankTiles                                  ; $025d
	ld ix, wCurrScoreLayout                                         ; $0260
	call PrefixScoreWithBlankTiles                                  ; $0264

	call UpdateShadowScoreValueLayout                               ; $0267

; Clear sprites, load levels text, then update hw nametable 
	call ClearSprites                                               ; $026a

	call Load2LevelsOptText                                         ; $026d
	call UpdateNameTable                                            ; $0270

; Mute sound on this screen
	ld a, SND_MUTE                                                  ; $0273
	ld (wSoundToPlay), a                                            ; $0275
	call UpdateSound                                                ; $0278

@pollInputLoop:
; Poll input, until btn 1 or 2 held
	call PollInput                                                  ; $027b

	ld a, (wRemappedBtnsHeld)                                       ; $027e
	bit REMAPPED_1, a                                               ; $0281
	jr nz, @actionBtnHeld                                           ; $0283

	bit REMAPPED_2, a                                               ; $0285
	jr z, @pollInputLoop                                            ; $0287

@actionBtnHeld:
; Set optioin selected, then go to in-game state
	ld (wButtonsHeldOnTitleScreen), a                               ; $0289

	ld a, GS_IN_GAME                                                ; $028c
	ld (wGameState), a                                              ; $028e

; Load round 1's layout and update nametable
	call LoadRound1Layout                                           ; $0291
	call UpdateNameTable                                            ; $0294

; Clear that buttons were held, for next state
	xor a                                                           ; $0297
	ld (wRemappedBtnsHeld), a                                       ; $0298

; Wait many cycles pt.1
	ld hl, $ffff                                                    ; $029b
-	dec hl                                                          ; $029e
	ld a, h                                                         ; $029f
	or a                                                            ; $02a0
	jr nz, -                                                        ; $02a1
	cp l                                                            ; $02a3
	jr nz, -                                                        ; $02a4

; Wait many cycles pt.2
	ld hl, $3fff                                                    ; $02a6
-	dec hl                                                          ; $02a9
	ld a, h                                                         ; $02aa
	or a                                                            ; $02ab
	jr nz, -                                                        ; $02ac
	cp l                                                            ; $02ae
	jr nz, -                                                        ; $02af

	ret                                                             ; $02b1


HandleTimer1Func_PlayerAndCollisions:
; Return if at a stand-still due to a negative reason
	ld a, (wInGameStandstillReason)                                 ; $02b2
	cp $02                                                          ; $02b5
	ret nc                                                          ; $02b7

; If hit by enemy, now we process the player being killed
	ld a, (wPlayerHitByEnemy)                                       ; $02b8
	or a                                                            ; $02bb
	jp nz, @processPlayerKilled                                     ; $02bc

; Return if timer not yet 0
	ld a, (wGenericTimers+1)                                        ; $02bf
	or a                                                            ; $02c2
	ret nz                                                          ; $02c3

; If jump func set, use it, otherwise carry on with generic player checks
	ld hl, (wTimer1JumpAddr)                                        ; $02c4
	ld a, h                                                         ; $02c7
	or l                                                            ; $02c8
	jr z, @noJumpFunc                                               ; $02c9

	ld bc, $00                                                      ; $02cb
	ld (wTimer1JumpAddr), bc                                        ; $02ce
	jp (hl)                                                         ; $02d2

@noJumpFunc:
	call PollInput                                                  ; $02d3

; B = buttons held
	ld ix, wRemappedBtnsHeld                                        ; $02d6
	ld a, (ix+$00)                                                  ; $02da
	ld b, a                                                         ; $02dd

; Jump if no directions held
	and $1e                                                         ; $02de
	jr z, @notOverridingDirsOrHitWall                               ; $02e0

; Else C = that direction, try to move player, jumping if hit a wall
	ld c, a                                                         ; $02e2
	call ProcessPlayerDirInput                                      ; $02e3
	cp COLL_WALL                                                    ; $02e6
	jr z, @notOverridingDirsOrHitWall                               ; $02e8

; Set wPlayerLastInputDirection
	ld (ix+$01), c                                                  ; $02ea
	jr @afterPlayerDirChosen                                        ; $02ed

@notOverridingDirsOrHitWall:
; B = current direction
	ld b, (ix+$01)                                                  ; $02ef

; Or action buttons held, with last inputted direction, to set curr direction
	ld a, (ix+$00)                                                  ; $02f2
	and $21                                                         ; $02f5
	or b                                                            ; $02f7
	ld (ix+$00), a                                                  ; $02f8

; Try to move in that direction
	ld b, a                                                         ; $02fb
	ld c, a                                                         ; $02fc
	call ProcessPlayerDirInput                                      ; $02fd

@afterPlayerDirChosen:
; Jump if a collision occurred
	or a                                                            ; $0300
	jr nz, @checkCollision                                          ; $0301

; Else player can walk, so play sound and move player
	ld a, SND_PLAYER_WALKING                                        ; $0303
	ld (wSoundToPlay), a                                            ; $0305
	call MoveObject                                                 ; $0308

; Jump if we now collided with an enemy
	call CheckEnemyCollisionAgainstObjectCoords                     ; $030b
	or a                                                            ; $030e
	jr nz, @processPlayerKilled                                     ; $030f

; Jump if water level is not empty
	ld a, (wPlayerWaterLevel)                                       ; $0311
	or a                                                            ; $0314
	jp nz, @clearPanicTimer                                         ; $0315

; Inc timer, jumping if it hasn't reached $5a yet
	ld a, (wWaterPanicTimer)                                        ; $0318
	inc a                                                           ; $031b
	ld (wWaterPanicTimer), a                                        ; $031c

	cp $5a                                                          ; $031f
	jp c, CheckIfPlayerFiringWater                                  ; $0321

; Once timer hits $5a, give player some water, then clear panic timer
	ld a, $01                                                       ; $0324
	ld (wPlayerWaterLevel), a                                       ; $0326
	call SetPlayerWaterLevelTileIdx                                 ; $0329

@clearPanicTimer:
	xor a                                                           ; $032c
	ld (wWaterPanicTimer), a                                        ; $032d
	jp CheckIfPlayerFiringWater                                     ; $0330

@checkCollision:
; Jump to handler for collision. If hit fire, continue down
	cp COLL_WALL                                                    ; $0333
	ret z                                                           ; $0335

	cp COLL_CENTER                                                  ; $0336
	jp z, HandlePlayerCollectingSpecialWater                        ; $0338

	cp COLL_BIG_PUDDLE                                              ; $033b
	jp z, HandlePlayerCollectingBigPuddle                           ; $033d

	cp COLL_SMALL_PUDDLE                                            ; $0340
	jp z, HandlePlayerCollectingSmallPuddle                         ; $0342

@processPlayerKilled:
; Halt everything, and clear enemy hit flag
	ld a, $01                                                       ; $0345
	ld (wInGameStandstillReason), a                                 ; $0347

	xor a                                                           ; $034a
	ld (wPlayerHitByEnemy), a                                       ; $034b

; After half a second, handle that player was killed
	ld a, $1e                                                       ; $034e
	ld (wGenericTimers+1), a                                        ; $0350

	ld hl, HandlePlayerKilled                                       ; $0353
	ld (wTimer1JumpAddr), hl                                        ; $0356
	ret                                                             ; $0359


HandlePlayerKilled:
; Clear fire enemies' sprites
	ld hl, wSprites+8                                               ; $035a
	ld de, wSprites+9                                               ; $035d
	ld bc, 3*4-1                                                    ; $0360
	ld (hl), $00                                                    ; $0363
	ldir                                                            ; $0365

; Adjust HL to point to layout elements based on curr layout
	ld a, (wInGameLayout)                                           ; $0367
	ld ix, Metatile_Empty                                           ; $036a
	ld hl, Layout1Elements                                          ; $036e
	ld de, Layout2Elements-Layout1Elements                          ; $0371

	dec a                                                           ; $0374
	jr z, @afterLayoutAddr                                          ; $0375

	add hl, de                                                      ; $0377
	dec a                                                           ; $0378
	jr z, @afterLayoutAddr                                          ; $0379

	add hl, de                                                      ; $037b

@afterLayoutAddr:
; Clear all 9 elements
	ld b, $09                                                       ; $037c

@nextElement:
; DE/IY = nametable addr of element
	ld e, (hl)                                                      ; $037e
	inc hl                                                          ; $037f
	ld d, (hl)                                                      ; $0380
	inc hl                                                          ; $0381

	push de                                                         ; $0382
	pop iy                                                          ; $0383

; If first 3 elements (fires), clear the fire heads too
	ld a, b                                                         ; $0385
	cp $07                                                          ; $0386
	jr c, +                                                         ; $0388

	ld (iy-$20), TILE_BLANK                                         ; $038a
	ld (iy-$1f), TILE_BLANK                                         ; $038e

; Set empty metatile, then do next element
+	call LoadMetatile                                               ; $0392
	dec b                                                           ; $0395
	jr nz, @nextElement                                             ; $0396

; Play death sound, then change player sprite, hiding water sprite
	ld a, SND_DIED_BY_FIRE                                          ; $0398
	ld (wSoundToPlay), a                                            ; $039a

	ld a, $4c                                                       ; $039d
	ld (wSprites+6), a                                              ; $039f
	ld a, $25                                                       ; $03a2
	ld (wSprites+2), a                                              ; $03a4

; After 1 second, call below func
	ld a, $3c                                                       ; $03a7
	ld (wGenericTimers+1), a                                        ; $03a9

	ld hl, JumpFunc_PlayerBeingKilled                               ; $03ac
	ld (wTimer1JumpAddr), hl                                        ; $03af
	ret                                                             ; $03b2


JumpFunc_PlayerBeingKilled:
; Change player sprite again, then call below func after 1 second again
	ld a, $28                                                       ; $03b3
	ld (wSprites+2), a                                              ; $03b5

	ld a, $3c                                                       ; $03b8
	ld (wGenericTimers+1), a                                        ; $03ba

	ld hl, JumpFunc_PlayerKilled                                    ; $03bd
	ld (wTimer1JumpAddr), hl                                        ; $03c0
	ret                                                             ; $03c3


JumpFunc_PlayerKilled:
; Set that we should freeze due to player being dead
	ld a, $02                                                       ; $03c4
	ld (wInGameStandstillReason), a                                 ; $03c6
	ret                                                             ; $03c9


HandlePlayerCollectingSpecialWater:
; Play sound, then clear that the item was loaded
	ld a, SND_GOT_SPECIAL_WATER                                     ; $03ca
	ld (wSoundToPlay), a                                            ; $03cc

	xor a                                                           ; $03cf
	ld (wCenterItemLoaded), a                                       ; $03d0

; Halt everything due to item collection
	ld a, $01                                                       ; $03d3
	ld (wInGameStandstillReason), a                                 ; $03d5

; +5k to score if round >= 9
	ld a, (wRound)                                                  ; $03d8
	ld c, $05                                                       ; $03db
	cp $09                                                          ; $03dd
	jr nc, @afterScoreIncrease                                      ; $03df

; +3k to score if round >= 6
	ld c, $03                                                       ; $03e1
	cp $06                                                          ; $03e3
	jr nc, @afterScoreIncrease                                      ; $03e5

; +2k to score if round >= 3
	ld c, $02                                                       ; $03e7
	cp $03                                                          ; $03e9
	jr nc, @afterScoreIncrease                                      ; $03eb

; Else +1k to score
	ld c, $01                                                       ; $03ed

@afterScoreIncrease:
; Add score, and handle post-score-increase funcs
	ld b, $00                                                       ; $03ef
	ld d, $00                                                       ; $03f1
	call AddB100sC1ksD10ksToCurrScore                               ; $03f3
	call CheckIfNewTopScore                                         ; $03f6
	call IncLivesIfApplicable                                       ; $03f9
	call UpdateShadowScoreValueLayout                               ; $03fc

; Empty out the tile at the screen center
	ld ix, Metatile_Empty                                           ; $03ff
	ld iy, wNameTable+$16b                                          ; $0403
	call LoadMetatile                                               ; $0407

; Fill player's water level, and update the player body water level tile
	ld a, $03                                                       ; $040a
	ld (wPlayerWaterLevel), a                                       ; $040c
	call SetPlayerWaterLevelTileIdx                                 ; $040f

; After a third of a second, have everything unfrozen
	ld a, $14                                                       ; $0412
	ld (wGenericTimers+1), a                                        ; $0414

	ld hl, JumpFunc_AfterSpecialWater                               ; $0417
	ld (wTimer1JumpAddr), hl                                        ; $041a
	ret                                                             ; $041d


JumpFunc_AfterSpecialWater:
; Allow everything to move again
	xor a                                                           ; $041e
	ld (wInGameStandstillReason), a                                 ; $041f
	ret                                                             ; $0422


; IY - nametable addr of puddle
HandlePlayerCollectingBigPuddle:
; Play sound
	ld a, SND_PUDDLE_COLLECTED                                      ; $0423
	ld (wSoundToPlay), a                                            ; $0425

; Freeze everything, then save the puddle's address
	ld a, $01                                                       ; $0428
	ld (wInGameStandstillReason), a                                 ; $042a
	ld (wPreservedPuddleAddr), iy                                   ; $042d

; After have a second, process that the big puddle was collected
	ld a, $1e                                                       ; $0431
	ld (wGenericTimers+1), a                                        ; $0433

	ld hl, JumpFunc_PlayerCollectedFromBigPuddle                    ; $0436
	ld (wTimer1JumpAddr), hl                                        ; $0439
	ret                                                             ; $043c


JumpFunc_PlayerCollectedFromBigPuddle:
; Check collision again with preserved puddle addr
	ld iy, (wPreservedPuddleAddr)                                   ; $043d
	call CheckCollisionWithBigPuddle                                ; $0441

; Change big puddle into a smaller one, then max out player's water level
	ld ix, Metatile_SmallPuddle                                     ; $0444
	call LoadMetatile                                               ; $0448

	ld a, $03                                                       ; $044b
	ld (wPlayerWaterLevel), a                                       ; $044d

; IY - nametable addr of puddle
HandlePlayerCollectingSmallPuddle:
; Play sound
	ld a, SND_PUDDLE_COLLECTED                                      ; $0450
	ld (wSoundToPlay), a                                            ; $0452

; Freeze everything, then save the puddle's address
	ld a, $01                                                       ; $0455
	ld (wInGameStandstillReason), a                                 ; $0457
	ld (wPreservedPuddleAddr), iy                                   ; $045a

; After have a second, process that the small puddle was collected
	ld a, $1e                                                       ; $045e
	ld (wGenericTimers+1), a                                        ; $0460

	ld hl, JumpFunc_SmallPuddleBeingCollected                       ; $0463
	ld (wTimer1JumpAddr), hl                                        ; $0466
	ret                                                             ; $0469


JumpFunc_SmallPuddleBeingCollected:
; Check collision again with preserved puddle addr
	ld iy, (wPreservedPuddleAddr)                                   ; $046a
	call CheckCollisionWithSmallPuddle                              ; $046e

; Load empty metatile in its place
	ld ix, Metatile_Empty                                           ; $0471
	call LoadMetatile                                               ; $0475

; Inc water level if not full
	ld a, (wPlayerWaterLevel)                                       ; $0478
	cp $03                                                          ; $047b
	jr z, +                                                         ; $047d

	inc a                                                           ; $047f
	ld (wPlayerWaterLevel), a                                       ; $0480

; Update player's body water tile idx
+	call SetPlayerWaterLevelTileIdx                                 ; $0483

; Call below func after 1/3 of a second
	ld a, $14                                                       ; $0486
	ld (wGenericTimers+1), a                                        ; $0488

	ld hl, JumpFunc_SmallPuddleCollected                            ; $048b
	ld (wTimer1JumpAddr), hl                                        ; $048e
	ret                                                             ; $0491


JumpFunc_SmallPuddleCollected:
; Allow things to move again
	xor a                                                           ; $0492
	ld (wInGameStandstillReason), a                                 ; $0493
	ret                                                             ; $0496


CheckIfPlayerFiringWater:
; Return if player's water level is empty
	ld a, (wPlayerWaterLevel)                                       ; $0497
	or a                                                            ; $049a
	ret z                                                           ; $049b

	ld iy, wRemappedBtnsHeld                                        ; $049c
	ld hl, wPrevBtnsHeld                                            ; $04a0

; If 1 or 2 pressed, proceed with firing water
	ld a, (iy+$00)                                                  ; $04a3
	bit REMAPPED_1, a                                               ; $04a6
	jr nz, @fireWater                                               ; $04a8

	bit REMAPPED_2, a                                               ; $04aa
	ret z                                                           ; $04ac

@fireWater:
; If 1 was held, reset that it was held
	ld a, (hl)                                                      ; $04ad
	bit REMAPPED_1, a                                               ; $04ae
	jr z, @createWaterShot                                          ; $04b0

	res REMAPPED_1, a                                               ; $04b2
	ld (hl), a                                                      ; $04b4
	ret                                                             ; $04b5

@createWaterShot:
; Else we pressed 1, B = prev btns held + 1
	set REMAPPED_1, a                                               ; $04b6
	ld (hl), a                                                      ; $04b8
	ld (iy+$00), a                                                  ; $04b9
	ld b, a                                                         ; $04bc

; C = the directions we previously held
	and $1e                                                         ; $04bd
	ld c, a                                                         ; $04bf

; Branch based on which direction we're facing while shooting
	ld d, TILE_WATER_SHOT_RIGHT                                     ; $04c0
	bit REMAPPED_RIGHT, a                                           ; $04c2
	jr nz, @setWaterShotTileIdx                                     ; $04c4

	ld d, TILE_WATER_SHOT_LEFT                                      ; $04c6
	bit REMAPPED_LEFT, a                                            ; $04c8
	jr nz, @setWaterShotTileIdx                                     ; $04ca

	ld d, TILE_WATER_SHOT_UP                                        ; $04cc
	bit REMAPPED_UP, a                                              ; $04ce
	jr nz, @setWaterShotTileIdx                                     ; $04d0

	ld d, TILE_WATER_SHOT_DOWN                                      ; $04d2

@setWaterShotTileIdx:
	ld a, d                                                         ; $04d4
	ld (wSprites+6), a                                              ; $04d5

; Preserve player's coords, and set that we are at a stand-still
	ld hl, (wSprites)                                               ; $04d8
	ld (wPreservedPlayerCoordsDuringWaterShot), hl                  ; $04db

	ld a, $01                                                       ; $04de
	ld (wInGameStandstillReason), a                                 ; $04e0

; The more water the player is, the farther it will shoot
	ld d, $0c                                                       ; $04e3
	ld a, (wPlayerWaterLevel)                                       ; $04e5
	dec a                                                           ; $04e8
	jr z, @setLifeTimer                                             ; $04e9

	ld d, $10                                                       ; $04eb
	dec a                                                           ; $04ed
	jr z, @setLifeTimer                                             ; $04ee

	ld d, $14                                                       ; $04f0

@setLifeTimer:
	ld a, d                                                         ; $04f2
	ld (wWaterShotLifeTimer), a                                     ; $04f3

; B = prev btns held, C = dirs we prev held, for player
	ld (wPreservedPlayerBtnsHeldAndDir), bc                         ; $04f6

; Clear vars that tally up what's extinguished
	ld bc, $00                                                      ; $04fa
	ld (wWaterExtinguishedStaticFire), bc                           ; $04fd
	ld (wWaterExtinguishedFireEnemy1), bc                           ; $0501
	ld (wDestAddrOfDestroyedStaticFire), bc                         ; $0505
	ld (wDestAddrOfDestroyedFireEnemies), bc                        ; $0509
	ld (wDestAddrOfDestroyedFireEnemies+2), bc                      ; $050d
	ld (wDestAddrOfDestroyedFireEnemies+4), bc                      ; $0511
	ld (wDestroyedFireEnemyX), bc                                   ; $0515

; Fiinally play shot sound
	ld a, SND_WATER_FIRED                                           ; $0519
	ld (wSoundToPlay), a                                            ; $051b

WaterShotMainLoop:
; If timer at 0, kill the water shot
	ld a, (wWaterShotLifeTimer)                                     ; $051e
	dec a                                                           ; $0521
	ld (wWaterShotLifeTimer), a                                     ; $0522
	jr z, KillWaterShot                                             ; $0525

; BC = prev btns held, and dirs prev held, for player
	ld bc, (wPreservedPlayerBtnsHeldAndDir)                         ; $0527

; Copy water shot to player sprite, and have it move, jumping if it collided with the layout
	ld hl, (wSprites+4)                                             ; $052b
	ld (wSprites), hl                                               ; $052e
	call ProcessPlayerDirInput                                      ; $0531
	or a                                                            ; $0534
	jr nz, WaterShotCollidedWithLayout                              ; $0535

; Jump if water hit fire
	call CheckEnemyCollisionAgainstObjectCoords                     ; $0537
	or a                                                            ; $053a
	jp nz, ProcessWaterHitFireEnemy                                 ; $053b

MoveWaterShot:
; Move object based on player's status at time of shooting
	ld bc, (wPreservedPlayerBtnsHeldAndDir)                         ; $053e
	call MoveObject                                                 ; $0542

; Restore player coords
	ld hl, (wPreservedPlayerCoordsDuringWaterShot)                  ; $0545
	ld (wSprites), hl                                               ; $0548

; Call the above main loop for the water shot, next frame
	ld a, $01                                                       ; $054b
	ld (wGenericTimers+1), a                                        ; $054d

	ld hl, WaterShotMainLoop                                        ; $0550
	ld (wTimer1JumpAddr), hl                                        ; $0553
	ret                                                             ; $0556


; A - object water shot collided with
WaterShotCollidedWithLayout:
; Branch based on what the shot collided with
	cp COLL_WALL                                                    ; $0557
	jr z, KillWaterShot                                             ; $0559

	cp COLL_FIRE_MAIN                                               ; $055b
	jp z, WaterShotCollidedWithFireMain                             ; $055d

	jr MoveWaterShot                                                ; $0560

KillWaterShot:
; -1 to current water level, and update player water body tile idx
	ld a, (wPlayerWaterLevel)                                       ; $0562
	dec a                                                           ; $0565
	ld (wPlayerWaterLevel), a                                       ; $0566

	call SetPlayerWaterLevelTileIdx                                 ; $0569

; Restore player's coords
	ld hl, (wPreservedPlayerCoordsDuringWaterShot)                  ; $056c
	ld (wSprites), hl                                               ; $056f
	ld (wSprites+4), hl                                             ; $0572

; Wait a bit, then have the func below called
	ld a, $03                                                       ; $0575
	ld (wGenericTimers+1), a                                        ; $0577

	ld hl, JumpFunc_WaterShotHitWall                                ; $057a
	ld (wTimer1JumpAddr), hl                                        ; $057d
	ret                                                             ; $0580


JumpFunc_WaterShotHitWall:
	ld ix, Metatile_Empty                                           ; $0581

; Loop through fires we may have destroyed
	ld hl, wDestAddressesOfDestroyedFires                           ; $0585
	ld d, $00                                                       ; $0588
	ld e, $04                                                       ; $058a

@nextFireType:
; BC points to the nametable addr of the current fire type
	ld c, (hl)                                                      ; $058c
	inc hl                                                          ; $058d
	ld b, (hl)                                                      ; $058e

; If 0, go to next addr
	ld a, b                                                         ; $058f
	or c                                                            ; $0590
	jr z, @toNextFireType                                           ; $0591

; IY = nametable addr, load empty metatile that addr, set associated bit in D
	push bc                                                         ; $0593
	pop iy                                                          ; $0594
	call LoadMetatile                                               ; $0596

	set 0, d                                                        ; $0599

@toNextFireType:
; Shift in bits for fires we've destroyed
	sla d                                                           ; $059b
	inc hl                                                          ; $059d
	dec e                                                           ; $059e
	jr nz, @nextFireType                                            ; $059f

; Jump if highest bit (static fire) was set
	ld a, d                                                         ; $05a1
	ld hl, ScoresForDestroyingFires                                 ; $05a2
	bit 4, a                                                        ; $05a5
	jr nz, @hitStaticFire                                           ; $05a7

; Otherwise if D has no bits set, don't increase score
	or a                                                            ; $05a9
	jr z, @afterScoreIncrease                                       ; $05aa

	jr @chooseBytePairForScoreSection                               ; $05ac

@hitStaticFire:
; Go to 2nd score section
	ld bc, $08                                                      ; $05ae
	add hl, bc                                                      ; $05b1

; Use the section if down held (riskier shot)
	ld bc, (wPreservedPlayerBtnsHeldAndDir)                         ; $05b2
	bit REMAPPED_DOWN, c                                            ; $05b6
	jr nz, @chooseBytePairForScoreSection                           ; $05b8

; Else use the 3rd/last score section
	ld bc, $08                                                      ; $05ba
	add hl, bc                                                      ; $05bd

@chooseBytePairForScoreSection:
; 4 times, for every bit set on D, go to next score byte pair
; ie score increases if we hit more than 1 thing in a shot
	ld b, $04                                                       ; $05be

@nextScoreEntry:
	sra d                                                           ; $05c0
	jr nc, +                                                        ; $05c2

	inc hl                                                          ; $05c4
	inc hl                                                          ; $05c5

+	dec b                                                           ; $05c6
	jr nz, @nextScoreEntry                                          ; $05c7

; CB = byte pair in table
	ld c, (hl)                                                      ; $05c9
	inc hl                                                          ; $05ca
	ld b, (hl)                                                      ; $05cb

; Add C 1ks and B 100s
	ld d, $00                                                       ; $05cc
	call AddB100sC1ksD10ksToCurrScore                               ; $05ce
	call CheckIfNewTopScore                                         ; $05d1

@afterScoreIncrease:
; Do some post-score-increase funcs
	call IncLivesIfApplicable                                       ; $05d4
	call UpdateShadowScoreValueLayout                               ; $05d7

; HL points to the layout elements for the curr layout, draw it
	ld a, (wInGameLayout)                                           ; $05da
	dec a                                                           ; $05dd
	ld hl, Layout1Elements                                          ; $05de
	or a                                                            ; $05e1
	jr z, @drawElements                                             ; $05e2

	ld hl, Layout2Elements                                          ; $05e4
	cp $01                                                          ; $05e7
	jr z, @drawElements                                             ; $05e9

	ld hl, Layout3Elements                                          ; $05eb

@drawElements:
	call DrawLayoutElements                                         ; $05ee

; After a while, check fires left, ie if we should freeze to add in pts
	ld a, $0a                                                       ; $05f1
	ld (wGenericTimers+1), a                                        ; $05f3

	ld hl, JumpFunc_CheckFiresLeft                                  ; $05f6
	ld (wTimer1JumpAddr), hl                                        ; $05f9
	ret                                                             ; $05fc


JumpFunc_CheckFiresLeft:
; Freeze if no fires left, else unfreeze everything
	ld a, (wInGameFiresShown)                                       ; $05fd
	or a                                                            ; $0600
	jr z, @noFires                                                  ; $0601

	xor a                                                           ; $0603
	ld (wInGameStandstillReason), a                                 ; $0604
	ret                                                             ; $0607

@noFires:
	ld a, $04                                                       ; $0608
	ld (wInGameStandstillReason), a                                 ; $060a
	ret                                                             ; $060d


WaterShotCollidedWithFireMain:
; Keep moving water shot if this func had water extinguish fire
	ld a, (wWaterExtinguishedStaticFire)                            ; $060e
	cp $ff                                                          ; $0611
	jp z, MoveWaterShot                                             ; $0613

; Else play extinguish sound, and set extinguish flag
	ld a, SND_FIRE_EXTINGUISHED                                     ; $0616
	ld (wSoundToPlay), a                                            ; $0618

	ld a, $ff                                                       ; $061b
	ld (wWaterExtinguishedStaticFire), a                            ; $061d

; Get address of fire main body, clear head part, and main body
	call CheckCollisionWithFireMain                                 ; $0620
	ld ix, Metatile_Empty                                           ; $0623
	ld a, (ix+$00)                                                  ; $0627
	ld (iy-$20), a                                                  ; $062a
	ld (iy-$1f), a                                                  ; $062d
	call LoadMetatile                                               ; $0630

; Load a blank metatile onto the fire area,
	ld ix, Metatile_Blank2                                          ; $0633
	call LoadMetatile                                               ; $0637
	ld (wDestAddrOfDestroyedStaticFire), iy                         ; $063a
	jp MoveWaterShot                                                ; $063e


; IY - addr of fire enemy
ProcessWaterHitFireEnemy:
; Jump if we tried to mark 1 fire enemy as extinguished, else set the flag
	ld a, (wWaterExtinguishedFireEnemy1)                            ; $0641
	cp $ff                                                          ; $0644
	jr z, @waterExtinguishedFireEnemies                             ; $0646

	ld a, $ff                                                       ; $0648
	ld (wWaterExtinguishedFireEnemy1), a                            ; $064a
	ld hl, wDestAddrOfDestroyedFireEnemies                          ; $064d

@checkIfExtinguishedEnemy:
; Loop through 3 fire enemies
	ld ix, wSprites+8                                               ; $0650
	ld b, $03                                                       ; $0654

@nextEnemy:
; If enemy y == the destroyed enemy's Y...
	ld a, (wDestroyedFireEnemyY)                                    ; $0656
	ld d, (ix+$00)                                                  ; $0659
	cp d                                                            ; $065c
	jr nz, @toNextEnemy                                             ; $065d

; And enemy x == the destroyed enemy's X...
	ld a, (wDestroyedFireEnemyX)                                    ; $065f
	ld d, (ix+$01)                                                  ; $0662
	cp d                                                            ; $0665
	jr nz, @toNextEnemy                                             ; $0666

; DE = fire enemy coords, set it in wDestAddrOfDestroyedFireEnemies
	push iy                                                         ; $0668
	pop de                                                          ; $066a
	ld (hl), e                                                      ; $066b
	inc hl                                                          ; $066c
	ld (hl), d                                                      ; $066d
	inc hl                                                          ; $066e

; Clear sprite
	ld (ix+$00), $00                                                ; $066f
	ld (ix+$01), $00                                                ; $0673
	ld (ix+$02), $00                                                ; $0677
	ld (ix+$03), $00                                                ; $067b
	call ClearEnemyDirectionVar                                     ; $067f

@toNextEnemy:
; To next 4-byte sprite
	ld de, $04                                                      ; $0682
	add ix, de                                                      ; $0685
	dec b                                                           ; $0687
	jr nz, @nextEnemy                                               ; $0688

; Once all enemis looped through, load a blank metatile in its place, and move water shot
	ld ix, Metatile_Blank2                                          ; $068a
	call LoadMetatile                                               ; $068e
	jp MoveWaterShot                                                ; $0691

@waterExtinguishedFireEnemies:
; Just move water shot if tried to mark a 2nd enemy as extinguiished...
	ld a, (wWaterExtinguishedFireEnemy2)                            ; $0694
	cp $ff                                                          ; $0697
	jp z, MoveWaterShot                                             ; $0699

; Else set flag, and try to fill 2nd slot for an extinguished enemy
	ld a, $ff                                                       ; $069c
	ld (wWaterExtinguishedFireEnemy2), a                            ; $069e
	ld hl, wDestAddrOfDestroyedFireEnemies+2                        ; $06a1
	jr @checkIfExtinguishedEnemy                                    ; $06a4


ScoresForDestroyingFires:
; Fire enemies
	.db $00, $00 ; 0
	.db $00, $02 ; 200
	.db $00, $05 ; 500
	.db $01, $00 ; 1000

; Static fire from above
	.db $01, $00 ; 1000
	.db $02, $00 ; 2000
	.db $03, $00 ; 3000
	.db $04, $00 ; 4000

; Static fire from another direction
	.db $00, $05 ; 500
	.db $01, $00 ; 1000
	.db $02, $00 ; 2000
	.db $03, $00 ; 3000


Metatile_Blank2:
	.db $37, $38, $39, $3a
	

; C - buttons held
; D - non-0 if we should only care about fire/wall
; Returns collision object in A
ProcessPlayerDirInput:
	push ix                                                         ; $06c2
	push hl                                                         ; $06c4
	push de                                                         ; $06c5
	push bc                                                         ; $06c6

; HL = player collision point X/Y and DE = current player's sprite X/Y
	ld hl, (wSprites)                                               ; $06c7
	ld de, (wSprites)                                               ; $06ca
	ld b, $00                                                       ; $06ce

; Branch based on direction held in this order
	bit REMAPPED_UP, c                                              ; $06d0
	jr nz, @upHeld                                                  ; $06d2

	bit REMAPPED_DOWN, c                                            ; $06d4
	jr nz, @downHeld                                                ; $06d6

	bit REMAPPED_RIGHT, c                                           ; $06d8
	jr nz, @rightHeld                                               ; $06da

	bit REMAPPED_LEFT, c                                            ; $06dc
	jr nz, @leftHeld                                                ; $06de

	pop bc                                                          ; $06e0
	pop de                                                          ; $06e1
	pop hl                                                          ; $06e2
	pop ix                                                          ; $06e3
	ret                                                             ; $06e5

@upHeld:
; C = 1 if we can move up
	ld c, $00                                                       ; $06e6

; Allow moving up if X is a multiple of 8 (tile-aligned)
	ld a, h                                                         ; $06e8
	and $0f                                                         ; $06e9
	or a                                                            ; $06eb
	jr z, @upCont                                                   ; $06ec

	cp $08                                                          ; $06ee
	jr z, @upCont                                                   ; $06f0

	ld c, $01                                                       ; $06f2

@upCont:
; Player collision check top pixel row of player, and sprite Y -= 2
	dec l                                                           ; $06f4
	dec l                                                           ; $06f5

	dec e                                                           ; $06f6
	dec e                                                           ; $06f7

; A = new collision Y, the jump will check if low nybble is $0a
	ld a, l                                                         ; $06f8
	jr @afterUpLeft                                                 ; $06f9

@downHeld:
; C = 1 if we can move down
	ld c, $00                                                       ; $06fb

; Allow moving down if X is a multiple of 8 (tile-aligned)
	ld a, h                                                         ; $06fd
	and $0f                                                         ; $06fe
	or a                                                            ; $0700
	jr z, @downCont                                                 ; $0701

	cp $08                                                          ; $0703
	jr z, @downCont                                                 ; $0705

	ld c, $01                                                       ; $0707

@downCont:
; Player collision check = bottom pixel row of player, once its Y is += 2
	ld a, $11                                                       ; $0709
	add a, l                                                        ; $070b
	ld l, a                                                         ; $070c

	inc e                                                           ; $070d
	inc e                                                           ; $070e
	jr @afterDownRight                                              ; $070f

@rightHeld:
; C = 1 if we can move right
	ld c, $00                                                       ; $0711

; Allow moving right if Y is a multiple of 8 (tile-aligned)
	ld a, l                                                         ; $0713
	and $0f                                                         ; $0714
	or a                                                            ; $0716
	jr z, @rightCont                                                ; $0717

	cp $08                                                          ; $0719
	jr z, @rightCont                                                ; $071b

	ld c, $01                                                       ; $071d

@rightCont:
; Player collision check = rightmost pixel row of player, once its X is += 2
	ld a, $11                                                       ; $071f
	add a, h                                                        ; $0721
	ld h, a                                                         ; $0722

	inc d                                                           ; $0723
	inc d                                                           ; $0724

@afterDownRight:
; A - player Y collision check if holding down, or X collision check if holding right
	and $0f                                                         ; $0725
	cp $06                                                          ; $0727
	jr z, @setBto1                                                  ; $0729

	jr @afterAllDirs                                                ; $072b

@leftHeld:
; C = 1 if we can move left
	ld c, $00                                                       ; $072d

; Allow moving left if Y is a multiple of 8 (tile-aligned)
	ld a, l                                                         ; $072f
	and $0f                                                         ; $0730
	or a                                                            ; $0732
	jr z, @leftCont                                                 ; $0733

	cp $08                                                          ; $0735
	jr z, @leftCont                                                 ; $0737

	ld c, $01                                                       ; $0739

@leftCont:
; Player collision check leftmost pixel row of player, and sprite X -= 2
	dec h                                                           ; $073b
	dec h                                                           ; $073c

	dec d                                                           ; $073d
	dec d                                                           ; $073e

; A = new collision X, below will check if low nybble is $0a
	ld a, h                                                         ; $073f

@afterUpLeft:
; A - player Y collision check if holding up, or X collision check if holding left
	and $0f                                                         ; $0740
	cp $0a                                                          ; $0742
	jr z, @setBto1                                                  ; $0744

@afterAllDirs:
	or a                                                            ; $0746
	jr z, @setBto1                                                  ; $0747

	cp $04                                                          ; $0749
	jr z, @setBto1                                                  ; $074b

	cp $08                                                          ; $074d
	jr z, @setBto1                                                  ; $074f

	cp $0c                                                          ; $0751
	jr nz, +                                                        ; $0753

@setBto1:
	ld b, $01                                                       ; $0755

; IY to point to tile that player should process collision with, DE to contain updated coords
+	ld (wPlayerCoords), hl                                          ; $0757
	call IYequAddrOfObjectNametableTile                             ; $075a

	ld (wPlayerCoords), de                                          ; $075d

; D = 1 if collision low nybble in [0, 4, 8, c], 6 if going down/right, a if going up/left
; E = 1 if player is tile-aligned (can move)
	ld d, b                                                         ; $0761
	ld e, c                                                         ; $0762

; Set that we are about to process collision
	ld a, $01                                                       ; $0763
	ld (wIsProcessingObjectCollision), a                            ; $0765

; Jump if a collision occurred
	call GetPlayerCollisionTypeInA                                  ; $0768
	or a                                                            ; $076b
	jr nz, @end                                                     ; $076c

; Re-push buttons held, IY to point to the next tile
	pop bc                                                          ; $076e
	push bc                                                         ; $076f
	inc iy                                                          ; $0770

; If moving left/right, check player's bottom-left tile, else keep it to top-right
	bit REMAPPED_UP, c                                              ; $0772
	jr nz, @check2ndCollision                                       ; $0774

	bit REMAPPED_DOWN, c                                            ; $0776
	jr nz, @check2ndCollision                                       ; $0778

	ld bc, $1f                                                      ; $077a
	add iy, bc                                                      ; $077d

@check2ndCollision:
; Jump if a collision happened with the new segment
	call GetPlayerCollisionTypeInA                                  ; $077f
	or a                                                            ; $0782
	jr nz, @end                                                     ; $0783

; If player is tile-aligned, there is no 3rd horiz/vert section to check
	ld a, e                                                         ; $0785
	or a                                                            ; $0786
	ld a, $00                                                       ; $0787
	jr z, @end                                                      ; $0789

; Else re-push buttons held, IY to point to the next tile
	pop bc                                                          ; $078b
	push bc                                                         ; $078c
	inc iy                                                          ; $078d

; If moving left/right, check player's bottom-left tile, else keep it to top-right
	bit REMAPPED_UP, c                                              ; $078f
	jr nz, @check3rdCollision                                       ; $0791

	bit REMAPPED_DOWN, c                                            ; $0793
	jr nz, @check3rdCollision                                       ; $0795

	ld bc, $1f                                                      ; $0797
	add iy, bc                                                      ; $079a

@check3rdCollision:
	call GetPlayerCollisionTypeInA                                  ; $079c

@end:
	pop bc                                                          ; $079f
	pop de                                                          ; $07a0
	pop hl                                                          ; $07a1
	pop ix                                                          ; $07a2

; Push collision type
	push af                                                         ; $07a4

; Clear that we're processing object collision
	xor a                                                           ; $07a5
	ld (wIsProcessingObjectCollision), a                            ; $07a6

; If orig D is non-0, return with collision type
	ld a, d                                                         ; $07a9
	or a                                                            ; $07aa
	jr z, @specialCollisionCase                                     ; $07ab

	pop af                                                          ; $07ad
	ret                                                             ; $07ae

@specialCollisionCase:
; Else only return with collision type if it's fire/wall
	pop af                                                          ; $07af
	cp COLL_FIRE_MAIN                                               ; $07b0
	ret z                                                           ; $07b2

	cp COLL_WALL                                                    ; $07b3
	ret z                                                           ; $07b5

	ld a, $00                                                       ; $07b6
	ret                                                             ; $07b8


; IY - points to nametable where player is processing a collision
GetPlayerCollisionTypeInA:
; Branch based on tile player is colliding with
	ld a, (iy+$00)                                                  ; $07b9
	cp TILE_BLANK                                                   ; $07bc
	jr z, @noCollision                                              ; $07be

	cp TILE_SMALL_PUDDLE_BOTTOM_RIGHT                               ; $07c0
	jr z, @smallPuddle                                              ; $07c2
	jr c, @smallPuddle                                              ; $07c4

	cp TILE_BIG_PUDDLE_BOTTOM_RIGHT                                 ; $07c6
	jr z, @bigPuddle                                                ; $07c8
	jr c, @bigPuddle                                                ; $07ca

	cp TILE_FIRE_MAIN_BOTTOM_RIGHT                                  ; $07cc
	jr z, @fireMain                                                 ; $07ce
	jr c, @fireMain                                                 ; $07d0

	cp TILE_FIRE_HEAD_LEFT_1                                        ; $07d2
	jr z, @noCollision                                              ; $07d4

	cp TILE_FIRE_HEAD_RIGHT_1                                       ; $07d6
	jr z, @noCollision                                              ; $07d8

	cp TILE_FIRE_HEAD_LEFT_2                                        ; $07da
	jr z, @noCollision                                              ; $07dc

	cp TILE_FIRE_HEAD_RIGHT_2                                       ; $07de
	jr z, @noCollision                                              ; $07e0

	cp TILE_WALL_3RD                                                ; $07e2
	jr z, @wall                                                     ; $07e4
	jr c, @wall                                                     ; $07e6

; If colliding with the very center of the screen, return 2
	push iy                                                         ; $07e8
	ld iy, wNameTable+$16b                                          ; $07ea
	call HLequRowColPixelsAtNametableAddrIY                         ; $07ee
	call CheckIfCollidingWithMetatileCenter                         ; $07f1
	pop iy                                                          ; $07f4

	or a                                                            ; $07f6
	jr nz, @noCollision                                             ; $07f7

	ld a, COLL_CENTER                                               ; $07f9
	ret                                                             ; $07fb

@noCollision:
	ld a, COLL_NONE                                                 ; $07fc
	ret                                                             ; $07fe

@smallPuddle:
	push iy                                                         ; $07ff
	call CheckCollisionWithSmallPuddle                              ; $0801
	call HLequRowColPixelsAtNametableAddrIY                         ; $0804
	call CheckIfCollidingWithMetatileCenter                         ; $0807
	pop iy                                                          ; $080a

	or a                                                            ; $080c
	jr nz, @noCollision                                             ; $080d

	ld a, COLL_SMALL_PUDDLE                                         ; $080f
	ret                                                             ; $0811

@bigPuddle:
	push iy                                                         ; $0812
	call CheckCollisionWithBigPuddle                                ; $0814
	call HLequRowColPixelsAtNametableAddrIY                         ; $0817
	call CheckIfCollidingWithMetatileCenter                         ; $081a
	pop iy                                                          ; $081d

	or a                                                            ; $081f
	jr nz, @noCollision                                             ; $0820

	ld a, COLL_BIG_PUDDLE                                           ; $0822
	ret                                                             ; $0824

@fireMain:
	push iy                                                         ; $0825
	call CheckCollisionWithFireMain                                 ; $0827
	call HLequRowColPixelsAtNametableAddrIY                         ; $082a
	call CheckIfCollidingWithMetatileCenter                         ; $082d
	pop iy                                                          ; $0830

	or a                                                            ; $0832
	jr nz, @noCollision                                             ; $0833

	ld a, COLL_FIRE_MAIN                                            ; $0835
	ret                                                             ; $0837

@wall:
	ld a, COLL_WALL                                                 ; $0838
	ret                                                             ; $083a


MoveObject:
; Jump if player has water
	ld a, (wPlayerWaterLevel)                                       ; $083b
	or a                                                            ; $083e
	jr nz, @hasWater                                                ; $083f

; Otherwise reset timers, and update player
	xor a                                                           ; $0841
	ld (wPlayerMovementTimer1), a                                   ; $0842

@clearTimer2MoveObject:
	xor a                                                           ; $0845
	ld (wPlayerMovementTimer2), a                                   ; $0846

@updatePlayerCoords:
; Update for player outline + water, then animate player
	ld hl, (wPlayerCoords)                                          ; $0849
	ld (wSprites), hl                                               ; $084c
	ld (wSprites+4), hl                                             ; $084f
	call AnimatePlayer                                              ; $0852
	ret                                                             ; $0855

@hasWater:
; Update player's movement timers
	ld hl, (wPlayerMovementTimer1)                                  ; $0856
	inc h                                                           ; $0859
	inc l                                                           ; $085a
	ld (wPlayerMovementTimer1), hl                                  ; $085b

; If timer 1 has reached its threshold...
	ld a, (@timer1threshold)                                        ; $085e
	cp l                                                            ; $0861
	jr nz, @checkTimer2                                             ; $0862

; Clear the 1st timer, and update player's coords
	xor a                                                           ; $0864
	ld (wPlayerMovementTimer1), a                                   ; $0865
	jr @updatePlayerCoords                                          ; $0868

@checkTimer2:
; Else update player only if the 2nd timer > the 2nd threshold
	ld a, (@timer2threshold)                                        ; $086a
	cp h                                                            ; $086d
	jr z, @clearTimer2MoveObject                                    ; $086e
	jr c, @clearTimer2MoveObject                                    ; $0870

	ret                                                             ; $0872

@timer1threshold:
	.db $02

@timer2threshold:
	.db $06
	
	
; Returns A=1 if collision occurred
; Returns address of latest extinguished enemy in IY
CheckEnemyCollisionAgainstObjectCoords:
	ld ix, wObjectY                                                 ; $0875
	jr +                                                            ; $0879

; Returns A=1 if collision occurred
CheckEnemyCollisionAgainstPlayerCoords:
	ld ix, wSprites                                                 ; $087b

+	push bc                                                         ; $087f

; Loop through each enemy's sprite
	ld hl, wSprites+8                                               ; $0880
	ld b, $03                                                       ; $0883

; Clear destroyed fire enemy coords
	ld de, $00                                                      ; $0885
	ld (wDestroyedFireEnemyX), de                                   ; $0888

@nextEnemy:
; C = enemy Y+7 (middle of sprite)
	ld a, (hl)                                                      ; $088c
	add a, $07                                                      ; $088d
	ld c, a                                                         ; $088f

; Go to next enemy if obj/player Y > middle, else branch
	ld a, (ix+$00)                                                  ; $0890
	cp c                                                            ; $0893
	jr z, @checkX                                                   ; $0894

	jr c, @aboveEnemy                                               ; $0896

@toNextEnemy:
	inc hl                                                          ; $0898
	inc hl                                                          ; $0899
	inc hl                                                          ; $089a
	inc hl                                                          ; $089b

	dec b                                                           ; $089c
	jr nz, @nextEnemy                                               ; $089d

; If D == 0 (we didn't hit anything), return
	ld a, d                                                         ; $089f
	pop bc                                                          ; $08a0
	or a                                                            ; $08a1
	ret z                                                           ; $08a2

; Else play fire extinguished sound, and return with A non-0 (collision occurred)
	push af                                                         ; $08a3
	ld a, SND_FIRE_EXTINGUISHED                                     ; $08a4
	ld (wSoundToPlay), a                                            ; $08a6
	pop af                                                          ; $08a9
	ret                                                             ; $08aa

@aboveEnemy:
; A = pixel Y+$0f of obj/player, ie bottom pixel. Ignore enemy if < middle
	add a, $0f                                                      ; $08ab
	cp c                                                            ; $08ad
	jr z, @checkX                                                   ; $08ae

	jr c, @toNextEnemy                                              ; $08b0

@checkX:
; A = enemy X, dec HL to point to enemy Y, C = enemy X+7 (middle of sprite)
	inc hl                                                          ; $08b2
	ld a, (hl)                                                      ; $08b3
	dec hl                                                          ; $08b4
	add a, $07                                                      ; $08b5
	ld c, a                                                         ; $08b7

; Go to next enemy if wObjectX > middle
	ld a, (ix+$01)                                                  ; $08b8
	cp c                                                            ; $08bb
	jr z, @collisionOccurred                                        ; $08bc

	jr nc, @toNextEnemy                                             ; $08be

; A = pixel X+$0f of obj/player, ie right pixel. Ignore enemy if < middle
	add a, $0f                                                      ; $08c0
	cp c                                                            ; $08c2
	jr z, @collisionOccurred                                        ; $08c3

	jr c, @toNextEnemy                                              ; $08c5

@collisionOccurred:
; D = 1 (to show that we've extinguished something)
	inc d                                                           ; $08c7

; Preserve curr player coords
	push hl                                                         ; $08c8
	ld hl, (wPlayerCoords)                                          ; $08c9
	ld (wPreservedPlayerCoordsDuringEnemyDeath), hl                 ; $08cc
	pop hl                                                          ; $08cf

	push hl                                                         ; $08d0

; Store destroyed enemy's Y
	ld a, (hl)                                                      ; $08d1
	ld (wDestroyedFireEnemyY), a                                    ; $08d2
	ld (wObjectY), a                                                ; $08d5

; Store destroyed enemy's X
	inc hl                                                          ; $08d8
	ld a, (hl)                                                      ; $08d9
	ld (wDestroyedFireEnemyX), a                                    ; $08da
	ld (wObjectX), a                                                ; $08dd

; IY = address of enemy, restore player coords, and go to next enemy
	call IYequAddrOfObjectNametableTile                             ; $08e0
	ld hl, (wPreservedPlayerCoordsDuringEnemyDeath)                 ; $08e3
	ld (wPlayerCoords), hl                                          ; $08e6
	pop hl                                                          ; $08e9
	jr @toNextEnemy                                                 ; $08ea


IncLivesIfApplicable:
	ld iy, wCurrScoreDigits                                         ; $08ec
	ld hl, wBonusLivesGotten                                        ; $08f0

; Jump if 0 bonus lives gotten
	ld a, (hl)                                                      ; $08f3
	or a                                                            ; $08f4
	jr z, @noBonusLivesGotten                                       ; $08f5

; Return if we already have both bonus lives
	cp $00                                                          ; $08f7
	ret z                                                           ; $08f9

	cp $01                                                          ; $08fa
	ret nz                                                          ; $08fc

; +1 to lives if score >= 100k
	ld a, (iy+$00)                                                  ; $08fd
	cp $01                                                          ; $0900
	ret nz                                                          ; $0902

	jr @incLives                                                    ; $0903

@noBonusLivesGotten:
; +1 to lives if score >= 30k
	ld a, (iy+$01)                                                  ; $0905
	cp $03                                                          ; $0908
	ret nz                                                          ; $090a

@incLives:
; Inc bonus lives gotten, displayed lives, then layout
	inc (hl)                                                        ; $090b

	ld a, (wDisplayedLivesLeft)                                     ; $090c
	inc a                                                           ; $090f
	ld (wDisplayedLivesLeft), a                                     ; $0910

	call UpdateLivesLeftCurrRoundAndScore                           ; $0913
	ret                                                             ; $0916


SetPlayerWaterLevelTileIdx:
	ld e, SPR_WATER_LEVEL_EMPTY                                     ; $0917

	ld a, (wPlayerWaterLevel)                                       ; $0919
	or a                                                            ; $091c
	jr z, @setWaterTileIdx                                          ; $091d

	ld e, SPR_WATER_LEVEL_LOW                                       ; $091f
	dec a                                                           ; $0921
	jr z, @setWaterTileIdx                                          ; $0922

	ld e, SPR_WATER_LEVEL_MID                                       ; $0924
	dec a                                                           ; $0926
	jr z, @setWaterTileIdx                                          ; $0927

	ld e, SPR_WATER_LEVEL_HIGH                                      ; $0929

@setWaterTileIdx:
	ld a, e                                                         ; $092b
	ld (wSprites+6), a                                              ; $092c
	ret                                                             ; $092f


AnimatePlayer:
	ld iy, wRemappedBtnsHeld                                        ; $0930

; E = prev directions held
	ld hl, wPrevBtnsHeld                                            ; $0934
	ld a, (hl)                                                      ; $0937
	and $1e                                                         ; $0938
	ld e, a                                                         ; $093a

; D = buttons held
	ld a, (iy+$00)                                                  ; $093b
	and $1e                                                         ; $093e
	ld d, a                                                         ; $0940

; Jump if same direction btns held
	cp e                                                            ; $0941
	jr z, @sameBtnsHeld                                             ; $0942

	ld e, $00                                                       ; $0944
	bit REMAPPED_RIGHT, a                                           ; $0946
	jr nz, @setTileIdx                                              ; $0948

	ld e, $08                                                       ; $094a
	bit REMAPPED_LEFT, a                                            ; $094c
	jr nz, @setTileIdx                                              ; $094e

	ld e, $10                                                       ; $0950

@setTileIdx:
	ld a, e                                                         ; $0952
	ld (wSprites+2), a                                              ; $0953

; Prev buttons = retained action buttons, plus current dir buttons held
	ld a, (hl)                                                      ; $0956
	and $21                                                         ; $0957
	or d                                                            ; $0959
	ld (hl), a                                                      ; $095a
	ret                                                             ; $095b

@sameBtnsHeld:
; If player tile == 0, do 2nd frame of anim
	ld a, (wSprites+2)                                              ; $095c
	or a                                                            ; $095f
	jr z, @secondFrame                                              ; $0960

; Same with tile == 8. If tile < 8 (ie 4 for doing copy backwards)
	cp $08                                                          ; $0962
	jr z, @secondFrame                                              ; $0964

	jr c, @firstFrame                                               ; $0966

; Same with tile == $10
	cp $10                                                          ; $0968
	jr z, @secondFrame                                              ; $096a

	jr @firstFrame                                                  ; $096c

@secondFrame:
	add a, $04                                                      ; $096e
	jr +                                                            ; $0970

@firstFrame:
	sub $04                                                         ; $0972

+	ld e, a                                                         ; $0974
	jr @setTileIdx                                                  ; $0975


; Returns nametable addr of collided element in IY
CheckCollisionWithFireMain:
	ld ix, Layout1Elements                                          ; $0977
	ld hl, wInGameFiresShown                                        ; $097b
	jr +                                                            ; $097e


; Returns nametable addr of collided element in IY
CheckCollisionWithBigPuddle:
	ld ix, Layout1Elements+6                                        ; $0980
	ld hl, wInGameBigPuddlesShown                                   ; $0984
	jr +                                                            ; $0987


; Returns nametable addr of collided element in IY
CheckCollisionWithSmallPuddle:
	ld ix, Layout1Elements+12                                       ; $0989
	ld hl, wInGameSmallPuddlesShown                                 ; $098d

+	push bc                                                         ; $0990

; Offset to check the right table
	ld a, (wInGameLayout)                                           ; $0991
	ld de, Layout2Elements-Layout1Elements                          ; $0994

@nextLayoutAdd:
	dec a                                                           ; $0997
	jr z, +                                                         ; $0998

	add ix, de                                                      ; $099a
	jr @nextLayoutAdd                                               ; $099c

; DE = nametable address of tile we're checking
+	ld c, $03                                                       ; $099e
	push iy                                                         ; $09a0
	pop de                                                          ; $09a2

@nextOfCurrElementType:
; If high bytes are different, don't even consider the element
	ld a, (ix+$01)                                                  ; $09a3
	cp d                                                            ; $09a6
	jr nz, @toNextOfCurrElementType                                 ; $09a7

; If low byte of element has it up-left to up-right of player, match found
	ld a, (ix+$00)                                                  ; $09a9
	sub $21                                                         ; $09ac
	cp e                                                            ; $09ae
	jr z, @matchFound                                               ; $09af

	inc a                                                           ; $09b1
	cp e                                                            ; $09b2
	jr z, @matchFound                                               ; $09b3

	inc a                                                           ; $09b5
	cp e                                                            ; $09b6
	jr z, @matchFound                                               ; $09b7

; If low byte of element has it on the same horiz level of player, match found
	add a, $1e                                                      ; $09b9
	cp e                                                            ; $09bb
	jr z, @matchFound                                               ; $09bc

	inc a                                                           ; $09be
	cp e                                                            ; $09bf
	jr z, @matchFound                                               ; $09c0

	inc a                                                           ; $09c2
	cp e                                                            ; $09c3
	jr z, @matchFound                                               ; $09c4

; If low byte of element has it down-left to down-right of player, match found
	add a, $1e                                                      ; $09c6
	cp e                                                            ; $09c8
	jr z, @matchFound                                               ; $09c9

	inc a                                                           ; $09cb
	cp e                                                            ; $09cc
	jr z, @matchFound                                               ; $09cd

	inc a                                                           ; $09cf
	cp e                                                            ; $09d0
	jr z, @matchFound                                               ; $09d1

@toNextOfCurrElementType:
; IX+2 to get to next of curr element type
	inc ix                                                          ; $09d3
	inc ix                                                          ; $09d5

	dec c                                                           ; $09d7
	jr nz, @nextOfCurrElementType                                   ; $09d8

	pop bc                                                          ; $09da
	ret                                                             ; $09db

@matchFound:
; Don't remove element if we're doing this check while processing object collision
	ld a, (wIsProcessingObjectCollision)                            ; $09dc
	or a                                                            ; $09df
	jr nz, @afterRemovingElement                                    ; $09e0

; B = bitfield of elements shown, if C = 0 (impossible), keep bitfield 0
	ld b, (hl)                                                      ; $09e2
	ld a, c                                                         ; $09e3
	or a                                                            ; $09e4
	jr z, @removeElement                                            ; $09e5

; Branch based on decrementing counter
	cp $01                                                          ; $09e7
	jr z, @remove3rdElement                                         ; $09e9

	cp $02                                                          ; $09eb
	jr z, @remove2ndElement                                         ; $09ed

; If 3, it's the 1st element
	res 0, b                                                        ; $09ef
	jr @removeElement                                               ; $09f1

@remove2ndElement:
	res 1, b                                                        ; $09f3
	jr @removeElement                                               ; $09f5

@remove3rdElement:
	res 2, b                                                        ; $09f7

@removeElement:
	ld (hl), b                                                      ; $09f9

@afterRemovingElement:
; IY = pointer to the current layout element
	ld c, (ix+$00)                                                  ; $09fa
	ld b, (ix+$01)                                                  ; $09fd
	push bc                                                         ; $0a00
	pop iy                                                          ; $0a01

	pop bc                                                          ; $0a03
	ret                                                             ; $0a04


; B - 1 for enemy 3, 2 for enemy 2, 3 for enemy 1
ClearEnemyDirectionVar:
	push hl                                                         ; $0a05
	push bc                                                         ; $0a06

	ld hl, wEnemyDirection+3                                        ; $0a07
	ld c, b                                                         ; $0a0a
	ld b, $00                                                       ; $0a0b
	sbc hl, bc                                                      ; $0a0d
	ld (hl), $00                                                    ; $0a0f

	pop bc                                                          ; $0a11
	pop hl                                                          ; $0a12
	ret                                                             ; $0a13


HandleTimer2Func_SpecialItem:
; Return if already in a stand-still
	ld a, (wInGameStandstillReason)                                 ; $0a14
	or a                                                            ; $0a17
	ret nz                                                          ; $0a18

; If center item exists, load its metatile
	ld a, (wCenterItemLoaded)                                       ; $0a19
	or a                                                            ; $0a1c
	jr z, @afterCenterItemExistsCheck                               ; $0a1d

	ld ix, (wCenterItemMetatileAddr)                                ; $0a1f
	ld iy, wNameTable+$16b                                          ; $0a23
	call LoadMetatile                                               ; $0a27

@afterCenterItemExistsCheck:
; Return if timer not yet 0
	ld a, (wGenericTimers+2)                                        ; $0a2a
	or a                                                            ; $0a2d
	ret nz                                                          ; $0a2e

; Use jump func if set
	ld hl, (wTimer2JumpAddr)                                        ; $0a2f
	ld a, h                                                         ; $0a32
	or l                                                            ; $0a33
	jr z, @noJumpFunc                                               ; $0a34

	ld bc, $00                                                      ; $0a36
	ld (wTimer2JumpAddr), bc                                        ; $0a39
	jp (hl)                                                         ; $0a3d

@noJumpFunc:
; Loop through big puddles bitfield, C to have num big puddles
	ld a, (wInGameBigPuddlesShown)                                  ; $0a3e
	ld b, $03                                                       ; $0a41
	ld c, $00                                                       ; $0a43

@nextBigPuddle:
	srl a                                                           ; $0a45
	jr nc, +                                                        ; $0a47
	inc c                                                           ; $0a49
+	dec b                                                           ; $0a4a
	jr nz, @nextBigPuddle                                           ; $0a4b

; Jump if 2 big puddles left
	ld a, c                                                         ; $0a4d
	cp $02                                                          ; $0a4e
	jr z, @twoBigPuddlesLeft                                        ; $0a50

; Return if 0 big puddles left
	or a                                                            ; $0a52
	ret z                                                           ; $0a53

; If 1 (or 3) big puddles left, load a center item if it had already been loaded once
	ld a, (wNumSpecialItemsLoaded)                                  ; $0a54
	cp $01                                                          ; $0a57
	ret nz                                                          ; $0a59

	jr JumpFunc_CenterItemLoaded                                    ; $0a5a

@twoBigPuddlesLeft:
; If 2 big puddles left, load a center item if it hadn't loaded before
	ld a, (wNumSpecialItemsLoaded)                                  ; $0a5c
	or a                                                            ; $0a5f
	ret nz                                                          ; $0a60

JumpFunc_CenterItemLoaded:
; Don't proceed until center item is clear
	ld a, (wNameTable+$16b)                                         ; $0a61
	cp TILE_BLANK                                                   ; $0a64
	jr nz, SetJumpFuncToCenterItemLoaded                            ; $0a66

; Inc num special items loaded. Use special water for the 1st item, and wine for the later ones
	ld a, (wNumSpecialItemsLoaded)                                  ; $0a68
	inc a                                                           ; $0a6b
	ld ix, Metatile_SpecialWater                                    ; $0a6c
	cp $01                                                          ; $0a70
	jr z, +                                                         ; $0a72
	ld ix, Metatile_SpecialWine                                     ; $0a74
+	ld (wNumSpecialItemsLoaded), a                                  ; $0a78
	ld (wOrigSpecialItemsLoaded), a                                 ; $0a7b

; Set that an item was loaded, save the chosen metatile addr, then load metatile
	ld a, $01                                                       ; $0a7e
	ld (wCenterItemLoaded), a                                       ; $0a80
	ld (wCenterItemMetatileAddr), ix                                ; $0a83

	ld iy, wNameTable+$16b                                          ; $0a87
	call LoadMetatile                                               ; $0a8b

; Set timer for wait func below
	ld a, $ff                                                       ; $0a8e
	ld (wGenericTimers+2), a                                        ; $0a90

	ld hl, JumpFunc_WaitAfterSpecialItemLoaded                      ; $0a93
	ld (wTimer2JumpAddr), hl                                        ; $0a96
	ret                                                             ; $0a99


JumpFunc_WaitAfterSpecialItemLoaded:
; Simply wait longer
	ld a, $ff                                                       ; $0a9a
	ld (wGenericTimers+2), a                                        ; $0a9c

	ld hl, JumpFunc_ClearSpecialItem                                ; $0a9f
	ld (wTimer2JumpAddr), hl                                        ; $0aa2
	ret                                                             ; $0aa5


JumpFunc_ClearSpecialItem:
; Clear that a special item was loaded, then clear the tiles in the center
	xor a                                                           ; $0aa6
	ld (wCenterItemLoaded), a                                       ; $0aa7

	ld ix, Metatile_Empty                                           ; $0aaa
	ld iy, wNameTable+$16b                                          ; $0aae
	call LoadMetatile                                               ; $0ab2
	ret                                                             ; $0ab5


SetJumpFuncToCenterItemLoaded:
	ld hl, JumpFunc_CenterItemLoaded                                ; $0ab6
	ld (wTimer2JumpAddr), hl                                        ; $0ab9
	ret                                                             ; $0abc


Metatile_SpecialWater:
	.db $50, $51, $52, $53


Metatile_SpecialWine:
	.db $54, $55, $56, $57


Metatile_Empty:
	.db $4b, $4b, $4b, $4b


UpdateFireEnemies:
; Return if the game is at a stand-still
	ld a, (wInGameStandstillReason)                                 ; $0ac9
	or a                                                            ; $0acc
	ret nz                                                          ; $0acd

; If timer stuck at 0, check if we should reset it
	ld a, (wEnemySpawnTimer)                                        ; $0ace
	or a                                                            ; $0ad1
	jp z, @checkIfShouldResetSpawnTimer                             ; $0ad2

; Jump if dec'd timer not yet 0
	dec a                                                           ; $0ad5
	ld (wEnemySpawnTimer), a                                        ; $0ad6
	jp nz, @afterSpawnTimer                                         ; $0ad9

; Create enemy in the fire closest to the player if nothing spawned from iit
	call EequClosestFireIdxToPlayer                                 ; $0adc
	call CheckIfEnemyAlreadySpawnedFromFireOrFireDead               ; $0adf
	or a                                                            ; $0ae2
	jr z, @createEnemy                                              ; $0ae3

; Else attempt creating the enemy from the other fires in order using above check
	ld e, $00                                                       ; $0ae5
	ld hl, (wFire1SpawnCoords)                                      ; $0ae7
	call CheckIfEnemyAlreadySpawnedFromFireOrFireDead               ; $0aea
	or a                                                            ; $0aed
	jr z, @createEnemy                                              ; $0aee

	ld e, $01                                                       ; $0af0
	ld hl, (wFire2SpawnCoords)                                      ; $0af2
	call CheckIfEnemyAlreadySpawnedFromFireOrFireDead               ; $0af5
	or a                                                            ; $0af8
	jr z, @createEnemy                                              ; $0af9

	ld e, $02                                                       ; $0afb
	ld hl, (wFire3SpawnCoords)                                      ; $0afd
	call CheckIfEnemyAlreadySpawnedFromFireOrFireDead               ; $0b00
	or a                                                            ; $0b03
	jr z, @createEnemy                                              ; $0b04

; At this point, just try to create anywhere, even if a living enemy had spawned there
; Check enemy 1, jumping if it exists
	ld e, $00                                                       ; $0b06
	ld a, (wEnemyDirection)                                         ; $0b08
	or a                                                            ; $0b0b
	jr nz, @checkEnemy2                                             ; $0b0c

; Spawn from fires 2, or 3 if they exist
	ld hl, (wFire2SpawnCoords)                                      ; $0b0e
	ld a, (wInGameFiresShown)                                       ; $0b11
	bit 1, a                                                        ; $0b14
	jr nz, @createEnemy                                             ; $0b16

	ld hl, (wFire3SpawnCoords)                                      ; $0b18
	bit 2, a                                                        ; $0b1b
	jr nz, @createEnemy                                             ; $0b1d

@checkEnemy2:
; Check enemy 2, jumping if it exists
	ld e, $01                                                       ; $0b1f
	ld a, (wEnemyDirection+1)                                       ; $0b21
	or a                                                            ; $0b24
	jr nz, @checkEnemy3                                             ; $0b25

; Spawn from fires 1, or 3 if they exist
	ld hl, (wFire1SpawnCoords)                                      ; $0b27
	ld a, (wInGameFiresShown)                                       ; $0b2a
	bit 0, a                                                        ; $0b2d
	jr nz, @createEnemy                                             ; $0b2f

	ld hl, (wFire3SpawnCoords)                                      ; $0b31
	bit 2, a                                                        ; $0b34
	jr nz, @createEnemy                                             ; $0b36

@checkEnemy3:
; Check enemy 3, jumping if it exists
	ld e, $02                                                       ; $0b38
	ld a, (wEnemyDirection+2)                                       ; $0b3a
	or a                                                            ; $0b3d
	jr nz, @checkIfShouldResetSpawnTimer                            ; $0b3e

; Spawn from fires 1, or 2 if they exist
	ld hl, (wFire1SpawnCoords)                                      ; $0b40
	ld a, (wInGameFiresShown)                                       ; $0b43
	bit 0, a                                                        ; $0b46
	jr nz, @createEnemy                                             ; $0b48

	ld hl, (wFire2SpawnCoords)                                      ; $0b4a
	bit 1, a                                                        ; $0b4d
	jr nz, @createEnemy                                             ; $0b4f

	jr @checkIfShouldResetSpawnTimer                                ; $0b51

@createEnemy:
; E = sprite slot, H = X, L = Y
; Have IX = slot to create enemy
	ld ix, wSprites+8                                               ; $0b53
	ld d, $00                                                       ; $0b57
	add ix, de                                                      ; $0b59
	add ix, de                                                      ; $0b5b
	add ix, de                                                      ; $0b5d
	add ix, de                                                      ; $0b5f

; Set coords and have it looking right with a dark red color
	ld (ix+$00), l                                                  ; $0b61
	ld (ix+$01), h                                                  ; $0b64
	ld (ix+$02), SPR_ENEMY_TAIL_BOTTOM_LEFT                         ; $0b67
	ld (ix+$03), $08                                                ; $0b6b

; Starting enemy sprite is tail bottom-left, clear unused struct var
	ld ix, wEnemyDirection                                          ; $0b6f
	add ix, de                                                      ; $0b73
	ld (ix+$00), $02                                                ; $0b75
	ld (ix+wUnusedEnemyStructVars_c06e-wEnemyDirection), $00        ; $0b79

; Play sound as a result of enemy spawn
	ld a, SND_ENEMY_SPAWNED                                         ; $0b7d
	ld (wSoundToPlay), a                                            ; $0b7f

@checkIfShouldResetSpawnTimer:
; Loop through 3 enemies
	ld hl, wEnemyDirection                                          ; $0b82
	ld b, $03                                                       ; $0b85

@checkIfNextEnemyExists:
; If any of the 3 don't exist, reset the spawn timer
	ld a, (hl)                                                      ; $0b87
	or a                                                            ; $0b88
	jr z, @resetSpawnTimer                                          ; $0b89

	inc hl                                                          ; $0b8b
	dec b                                                           ; $0b8c
	jr nz, @checkIfNextEnemyExists                                  ; $0b8d

	jr @afterSpawnTimer                                             ; $0b8f

@resetSpawnTimer:
	ld a, $80                                                       ; $0b91
	ld (wEnemySpawnTimer), a                                        ; $0b93

@afterSpawnTimer:
; Now loop through, updating enemies
	ld ix, wEnemyDirection                                          ; $0b96
	ld e, $00                                                       ; $0b9a

@updateNextEnemy:
	ld a, (ix+$00)                                                  ; $0b9c
	or a                                                            ; $0b9f
	jr nz, @updateEnemy                                             ; $0ba0

@toUpdateNextEnemy:
	inc ix                                                          ; $0ba2
	inc e                                                           ; $0ba4

; Stop when all 3 done
	ld a, e                                                         ; $0ba5
	cp $03                                                          ; $0ba6
	jr nz, @updateNextEnemy                                         ; $0ba8

	ret                                                             ; $0baa

@updateEnemy:
; Go to next enemy if we should skip updating it
	call CheckIfShouldSkipUpdatingEnemy                             ; $0bab
	or a                                                            ; $0bae
	jr nz, @toUpdateNextEnemy                                       ; $0baf

; Process enemy movement
	call MapEnemysSpriteAndDirIntoPlayers                           ; $0bb1
	call ProcessEnemyMovement                                       ; $0bb4
	call UpdateEnemySpriteTileAndCoords                             ; $0bb7
	call RestorePlayersSpritesAndBtnsStatus                         ; $0bba

; Check if enemy hit the player...
	push ix                                                         ; $0bbd
	push de                                                         ; $0bbf
	call CheckEnemyCollisionAgainstPlayerCoords                     ; $0bc0
	pop de                                                          ; $0bc3
	pop ix                                                          ; $0bc4

	or a                                                            ; $0bc6
	jp z, @toUpdateNextEnemy                                        ; $0bc7

; Setting flag if it did
	ld (wPlayerHitByEnemy), a                                       ; $0bca
	jp @toUpdateNextEnemy                                           ; $0bcd


; Returns fire spawn coords in HL
EequClosestFireIdxToPlayer:
; Loop through fire spawn coords
	call IXequCurrLayoutElementsAddr                                ; $0bd0
	ld iy, wFire1SpawnCoords                                        ; $0bd3
	ld d, $03                                                       ; $0bd7

@nextSpawnCoords:
; A = total pixel diff between player and fire
	push iy                                                         ; $0bd9
	call AequXplusYpixelDiffBetweenPlayerAndFire                    ; $0bdb
	pop iy                                                          ; $0bde

; Set spawn coords to row/col of relevant fire, and set total pixel diff
	ld (iy+$00), h                                                  ; $0be0
	ld (iy+$01), l                                                  ; $0be3
	ld (iy+$06), a                                                  ; $0be6

; To next spawn coords
	inc ix                                                          ; $0be9
	inc ix                                                          ; $0beb
	inc iy                                                          ; $0bed
	inc iy                                                          ; $0bef

	dec d                                                           ; $0bf1
	jr nz, @nextSpawnCoords                                         ; $0bf2

; A, C, D = total pixel diff for the 3 fires
	ld iy, wFiresPixelDistanceToPlayer                              ; $0bf4
	ld a, (iy+$00)                                                  ; $0bf8
	ld c, (iy+$02)                                                  ; $0bfb
	ld d, (iy+$04)                                                  ; $0bfe

; If fire 1 is closer or equal to fire 2, don't consider fire 2
	cp c                                                            ; $0c01
	jr z, @notFire2                                                 ; $0c02
	jr c, @notFire2                                                 ; $0c04

; Fire 1 is not the closest. If fire 2 is closer than fire 3, use that
	ld a, c                                                         ; $0c06
	cp d                                                            ; $0c07
	jr z, @returnFire2                                              ; $0c08
	jr c, @returnFire2                                              ; $0c0a

@returnFire3:
; Else use fire 3
	ld e, $02                                                       ; $0c0c
	ld hl, (wFire3SpawnCoords)                                      ; $0c0e
	ret                                                             ; $0c11

@notFire2:
; If fire 1 is closer or equal in distance than fire 3, use it, else use fire 3
	cp d                                                            ; $0c12
	jr z, @returnFire1                                              ; $0c13

	jr nc, @returnFire3                                             ; $0c15

@returnFire1:
	ld e, $00                                                       ; $0c17
	ld hl, (wFire1SpawnCoords)                                      ; $0c19
	ret                                                             ; $0c1c

@returnFire2:
	ld e, $01                                                       ; $0c1d
	ld hl, (wFire2SpawnCoords)                                      ; $0c1f
	ret                                                             ; $0c22


; IX - pointer to curr fire element nametable addr
; Returns HL = row/col pixel
AequXplusYpixelDiffBetweenPlayerAndFire:
	push bc                                                         ; $0c23
	push de                                                         ; $0c24

; DE, then IY = nametable addr of fire
	ld e, (ix+$00)                                                  ; $0c25
	ld d, (ix+$01)                                                  ; $0c28
	push de                                                         ; $0c2b
	pop iy                                                          ; $0c2c

; Check fire location against player coords
	call HLequRowColPixelsAtNametableAddrIY                         ; $0c2e
	ld de, (wSprites)                                               ; $0c31

; B = y pixel diff
	ld a, d                                                         ; $0c35
	sub h                                                           ; $0c36
	jr nc, +                                                        ; $0c37
	cpl                                                             ; $0c39
+	ld b, a                                                         ; $0c3a

; Add on x pixel diff
	ld a, e                                                         ; $0c3b
	sub l                                                           ; $0c3c
	jr nc, +                                                        ; $0c3d
	cpl                                                             ; $0c3f
+	add a, b                                                        ; $0c40

	pop de                                                          ; $0c41
	pop bc                                                          ; $0c42
	ret                                                             ; $0c43


; E - fire idx to spawn enemy in
; Returns A=0 if the enemy can spawn in the fire
CheckIfEnemyAlreadySpawnedFromFireOrFireDead:
	push ix                                                         ; $0c44
	push de                                                         ; $0c46

; A = fire idx
	ld ix, wEnemyDirection                                          ; $0c47
	ld a, e                                                         ; $0c4b

; IX = enemy direction associated with fire
@loopFireIdx:
	or a                                                            ; $0c4c
	jr z, @afterIncIX                                               ; $0c4d

	inc ix                                                          ; $0c4f
	dec a                                                           ; $0c51
	jr @loopFireIdx                                                 ; $0c52

@afterIncIX:
; If enemy already spawned from that fire, prevent it spawning there again
	ld a, (ix+$00)                                                  ; $0c54
	or a                                                            ; $0c57
	jr nz, @preventEnemySpawn                                       ; $0c58

; D = fires shown bitfield
	ld a, (wInGameFiresShown)                                       ; $0c5a
	ld d, a                                                         ; $0c5d

; Branch based on fire idx
	ld a, e                                                         ; $0c5e
	or a                                                            ; $0c5f
	jr z, @fire1                                                    ; $0c60

	dec a                                                           ; $0c62
	jr z, @fire2                                                    ; $0c63

; Check relevant bit for 3rd fire
	bit 2, d                                                        ; $0c65

@checkIfFireActive:
; Allow spawn if fire still exists
	jr z, @preventEnemySpawn                                        ; $0c67

	jr @allowEnemySpawn                                             ; $0c69

@fire1:
	bit 0, d                                                        ; $0c6b
	jr @checkIfFireActive                                           ; $0c6d

@fire2:
	bit 1, d                                                        ; $0c6f
	jr @checkIfFireActive                                           ; $0c71


; Unused - allow enemy spawn from sprite location
	push ix                                                         ; $0c73
	push de                                                         ; $0c75
	call HLequSpriteEAddr                                           ; $0c76
	push hl                                                         ; $0c79
	pop ix                                                          ; $0c7a

	ld h, (ix+$00)                                                  ; $0c7c
	ld l, (ix+$01)                                                  ; $0c7f

@allowEnemySpawn:
	ld a, $00                                                       ; $0c82
	pop de                                                          ; $0c84
	pop ix                                                          ; $0c85
	ret                                                             ; $0c87

@preventEnemySpawn:
	ld a, $01                                                       ; $0c88
	pop de                                                          ; $0c8a
	pop ix                                                          ; $0c8b
	ret                                                             ; $0c8d


IXequCurrLayoutElementsAddr:
	push bc                                                         ; $0c8e
	ld ix, Layout1Elements                                          ; $0c8f
	ld bc, Layout2Elements-Layout1Elements                          ; $0c93

; End once we have the layout addr
	ld a, (wInGameLayout)                                           ; $0c96
	dec a                                                           ; $0c99
	jr z, @end                                                      ; $0c9a

	add ix, bc                                                      ; $0c9c
	dec a                                                           ; $0c9e
	jr z, @end                                                      ; $0c9f

	add ix, bc                                                      ; $0ca1

@end:
	pop bc                                                          ; $0ca3
	ret                                                             ; $0ca4


; E - idx of enemy
; Returns A=1 if we should skip updating the enemy
CheckIfShouldSkipUpdatingEnemy:
	push de                                                         ; $0ca5

; HL = addr of enemy timer
	ld hl, wEnemyTimers                                             ; $0ca6
	ld d, $00                                                       ; $0ca9
	add hl, de                                                      ; $0cab
	add hl, de                                                      ; $0cac

; Inc timer, jumping if it matches 1st threshold value
	ld de, wEnemyTimerThreshold1                                    ; $0cad
	inc (hl)                                                        ; $0cb0
	ld a, (de)                                                      ; $0cb1
	cp (hl)                                                         ; $0cb2
	jr z, @clearTimer1UpdateEnemy                                   ; $0cb3

; Inc 2nd timer regardless, allow updating enemy if > wEnemyTimerThreshold2
	inc hl                                                          ; $0cb5
	inc (hl)                                                        ; $0cb6
	inc de                                                          ; $0cb7
	ld a, (de)                                                      ; $0cb8
	cp (hl)                                                         ; $0cb9
	jr z, @clearTimer2UpdateEnemy                                   ; $0cba
	jr c, @clearTimer2UpdateEnemy                                   ; $0cbc

; Else skip processing enemy
	pop de                                                          ; $0cbe
	ld a, $01                                                       ; $0cbf
	ret                                                             ; $0cc1

@clearTimer1UpdateEnemy:
; Reset timer, inc 2nd timer, and allow updating enemy
	ld (hl), $00                                                    ; $0cc2
	inc hl                                                          ; $0cc4
	inc (hl)                                                        ; $0cc5

@allowUpdatingEnemy:
	pop de                                                          ; $0cc6
	ld a, $00                                                       ; $0cc7
	ret                                                             ; $0cc9

@clearTimer2UpdateEnemy:
	ld (hl), $00                                                    ; $0cca
	jr @allowUpdatingEnemy                                          ; $0ccc


; E - enemy idx
; IX - wEnemyDirection for enemy
MapEnemysSpriteAndDirIntoPlayers:
	push de                                                         ; $0cce

; Preserve buttons status
	ld hl, wRemappedBtnsHeld                                        ; $0ccf
	ld de, wPreservedRemappedBtnsHeld                               ; $0cd2
	ld bc, $03                                                      ; $0cd5
	ldir                                                            ; $0cd8

; Preserve player sprites
	ld hl, wSprites                                                 ; $0cda
	ld de, wPreservedPlayerSprites                                  ; $0cdd
	ld bc, $08                                                      ; $0ce0
	ldir                                                            ; $0ce3

; Get and re-push enemy idx, then have HL equ its shadow sprite addr
	pop de                                                          ; $0ce5
	push de                                                         ; $0ce6
	call HLequSpriteEAddr                                           ; $0ce7

; Copy enemy spriite details into 1st slot
	ld de, wSprites                                                 ; $0cea
	ld bc, $04                                                      ; $0ced
	ldir                                                            ; $0cf0

; Copy enemy's direction into player's buttons held
	ld a, (ix+$00)                                                  ; $0cf2
	ld b, a                                                         ; $0cf5
	and $1e                                                         ; $0cf6
	pop de                                                          ; $0cf8
	ld (wRemappedBtnsHeld), a                                       ; $0cf9
	ret                                                             ; $0cfc


RestorePlayersSpritesAndBtnsStatus:
	push de                                                         ; $0cfd

	ld hl, wPreservedPlayerSprites                                  ; $0cfe
	ld de, wSprites                                                 ; $0d01
	ld bc, $08                                                      ; $0d04
	ldir                                                            ; $0d07

	ld hl, wPreservedRemappedBtnsHeld                               ; $0d09
	ld de, wRemappedBtnsHeld                                        ; $0d0c
	ld bc, $03                                                      ; $0d0f
	ldir                                                            ; $0d12

	pop de                                                          ; $0d14
	ret                                                             ; $0d15


; E - enemy idx
; IX - wEnemyDirection for enemy
ProcessEnemyMovement:
	push de                                                         ; $0d16

; HL points to unused struct var for enemy
	ld hl, wUnusedEnemyStructVars_c06e                              ; $0d17
	ld d, $00                                                       ; $0d1a
	add hl, de                                                      ; $0d1c
	push hl                                                         ; $0d1d

; --
; -- Attempt beeline
; --

; Jump if enemy's Y == player's Y
	call BequVertDirForEnemyToPlayer                                ; $0d1e
	ld a, c                                                         ; $0d21
	or a                                                            ; $0d22
	jr z, @sameYasPlayer                                            ; $0d23

; Jump if enemy's X != player's X
	call DequHorizDirForEnemyToPlayer                               ; $0d25
	ld a, e                                                         ; $0d28
	or a                                                            ; $0d29
	jr nz, @notAlignedWithPlayer                                    ; $0d2a

; Should be invalid (enemy on top of player), move vertically regardless
	call BequVertDirForEnemyToPlayer                                ; $0d2c
	jr +                                                            ; $0d2f

@sameYasPlayer:
	call DequHorizDirForEnemyToPlayer                               ; $0d31
	ld b, d                                                         ; $0d34

; C = desired direction, jump if not hit wall
+	ld c, b                                                         ; $0d35
	call ProcessPlayerDirInput                                      ; $0d36
	cp COLL_WALL                                                    ; $0d39
	jr nz, @enemyCanMoveIntoSpot                                    ; $0d3b

; --
; -- Attempt previously applied directions
; --

	call SetThatEnemyFailedThisDir                                  ; $0d3d

@notAlignedWithPlayer:
; Loop through dirs attempted
	ld hl, wEnemyDirsAttempted                                      ; $0d40
	ld d, $03                                                       ; $0d43

@nextDirAttempted:
	ld a, (hl)                                                      ; $0d45
	or a                                                            ; $0d46
	jr z, @toNextDirAttempted                                       ; $0d47

; If dir attempted, store in B and C
	ld b, a                                                         ; $0d49
	and $1f                                                         ; $0d4a
	ld c, a                                                         ; $0d4c

; Try to move in chosen direction, choosing a new one if we'd hit wall
	call ProcessPlayerDirInput                                      ; $0d4d
	cp COLL_WALL                                                    ; $0d50
	jr nz, @enemyCanMoveIntoSpot                                    ; $0d52

@toNextDirAttempted:
	inc hl                                                          ; $0d54
	dec d                                                           ; $0d55
	jr nz, @nextDirAttempted                                        ; $0d56

	jr @afterNoPrevFailedDirs                                       ; $0d58

@enemyCanMoveIntoSpot:
; Clear that this dir failed
	ld (hl), $00                                                    ; $0d5a

; Pop unused enemy struct 2 value
	pop hl                                                          ; $0d5c

@end:
; Set enemy direction, and clear struct 2 value
	ld (ix+$00), c                                                  ; $0d5d
	ld (hl), $00                                                    ; $0d60
	pop de                                                          ; $0d62
	ret                                                             ; $0d63

@afterNoPrevFailedDirs:
; --
; -- Attempt other dirs
; --

; B and C = current enemy direction
	pop hl                                                          ; $0d64
	ld a, (ix+$00)                                                  ; $0d65
	ld b, a                                                         ; $0d68
	and $1f                                                         ; $0d69
	ld c, a                                                         ; $0d6b

; Inc enemy struct 2 value. If 8+ (never happens as this func clears it at @end),
; Change direction to be that closest to player
	inc (hl)                                                        ; $0d6c
	ld a, (hl)                                                      ; $0d6d
	cp $08                                                          ; $0d6e
	jr c, +                                                         ; $0d70
	call CequEnemyClosestDirToPlayer                                ; $0d72

; Move in that current direction, and jump if no wall hit, otherwise say it failed
+	call ProcessPlayerDirInput                                      ; $0d75
	cp COLL_WALL                                                    ; $0d78
	jr nz, @enemyMovedIn                                            ; $0d7a

	call SetThatEnemyFailedThisDir                                  ; $0d7c

; Try horiz if just failed up, or REMAPPED_DOWN if below fails
	bit REMAPPED_UP, c                                              ; $0d7f
	jr nz, @tryHorizMovementThenVert                                ; $0d81

; If just failed horiz, try vert
	bit REMAPPED_RIGHT, c                                           ; $0d83
	jr nz, @tryVertMovementThenHoriz                                ; $0d85

	bit REMAPPED_LEFT, c                                            ; $0d87
	jr nz, @tryVertMovementThenHoriz                                ; $0d89

@tryHorizMovementThenVert:
; Try to move left (REMAPPED_LEFT)
	ld b, $08                                                       ; $0d8b
	ld c, $08                                                       ; $0d8d
	call ProcessPlayerDirInput                                      ; $0d8f
	cp $01                                                          ; $0d92
	jr nz, @enemyMovedIn                                            ; $0d94

; Try to move right (REMAPPED_RIGHT)
	ld b, $04                                                       ; $0d96
	ld c, $04                                                       ; $0d98
	call ProcessPlayerDirInput                                      ; $0d9a
	cp $01                                                          ; $0d9d
	jr nz, @enemyMovedIn                                            ; $0d9f

; Try to move up (REMAPPED_UP)
	ld b, $02                                                       ; $0da1
	ld c, $02                                                       ; $0da3
	call ProcessPlayerDirInput                                      ; $0da5
	cp $01                                                          ; $0da8
	jr nz, @enemyMovedIn                                            ; $0daa

; Try to move down (REMAPPED_DOWN)
	ld b, $10                                                       ; $0dac
	ld c, $10                                                       ; $0dae
	call ProcessPlayerDirInput                                      ; $0db0
	jr @enemyMovedIn                                                ; $0db3

@tryVertMovementThenHoriz:
; Try to move down (REMAPPED_DOWN)
	ld b, $10                                                       ; $0db5
	ld c, $10                                                       ; $0db7
	call ProcessPlayerDirInput                                      ; $0db9
	cp COLL_WALL                                                    ; $0dbc
	jr nz, @enemyMovedIn                                            ; $0dbe

; Try to move up (REMAPPED_UP)
	ld b, $02                                                       ; $0dc0
	ld c, $02                                                       ; $0dc2
	call ProcessPlayerDirInput                                      ; $0dc4
	cp COLL_WALL                                                    ; $0dc7
	jr nz, @enemyMovedIn                                            ; $0dc9

; Try to move right (REMAPPED_RIGHT)
	ld b, $04                                                       ; $0dcb
	ld c, $04                                                       ; $0dcd
	call ProcessPlayerDirInput                                      ; $0dcf
	cp COLL_WALL                                                    ; $0dd2
	jr nz, @enemyMovedIn                                            ; $0dd4

; Try to move left (REMAPPED_LEFT)
	ld b, $08                                                       ; $0dd6
	ld c, $08                                                       ; $0dd8
	call ProcessPlayerDirInput                                      ; $0dda

@enemyMovedIn:
	call ClearThatEnemyFailedThisDir                                ; $0ddd
	jp @end                                                         ; $0de0


CequEnemyClosestDirToPlayer:
; C = player Y-enemy Y
; E = player X-enemy X
	call BequVertDirForEnemyToPlayer                                ; $0de3
	call DequHorizDirForEnemyToPlayer                               ; $0de6

; If y diff >= x diff, C = horiz direction
; Else C = vert direction
	ld a, c                                                         ; $0de9
	cp e                                                            ; $0dea
	jr c, +                                                         ; $0deb
	ld b, d                                                         ; $0ded
+	ld c, b                                                         ; $0dee
	ret                                                             ; $0def


; Returns C = player's Y - enemy's Y
BequVertDirForEnemyToPlayer:
; B = object's Y
	ld a, (wSprites)                                                ; $0df0
	ld b, a                                                         ; $0df3

; C = player's Y - object's Y, jumping if player's is less
	ld a, (wPreservedPlayerSprites)                                 ; $0df4
	sub b                                                           ; $0df7
	ld c, a                                                         ; $0df8

	jr c, @enemyBelowPlayer                                         ; $0df9

; Return REMAPPED_DOWN
	ld b, $10                                                       ; $0dfb
	ret                                                             ; $0dfd

@enemyBelowPlayer:
; Return REMAPPED_UP
	ld b, $02                                                       ; $0dfe
	ret                                                             ; $0e00


; Returns E = player's X - enemy's X
DequHorizDirForEnemyToPlayer:
; D = object's X
	ld a, (wSprites+1)                                              ; $0e01
	ld d, a                                                         ; $0e04

; E = player's X - object's X, jumping if player's is less
	ld a, (wPreservedPlayerSprites+1)                               ; $0e05
	sub d                                                           ; $0e08
	ld e, a                                                         ; $0e09

	jr c, @enemyRightOfPlayer                                       ; $0e0a

; Return REMAPPED_RIGHT
	ld d, $04                                                       ; $0e0c
	ret                                                             ; $0e0e

@enemyRightOfPlayer:
; Return REMAPPED_LEFT
	ld d, $08                                                       ; $0e0f
	ret                                                             ; $0e11


; C - direction enemy moved in
SetThatEnemyFailedThisDir:
	push hl                                                         ; $0e12

; If we attempted this direction before, keep it in
	call CheckIfAttemptedDirIsNew                                   ; $0e13
	or a                                                            ; $0e16
	jr nz, +                                                        ; $0e17
	ld (hl), c                                                      ; $0e19

+	pop hl                                                          ; $0e1a
	ret                                                             ; $0e1b


; C - direction enemy moved in
ClearThatEnemyFailedThisDir:
	push hl                                                         ; $0e1c

; If we attempted this direction before, clear that it had failed
	call CheckIfAttemptedDirIsNew                                   ; $0e1d
	or a                                                            ; $0e20
	jr nz, +                                                        ; $0e21
	ld (hl), $00                                                    ; $0e23

+	pop hl                                                          ; $0e25
	ret                                                             ; $0e26


; C - direction enemy moved in
; Returns dir attempted in HL if a matching dir found
; Returns 1 if no matching dirs in dirs attempted
CheckIfAttemptedDirIsNew:
	ld hl, wEnemyDirsAttempted                                      ; $0e27
	ld d, $03                                                       ; $0e2a

@nextDir:
	ld a, (hl)                                                      ; $0e2c
	cp c                                                            ; $0e2d
	jr z, @matchedC                                                 ; $0e2e

	inc hl                                                          ; $0e30
	dec d                                                           ; $0e31
	jr nz, @nextDir                                                 ; $0e32

	ld a, $01                                                       ; $0e34
	ret                                                             ; $0e36

@matchedC:
	xor a                                                           ; $0e37
	ret                                                             ; $0e38


; IX - pointer to enemy direction
UpdateEnemySpriteTileAndCoords:
	push de                                                         ; $0e39

; Branch with C based on direction
	ld a, (ix+$00)                                                  ; $0e3a
	ld c, SPR_ENEMY_TAIL_TOP_LEFT                                   ; $0e3d
	bit 2, a                                                        ; $0e3f
	jr nz, @setTileAndCoords                                        ; $0e41

	ld c, SPR_ENEMY_TAIL_BOTTOM_RIGHT                               ; $0e43
	bit 3, a                                                        ; $0e45
	jr nz, @setTileAndCoords                                        ; $0e47

	ld c, SPR_ENEMY_TAIL_BOTTOM_LEFT                                ; $0e49
	bit 1, a                                                        ; $0e4b
	jr nz, @setTileAndCoords                                        ; $0e4d

	ld c, SPR_ENEMY_TAIL_TOP_RIGHT                                  ; $0e4f

@setTileAndCoords:
	call HLequSpriteEAddr                                           ; $0e51

; Update coords
	ld a, (wObjectY)                                                ; $0e54
	ld (hl), a                                                      ; $0e57
	inc hl                                                          ; $0e58

	ld a, (wObjectX)                                                ; $0e59
	ld (hl), a                                                      ; $0e5c
	inc hl                                                          ; $0e5d

; Set tile idx
	ld (hl), c                                                      ; $0e5e
	pop de                                                          ; $0e5f
	ret                                                             ; $0e60


HLequSpriteEAddr:
	ld hl, wSprites+8                                               ; $0e61
	ld d, $00                                                       ; $0e64
	add hl, de                                                      ; $0e66
	add hl, de                                                      ; $0e67
	add hl, de                                                      ; $0e68
	add hl, de                                                      ; $0e69
	ret                                                             ; $0e6a


AnimateFireHeads:
; Return if game in a stand-still
	ld a, (wInGameStandstillReason)                                 ; $0e6b
	or a                                                            ; $0e6e
	ret nz                                                          ; $0e6f

; Animate fires ever 8 frames, at different points in those 8
	ld a, (wVBlankInterruptCounter)                                 ; $0e70
	and $07                                                         ; $0e73
	cp $01                                                          ; $0e75
	jr z, @processFire1                                             ; $0e77

	cp $05                                                          ; $0e79
	jr z, @processFire2                                             ; $0e7b

	cp $07                                                          ; $0e7d
	ret nz                                                          ; $0e7f

; Process fire 3
	ld a, (wInGameFiresShown)                                       ; $0e80
	bit 2, a                                                        ; $0e83
	ret z                                                           ; $0e85

	ld iy, Layout1Elements+4                                        ; $0e86
	jr @afterFireChosen                                             ; $0e8a

@processFire2:
	ld a, (wInGameFiresShown)                                       ; $0e8c
	bit 1, a                                                        ; $0e8f
	ret z                                                           ; $0e91

	ld iy, Layout1Elements+2                                        ; $0e92
	jr @afterFireChosen                                             ; $0e96

@processFire1:
	ld a, (wInGameFiresShown)                                       ; $0e98
	bit 0, a                                                        ; $0e9b
	ret z                                                           ; $0e9d

	ld iy, Layout1Elements                                          ; $0e9e

@afterFireChosen:
	ld de, Layout2Elements-Layout1Elements                          ; $0ea2

; If layout 1, retain IY
	ld a, (wInGameLayout)                                           ; $0ea5
	cp $01                                                          ; $0ea8
	jr z, @afterLayoutAdjust                                        ; $0eaa

; Else IY = Layout2Elements, if layout 2
	add iy, de                                                      ; $0eac
	cp $02                                                          ; $0eae
	jr z, @afterLayoutAdjust                                        ; $0eb0

; Else IY = Layout3Elements, if layout 3
	add iy, de                                                      ; $0eb2

@afterLayoutAdjust:
; IY = address of layout+fire
	ld e, (iy+$00)                                                  ; $0eb4
	ld d, (iy+$01)                                                  ; $0eb7
	push de                                                         ; $0eba
	pop iy                                                          ; $0ebb

; Use a different fire head to the one currently displayed
	ld a, (iy-$20)                                                  ; $0ebd
	cp TILE_FIRE_HEAD_LEFT_1                                        ; $0ec0
	jr nz, @isFireHead2                                             ; $0ec2

	ld (iy-$20), TILE_FIRE_HEAD_LEFT_2                              ; $0ec4
	ld (iy-$1f), TILE_FIRE_HEAD_RIGHT_2                             ; $0ec8
	ret                                                             ; $0ecc

@isFireHead2:
	ld (iy-$20), TILE_FIRE_HEAD_LEFT_1                              ; $0ecd
	ld (iy-$1f), TILE_FIRE_HEAD_RIGHT_1                             ; $0ed1
	ret                                                             ; $0ed5


HandleTimer6Func_DeathOrClear:
; Return unless frozen for a negative reason
	ld a, (wInGameStandstillReason)                                 ; $0ed6
	cp $02                                                          ; $0ed9
	ret c                                                           ; $0edb

; Return if timer not 0 yet
	ld a, (wGenericTimers+6)                                        ; $0edc
	or a                                                            ; $0edf
	ret nz                                                          ; $0ee0

; Jump if no jump func, otherwise jump to it
	ld hl, (wTimer6JumpAddr)                                        ; $0ee1
	ld a, h                                                         ; $0ee4
	or l                                                            ; $0ee5
	jr z, @noJumpFunc                                               ; $0ee6

	ld bc, $00                                                      ; $0ee8
	ld (wTimer6JumpAddr), bc                                        ; $0eeb
	jp (hl)                                                         ; $0eef

@noJumpFunc:
; Jump if frozen due to 0 fires left
	ld a, (wInGameStandstillReason)                                 ; $0ef0
	cp $04                                                          ; $0ef3
	jp z, HandleRoundClear                                          ; $0ef5

; Play death sound, then save fires shown
	ld a, SND_DIED_OTHER                                            ; $0ef8
	ld (wSoundToPlay), a                                            ; $0efa

	ld hl, wInGameFiresShown                                        ; $0efd
	ld de, wOrigFiresShown                                          ; $0f00
	ld bc, $03                                                      ; $0f03
	ldir                                                            ; $0f06

; Save the current round and its digits
	ld a, (wRound)                                                  ; $0f08
	ld (wOrigRound), a                                              ; $0f0b

	ld hl, (wRoundDigits)                                           ; $0f0e
	ld (wOrigRoundDigits), hl                                       ; $0f11

; Lives left is what's displayed-1, jump if now 0
	ld a, (wDisplayedLivesLeft)                                     ; $0f14
	dec a                                                           ; $0f17
	ld (wLivesLeft), a                                              ; $0f18
	or a                                                            ; $0f1b
	jr z, JumpFunc_WaitWith0Lives                                   ; $0f1c

	ld (wDisplayedLivesLeft), a                                     ; $0f1e

; Restore num special items loaded
	ld a, (wOrigSpecialItemsLoaded)                                 ; $0f21
	ld (wNumSpecialItemsLoaded), a                                  ; $0f24

; Restart round after 1 second
	ld a, $3c                                                       ; $0f27
	ld (wGenericTimers+6), a                                        ; $0f29

	ld hl, JumpFunc_RestartRound                                    ; $0f2c
	ld (wTimer6JumpAddr), hl                                        ; $0f2f
	ret                                                             ; $0f32


JumpFunc_RestartRound:
; Load round and update status, the unfreeze everything
	call LoadRoundAfterRestart                                      ; $0f33
	call UpdateLivesLeftCurrRoundAndScore                           ; $0f36

	xor a                                                           ; $0f39
	ld (wInGameStandstillReason), a                                 ; $0f3a
	ret                                                             ; $0f3d


JumpFunc_WaitWith0Lives:
; Handle game over after 1 second
	ld a, $3c                                                       ; $0f3e
	ld (wGenericTimers+6), a                                        ; $0f40

	ld hl, JumpFunc_GameOver                                        ; $0f43
	ld (wTimer6JumpAddr), hl                                        ; $0f46
	ret                                                             ; $0f49


JumpFunc_GameOver:
; Clear layout, and unfreeze everything
	call ClearInGameLayoutExceptStatus                              ; $0f4a
	xor a                                                           ; $0f4d
	ld (wInGameStandstillReason), a                                 ; $0f4e

; Set state to GS_TITLE_SCREEN
	inc a                                                           ; $0f51
	ld (wGameState), a                                              ; $0f52
	ret                                                             ; $0f55


HandleRoundClear:
; Play looping victory sound
	ld a, SND_ROUND_CLEAR                                           ; $0f56
	ld (wSoundToPlay), a                                            ; $0f58

RoundClearAddInBonusPts:
; Subtract 100 bonus pts, storing if now 0
	ld b, $01                                                       ; $0f5b
	call SubtractBHundredsFromBonusScore                            ; $0f5d
	ld (wDoneAddingBonusPtsToCurrScore), a                          ; $0f60

; Update layout, and add the 100 pts to curr score
	call UpdateCurrScoreDigitsLayout                                ; $0f63
	ld bc, $0100                                                    ; $0f66
	ld d, $00                                                       ; $0f69
	call AddB100sC1ksD10ksToCurrScore                               ; $0f6b

; Handle post-score increase funcs
	call CheckIfNewTopScore                                         ; $0f6e
	call UpdateShadowScoreValueLayout                               ; $0f71
	call IncLivesIfApplicable                                       ; $0f74

; Handle next 100 pts in 7 frames
	ld a, $07                                                       ; $0f77
	ld (wGenericTimers+6), a                                        ; $0f79

	ld hl, JumpFunc_CheckIfBonusPtsToAdd                            ; $0f7c
	ld (wTimer6JumpAddr), hl                                        ; $0f7f
	ret                                                             ; $0f82


JumpFunc_CheckIfBonusPtsToAdd:
; Keep adding in bonus pts until it's 0
	ld a, (wDoneAddingBonusPtsToCurrScore)                          ; $0f83
	or a                                                            ; $0f86
	jr z, RoundClearAddInBonusPts                                   ; $0f87

; Clear music, inc round and load its layout
	ld a, SND_MUTE                                                  ; $0f89
	ld (wSoundToPlay), a                                            ; $0f8b
	call IncRoundAndItsLayout                                       ; $0f8e

; After half a second, load that next round
	ld a, $1e                                                       ; $0f91
	ld (wGenericTimers+6), a                                        ; $0f93

	ld hl, JumpFunc_LoadNextRound                                   ; $0f96
	ld (wTimer6JumpAddr), hl                                        ; $0f99
	ret                                                             ; $0f9c


JumpFunc_LoadNextRound:
; Update lives left with what's displayed
	ld hl, wLivesLeft                                               ; $0f9d
	ld a, (wDisplayedLivesLeft)                                     ; $0fa0
	ld (hl), a                                                      ; $0fa3

; Update score layout, load next round, then unfreeze everything
	call UpdateShadowScoreValueLayout                               ; $0fa4
	call LoadNextRoundLayout                                        ; $0fa7

	xor a                                                           ; $0faa
	ld (wInGameStandstillReason), a                                 ; $0fab
	ret                                                             ; $0fae


ClearInGameLayoutExceptStatus:
; Clear $11 rows
	ld a, $11                                                       ; $0faf
	ld hl, wNameTable                                               ; $0fb1

@nextRow:
; Clear $18 bytes in row
	ld d, h                                                         ; $0fb4
	ld e, l                                                         ; $0fb5
	inc de                                                          ; $0fb6
	ld bc, $17                                                      ; $0fb7
	ld (hl), TILE_BLANK                                             ; $0fba
	ldir                                                            ; $0fbc

; To next row
	ld bc, SCREEN_COLS-$17                                          ; $0fbe
	add hl, bc                                                      ; $0fc1

	dec a                                                           ; $0fc2
	jr nz, @nextRow                                                 ; $0fc3

; Clear all bytes in the remaining rows
	ld hl, wNameTable+$220                                          ; $0fc5
	ld de, wNameTable+$221                                          ; $0fc8
	ld bc, wSprites-(wNameTable+$220)-1                             ; $0fcb
	ld (hl), TILE_BLANK                                             ; $0fce
	ldir                                                            ; $0fd0

; Clear all sprites
	ld hl, wSprites                                                 ; $0fd2
	ld de, wSprites+1                                               ; $0fd5
	ld bc, 5*4-1                                                    ; $0fd8
	ld (hl), $00                                                    ; $0fdb
	ldir                                                            ; $0fdd
	ret                                                             ; $0fdf


UpdateShadowScoreRelatedLayout:
; TOP- with below to be TOP-SCORE
	ld hl, Layout_Top                                               ; $0fe0
	ld de, wNameTable+$38                                           ; $0fe3
	ld bc, Layout_Top@end-Layout_Top                                ; $0fe6
	ldir                                                            ; $0fe9

; Layout_TopScoreText
	ld de, wNameTable+$59                                           ; $0feb
	ld bc, Layout_TopScoreText@end-Layout_TopScoreText              ; $0fee
	ldir                                                            ; $0ff1

; Layout_CurrScoreText
	ld de, wNameTable+$d9                                           ; $0ff3
	ld bc, Layout_CurrScoreText@end-Layout_CurrScoreText            ; $0ff6
	ldir                                                            ; $0ff9

UpdateShadowScoreValueLayout:
	ld hl, wTopScoreLayout                                          ; $0ffb
	ld de, wNameTable+$78                                           ; $0ffe
	ld bc, _sizeof_wTopScoreLayout                                  ; $1001
	ldir                                                            ; $1004

; wCurrScoreLayout
	ld de, wNameTable+$f8                                           ; $1006
	ld bc, _sizeof_wCurrScoreLayout                                 ; $1009
	ldir                                                            ; $100c
	ret                                                             ; $100e


Layout_Top:
	.asc "TOP-"
@end:

Layout_TopScoreText:
	.asc "SCORE"	
@end:

Layout_CurrScoreText:
	.asc "SCORE"
@end:


; Displays stuff on the bottom-right of the screen
DisplayInGameStatus:
; Display "ROUND"
	ld hl, Layout_RoundText                                         ; $101d
	ld de, wNameTable+$1f9                                          ; $1020
	ld bc, Layout_RoundText@end-Layout_RoundText                    ; $1023
	ldir                                                            ; $1026

; Display 2 green tiles around curr score val
	ld a, TILE_GREEN                                                ; $1028
	ld (wNameTable+$277), a                                         ; $102a
	ld (wNameTable+$27e), a                                         ; $102d

; Display 8 green tiles below the above
	ld hl, wNameTable+$297                                          ; $1030
	ld de, wNameTable+$298                                          ; $1033
	ld bc, $07                                                      ; $1036
	ld (hl), a                                                      ; $1039
	ldir                                                            ; $103a

; Display 2 hearts around curr round
	ld a, TILE_HEART                                                ; $103c
	ld (wNameTable+$21a), a                                         ; $103e
	ld (wNameTable+$21d), a                                         ; $1041

UpdateLivesLeftCurrRoundAndScore:
	ld ix, Metatile_Lives                                           ; $1044
	ld iy, wNameTable+$2b7                                          ; $1048

; Pre-dec as 1 life left means 0 displayed lives 'character'
	ld a, (wDisplayedLivesLeft)                                     ; $104c
	ld b, a                                                         ; $104f

@nextLife:
	dec b                                                           ; $1050
	jr z, @afterLives                                               ; $1051

; Load metatile, then next life is 2 tiles ahead
	call LoadMetatile                                               ; $1053
	inc iy                                                          ; $1056
	inc iy                                                          ; $1058
	jr @nextLife                                                    ; $105a

@afterLives:
; Display curr round
	ld a, (wRoundDigits)                                            ; $105c
	ld (wNameTable+$21b), a                                         ; $105f
	ld a, (wRoundDigits+1)                                          ; $1062
	ld (wNameTable+$21c), a                                         ; $1065

UpdateCurrScoreDigitsLayout:
	ld hl, wBonusScoreLayout                                        ; $1068
	ld de, wNameTable+$278                                          ; $106b
	ld bc, _sizeof_wBonusScoreLayout                                ; $106e
	ldir                                                            ; $1071
	ret                                                             ; $1073


Layout_RoundText:
	.asc "ROUND"
@end:


Metatile_Lives:
	.db $1b, $1c, $1d, $1e
	

LoadTitleScreenTitleAndCopyright:
	ld ix, Metatiles_Guzzler                                        ; $107d
	ld iy, wNameTable+$85                                           ; $1081
	ld b, (Metatiles_Guzzler@end-Metatiles_Guzzler)/4               ; $1085

@nextMetatile:
	call LoadMetatile                                               ; $1087

; Dest is 2 tiles ahead, src += to next 4 bytes
	inc iy                                                          ; $108a
	inc iy                                                          ; $108c

	inc ix                                                          ; $108e
	inc ix                                                          ; $1090
	inc ix                                                          ; $1092
	inc ix                                                          ; $1094

	dec b                                                           ; $1096
	jr nz, @nextMetatile                                            ; $1097

; Load copyright text
	ld hl, Layout_Copyright                                         ; $1099
	ld de, wNameTable+$285                                          ; $109c
	ld bc, Layout_Copyright@end-Layout_Copyright                    ; $109f
	ldir                                                            ; $10a2

; Load 'TM'
	ld a, $59                                                       ; $10a4
	ld (wNameTable+$b3), a                                          ; $10a6
	ld a, $5a                                                       ; $10a9
	ld (wNameTable+$b4), a                                          ; $10ab
	ret                                                             ; $10ae


Metatiles_Guzzler:
	.db $1f, $20, $21, $22
	.db $23, $24, $25, $26
	.db $27, $28, $29, $2a
	.db $27, $28, $29, $2a
	.db $2b, $2c, $2d, $2e
	.db $2f, $30, $31, $32
	.db $33, $34, $35, $36
@end:


Layout_Copyright:
	.asc "@ 1983 TSUKUDA"
@end:


_LoadLevelOptText:
	ld de, wNameTable+$186                                          ; $10d9
	ld bc, Layout_Level1@end-Layout_Level1                          ; $10dc
	ldir                                                            ; $10df

; Layout_Level2
	ld de, wNameTable+$1c6                                          ; $10e1
	ld bc, Layout_Level2@end-Layout_Level2                          ; $10e4
	ldir                                                            ; $10e7
	ret                                                             ; $10e9


Load2LevelsOptText:
	ld hl, Layout_Level1                                            ; $10ea
	jr _LoadLevelOptText                                            ; $10ed


Layout_Level1:
	.asc "LEVEL 1  - S1"
@end:

Layout_Level2:
	.asc "LEVEL 2  - S2"
@end:


IncRoundAndItsLayout:
; Inc current round
	ld a, (wRound)                                                  ; $1109
	inc a                                                           ; $110c
	ld (wRound), a                                                  ; $110d

; Check 10s digit, if blank, fill it with 0 (it is digits + layout)
	ld ix, wRoundDigits                                             ; $1110
	ld a, (ix+$00)                                                  ; $1114
	cp TILE_BLANK                                                   ; $1117
	jr nz, +                                                        ; $1119
	ld (ix+$00), $00                                                ; $111b

; Inc 1s part of layout, jump if it hadn't reached 10
+	inc (ix+$01)                                                    ; $111f
	ld a, (ix+$01)                                                  ; $1122
	cp 10                                                           ; $1125
	jr nz, @afterIncDigits                                          ; $1127

; If it has, reset 1s, and inc 10s, jump if we're not at 100
	ld (ix+$01), $00                                                ; $1129
	inc (ix+$00)                                                    ; $112d

	ld a, (ix+$00)                                                  ; $1130
	cp 10                                                           ; $1133
	jr nz, @afterIncDigits                                          ; $1135

; Set 10s to 0, and round to 1
	ld (ix+$00), $00                                                ; $1137
	ld a, $01                                                       ; $113b
	ld (ix+$01), a                                                  ; $113d
	ld (wRound), a                                                  ; $1140

@afterIncDigits:
; Save the round and its digits
	ld a, (wRound)                                                  ; $1143
	ld hl, (wRoundDigits)                                           ; $1146

	ld (wOrigRound), a                                              ; $1149
	ld (wOrigRoundDigits), hl                                       ; $114c

PrefixRoundWithBlankTile:
; If 10s digit of round == 0, fill it with a blank instead
	ld a, (wRoundDigits)                                            ; $114f
	or a                                                            ; $1152
	ret nz                                                          ; $1153

	ld a, TILE_BLANK                                                ; $1154
	ld (wRoundDigits), a                                            ; $1156
	ret                                                             ; $1159


AddB100sC1ksD10ksToCurrScore:
	ld ix, wCurrScoreDigits                                         ; $115a
	ld iy, wCurrScoreLayout                                         ; $115e
	push bc                                                         ; $1162
	push de                                                         ; $1163

; Add hundreds param to score hundreds, jumping if we didn't reach 16
	ld a, (ix+$03)                                                  ; $1164
	add a, b                                                        ; $1167
	bit 4, a                                                        ; $1168
	jr z, @afterAdding100s                                          ; $116a

; If we did, inc thousands, then A = hundreds-16+6
	inc (ix+$02)                                                    ; $116c
	res 4, a                                                        ; $116f
	add a, $06                                                      ; $1171

@afterAdding100s:
; If hundreds >= 10, sub it, and +1 to thousands
	cp 10                                                           ; $1173
	jr c, +                                                         ; $1175

	sub 10                                                          ; $1177
	inc (ix+$02)                                                    ; $1179

+	ld (ix+$03), a                                                  ; $117c

; Add thousands param to score thousands, jumping if we didn't reach 16
	ld a, (ix+$02)                                                  ; $117f
	add a, c                                                        ; $1182
	bit 4, a                                                        ; $1183
	jr z, @afterChecking1000s                                       ; $1185

; If we did, inc 10ks, then A = thousands-16+6
	inc (ix+$01)                                                    ; $1187
	res 4, a                                                        ; $118a
	add a, $06                                                      ; $118c

@afterChecking1000s:
; If thousands >= 10, sub it, and +1 to 10ks
	cp 10                                                           ; $118e
	jr c, +                                                         ; $1190

	sub 10                                                          ; $1192
	inc (ix+$01)                                                    ; $1194

+	ld (ix+$02), a                                                  ; $1197

; Add 10ks param to score 10ks. If >= 10, sub 10, then inc 100ks
	ld a, (ix+$01)                                                  ; $119a
	add a, d                                                        ; $119d
	cp 10                                                           ; $119e
	jr c, +                                                         ; $11a0

	sub 10                                                          ; $11a2
	inc (ix+$00)                                                    ; $11a4

+	ld (ix+$01), a                                                  ; $11a7

; Once 100ks digit reaches 10..., 
	ld a, (ix+$00)                                                  ; $11aa
	cp 10                                                           ; $11ad
	jr nz, @afterCheckiing10ks                                      ; $11af

; Reset the score to have 100s, 10s and 1s
	ld (ix+$00), $00                                                ; $11b1
	ld (ix+$01), $00                                                ; $11b5
	ld (ix+$02), $00                                                ; $11b9

@afterCheckiing10ks:
; HL points to score struct, DE points to layout, copy HL to DE
	push ix                                                         ; $11bd
	pop hl                                                          ; $11bf
	push iy                                                         ; $11c0
	pop de                                                          ; $11c2
	ld bc, _sizeof_wCurrScoreDigits                                 ; $11c3
	ldir                                                            ; $11c6

; IX points to layout, add a prefix on the 10s if 0
	push iy                                                         ; $11c8
	pop ix                                                          ; $11ca
	call PrefixScoreWithBlankTiles                                  ; $11cc

	pop de                                                          ; $11cf
	pop bc                                                          ; $11d0
	ret                                                             ; $11d1


CheckIfNewTopScore:
	ld ix, wCurrScoreDigits                                         ; $11d2
	ld hl, wCurrScoreDigits                                         ; $11d6
	ld iy, wTopScoreDigits                                          ; $11d9

; Loop through the digits, except the 10s and 1s which don't get updated
	ld b, $04                                                       ; $11dd

@nextDigit:
; Compare top score digit against the curr score, returning if top > curr
	ld a, (iy+$00)                                                  ; $11df
	cp (ix+$00)                                                     ; $11e2
	jr z, @toNextDigit                                              ; $11e5

	jr c, @newTopScore                                              ; $11e7

	ret                                                             ; $11e9

@toNextDigit:
	inc ix                                                          ; $11ea
	inc iy                                                          ; $11ec

	dec b                                                           ; $11ee
	jr nz, @nextDigit                                               ; $11ef

	ret                                                             ; $11f1

@newTopScore:
; Copy wCurrScoreDigits to wTopScoreDigits
	ld de, wTopScoreDigits                                          ; $11f2
	ld bc, $06                                                      ; $11f5
	ldir                                                            ; $11f8

; Copy the digits to the layout too
	ld hl, wTopScoreDigits                                          ; $11fa
	ld de, wTopScoreLayout                                          ; $11fd
	ld bc, $06                                                      ; $1200
	ldir                                                            ; $1203

; Finally prefix with blank tiles
	ld ix, wTopScoreLayout                                          ; $1205
	call PrefixScoreWithBlankTiles                                  ; $1209
	ret                                                             ; $120c


; Returns A = 1 if our score is 0
SubtractBHundredsFromBonusScore:
; Subtract hundreds if our hundreds digit >= B
	ld ix, wBonusScoreDigits                                        ; $120d
	ld a, (ix+$03)                                                  ; $1211
	cp b                                                            ; $1214
	jr z, @hundredsIsSmall                                          ; $1215

	jr nc, @subtractHundreds                                        ; $1217

@hundredsIsSmall:
; If our 100ks, 10ks, and thousands are all 0...
	ld a, (ix+$00)                                                  ; $1219
	add a, (ix+$01)                                                 ; $121c
	add a, (ix+$02)                                                 ; $121f
	or a                                                            ; $1222
	jr nz, @subtractHundreds                                        ; $1223

; Set our hundreds to 0, then update layout
	ld (ix+$03), $00                                                ; $1225
	ld a, $01                                                       ; $1229
	jr @setLayout                                                   ; $122b

@subtractHundreds:
; Subtract B from hundreds, adjusting thousands if carry set
	ld a, (ix+$03)                                                  ; $122d
	sub b                                                           ; $1230
	jr nc, +                                                        ; $1231

	dec (ix+$02)                                                    ; $1233
	add a, 10                                                       ; $1236

+	ld (ix+$03), a                                                  ; $1238

; Jump if we haven't got thousands below 0
	ld a, (ix+$02)                                                  ; $123b
	cp $ff                                                          ; $123e
	jr nz, @afterHighDigitsCheck                                    ; $1240

; Else dec 10ks, and set thousands to 9
	dec (ix+$01)                                                    ; $1242
	ld (ix+$02), $09                                                ; $1245

; Jump if we haven't got 10ks below 0
	ld a, (ix+$01)                                                  ; $1249
	cp $ff                                                          ; $124c
	jr nz, @afterHighDigitsCheck                                    ; $124e

; Else dec 100ks, and set 10ks to 9
	dec (ix+$00)                                                    ; $1250
	ld (ix+$01), $09                                                ; $1253

@afterHighDigitsCheck:
	xor a                                                           ; $1257

@setLayout:
; Copy digits to layout
	ld hl, wBonusScoreDigits                                        ; $1258
	ld de, wBonusScoreLayout                                        ; $125b
	ld bc, $06                                                      ; $125e
	ldir                                                            ; $1261

; Then prefix unused high digits with blank tiles
	ld ix, wBonusScoreLayout                                        ; $1263
	call PrefixScoreWithBlankTiles                                  ; $1267
	ret                                                             ; $126a


; IX - address of score struct
PrefixScoreWithBlankTiles:
	push af                                                         ; $126b

; Loop through all but last score value
	ld b, $05                                                       ; $126c

@nextDigit:
; We're done once we encounter a non-0 value
	ld a, (ix+$00)                                                  ; $126e
	or a                                                            ; $1271
	jr nz, @done                                                    ; $1272

; Otherwise fill with a blank tile
	ld (ix+$00), TILE_BLANK                                         ; $1274
	inc ix                                                          ; $1278
	dec b                                                           ; $127a
	jr nz, @nextDigit                                               ; $127b

@done:
	pop af                                                          ; $127d
	ret                                                             ; $127e


; IX - src addr of 4 bytes
; IY - dest addr of top-left tile
LoadMetatile:
; Copy metatile as if 2 sprites
; 0 2
; 1 3
	ld a, (ix+$00)                                                  ; $127f
	ld (iy+$00), a                                                  ; $1282
	ld a, (ix+$01)                                                  ; $1285
	ld (iy+$20), a                                                  ; $1288
	ld a, (ix+$02)                                                  ; $128b
	ld (iy+$01), a                                                  ; $128e
	ld a, (ix+$03)                                                  ; $1291
	ld (iy+$21), a                                                  ; $1294
	ret                                                             ; $1297


; Unused - this would allow 2 extra bytes to create a 3x2 metatile
	ld a, (ix+$04)                                                  ; $1298
	ld (iy+$02), a                                                  ; $129b
	ld a, (ix+$05)                                                  ; $129e
	ld (iy+$22), a                                                  ; $12a1
	jr LoadMetatile                                                 ; $12a4


; IX - src of metatile details
; IY - dest of fire metatile
DisplayFireMetatile:
; Copy Layout_FireTop to the 2 tiles above the fire
	ld a, (ix-$02)                                                  ; $12a6
	ld (iy-$20), a                                                  ; $12a9
	ld a, (ix-$01)                                                  ; $12ac
	ld (iy-$1f), a                                                  ; $12af

	jr LoadMetatile                                                 ; $12b2


SetLayoutAndDrawIt:
; B = the tile idx used to draw walls
	ld hl, wWallsTileIdx                                            ; $12b4
	ld a, (hl)                                                      ; $12b7
	ld b, a                                                         ; $12b8

; Sub 3 from round until we get 1-3 (layout idx)
	ld a, (wRound)                                                  ; $12b9

@nextSub:
	cp $04                                                          ; $12bc
	jr c, @setLayoutAndDrawWalls                                    ; $12be

	sub $03                                                         ; $12c0
	jr @nextSub                                                     ; $12c2

@setLayoutAndDrawWalls:
; Set layout, then draw layout-specific tiles, then surrounding walls
	ld (wInGameLayout), a                                           ; $12c4

	call DrawLayout1                                                ; $12c7
	call DrawLayout2                                                ; $12ca
	call DrawLayout3                                                ; $12cd

	call DrawInGameSurroundingWall                                  ; $12d0
	ret                                                             ; $12d3


; A - layout idx
; B - wall tile idx to set
DrawLayout1:
; Return if not layout 1
	cp $01                                                          ; $12d4
	ret nz                                                          ; $12d6

; Draw walls
	ld hl, wNameTable+$84                                           ; $12d7
	ld a, $07                                                       ; $12da
	call MemSetHoriz                                                ; $12dc

	ld hl, wNameTable+$8d                                           ; $12df
	ld a, $04                                                       ; $12e2
	call MemSetHoriz                                                ; $12e4

	ld hl, wNameTable+$93                                           ; $12e7
	ld a, $07                                                       ; $12ea
	call MemSetVert                                                 ; $12ec

	ld hl, wNameTable+$e4                                           ; $12ef
	ld a, $04                                                       ; $12f2
	call MemSetVert                                                 ; $12f4

	ld hl, wNameTable+$e7                                           ; $12f7
	ld a, $04                                                       ; $12fa
	call MemSetVert                                                 ; $12fc

	ld hl, wNameTable+$ea                                           ; $12ff
	ld a, $04                                                       ; $1302
	call MemSetVert                                                 ; $1304

	ld hl, wNameTable+$ed                                           ; $1307
	ld a, $04                                                       ; $130a
	call MemSetVert                                                 ; $130c

	ld hl, wNameTable+$f0                                           ; $130f
	ld a, $04                                                       ; $1312
	call MemSetVert                                                 ; $1314

	ld hl, wNameTable+$148                                          ; $1317
	ld a, $02                                                       ; $131a
	call MemSetHoriz                                                ; $131c

	ld hl, wNameTable+$14e                                          ; $131f
	ld a, $02                                                       ; $1322
	call MemSetHoriz                                                ; $1324

	ld hl, wNameTable+$1a4                                          ; $1327
	ld a, $07                                                       ; $132a
	call MemSetVert                                                 ; $132c

	ld hl, wNameTable+$1a7                                          ; $132f
	ld a, $04                                                       ; $1332
	call MemSetHoriz                                                ; $1334

	ld hl, wNameTable+$1ad                                          ; $1337
	ld a, $04                                                       ; $133a
	call MemSetHoriz                                                ; $133c

	ld hl, wNameTable+$1b3                                          ; $133f
	ld a, $07                                                       ; $1342
	call MemSetVert                                                 ; $1344

	ld hl, wNameTable+$1c7                                          ; $1347
	ld a, $03                                                       ; $134a
	call MemSetVert                                                 ; $134c

	ld hl, wNameTable+$1d0                                          ; $134f
	ld a, $03                                                       ; $1352
	call MemSetVert                                                 ; $1354

	ld hl, wNameTable+$208                                          ; $1357
	ld a, $03                                                       ; $135a
	call MemSetHoriz                                                ; $135c

	ld hl, wNameTable+$20d                                          ; $135f
	ld a, $03                                                       ; $1362
	call MemSetHoriz                                                ; $1364

	ld hl, wNameTable+$267                                          ; $1367
	ld a, $0a                                                       ; $136a
	call MemSetHoriz                                                ; $136c

; Draw elements, then return the current layout idx for next layout check
	ld hl, Layout1Elements                                          ; $136f
	call DrawLayoutElements                                         ; $1372

	ld a, $01                                                       ; $1375
	ret                                                             ; $1377


; A - layout idx
; B - wall tile idx to set
DrawLayout2:
; Return if not layout 2
	cp $02                                                          ; $1378
	ret nz                                                          ; $137a

; Draw walls
	ld hl, wNameTable+$c2                                           ; $137b
	ld a, $12                                                       ; $137e
	call MemSetHoriz                                                ; $1380

	ld hl, wNameTable+$e7                                           ; $1383
	ld a, $08                                                       ; $1386
	call MemSetVert                                                 ; $1388

	ld hl, wNameTable+$f3                                           ; $138b
	ld a, $06                                                       ; $138e
	call MemSetVert                                                 ; $1390

	ld hl, wNameTable+$12a                                          ; $1393
	ld a, $07                                                       ; $1396
	call MemSetHoriz                                                ; $1398

	ld hl, wNameTable+$14a                                          ; $139b
	ld a, $02                                                       ; $139e
	call MemSetVert                                                 ; $13a0

	ld hl, wNameTable+$150                                          ; $13a3
	ld a, $07                                                       ; $13a6
	call MemSetVert                                                 ; $13a8

	ld hl, wNameTable+$164                                          ; $13ab
	ld a, $07                                                       ; $13ae
	call MemSetVert                                                 ; $13b0

	ld hl, wNameTable+$18d                                          ; $13b3
	ld a, $03                                                       ; $13b6
	call MemSetVert                                                 ; $13b8

	ld hl, wNameTable+$1c8                                          ; $13bb
	ld a, $05                                                       ; $13be
	call MemSetHoriz                                                ; $13c0

	ld hl, wNameTable+$225                                          ; $13c3
	ld a, $11                                                       ; $13c6
	call MemSetHoriz                                                ; $13c8

; Draw elements, then return the current layout idx for next layout check
	ld hl, Layout2Elements                                          ; $13cb
	call DrawLayoutElements                                         ; $13ce

	ld a, $02                                                       ; $13d1
	ret                                                             ; $13d3


; A - layout idx
; B - wall tile idx to set
DrawLayout3:
; Return if not layout 3
	cp $03                                                          ; $13d4
	ret nz                                                          ; $13d6

; Draw walls
	ld hl, wNameTable+$e2                                           ; $13d7
	ld a, $06                                                       ; $13da
	call MemSetHoriz                                                ; $13dc

	ld hl, wNameTable+$182                                          ; $13df
	ld a, $06                                                       ; $13e2
	call MemSetHoriz                                                ; $13e4

	ld hl, wNameTable+$222                                          ; $13e7
	ld a, $06                                                       ; $13ea
	call MemSetHoriz                                                ; $13ec

; Draw elements, then return the current layout idx for next layout check (not needed here)
	ld hl, Layout3Elements                                          ; $13ef
	call DrawLayoutElements                                         ; $13f2

	ld a, $03                                                       ; $13f5
	ret                                                             ; $13f7


; B - tile idx to set
DrawInGameSurroundingWall:
	ld hl, wNameTable+$21                                           ; $13f8
	ld a, $16                                                       ; $13fb
	call MemSetHoriz                                                ; $13fd

	ld hl, wNameTable+$41                                           ; $1400
	ld a, $15                                                       ; $1403
	call MemSetVert                                                 ; $1405

	ld hl, wNameTable+$56                                           ; $1408
	ld a, $15                                                       ; $140b
	call MemSetVert                                                 ; $140d

	ld hl, wNameTable+$2c2                                          ; $1410
	ld a, $14                                                       ; $1413
	call MemSetHoriz                                                ; $1415
	ret                                                             ; $1418


; A - num bytes
; B - byte to set
; HL - dest addr
MemSetHoriz:
-	ld (hl), b                                                      ; $1419
	inc hl                                                          ; $141a
	dec a                                                           ; $141b
	jr nz, -                                                        ; $141c

	ret                                                             ; $141e


; A - num bytes
; B - byte to set
; HL - dest addr
MemSetVert:
	ld de, SCREEN_COLS                                              ; $141f
-	ld (hl), b                                                      ; $1422
	add hl, de                                                      ; $1423
	dec a                                                           ; $1424
	jr nz, -                                                        ; $1425

	ret                                                             ; $1427


; 3 groups for each layout, in order of fire, big puddle, small puddle
Layout1Elements:
	.dw wNameTable+$108
	.dw wNameTable+$10e
	.dw wNameTable+$22b

	.dw wNameTable+$4b
	.dw wNameTable+$174
	.dw wNameTable+$28b

	.dw wNameTable+$105
	.dw wNameTable+$111
	.dw wNameTable+$162
	
	
Layout2Elements:
	.dw wNameTable+$8b
	.dw wNameTable+$286
	.dw wNameTable+$28f

	.dw wNameTable+$54
	.dw wNameTable+$1d2
	.dw wNameTable+$294

	.dw wNameTable+$86
	.dw wNameTable+$90
	.dw wNameTable+$102
	
	
Layout3Elements:
	.dw wNameTable+$a4
	.dw wNameTable+$144
	.dw wNameTable+$1e4

	.dw wNameTable+$b1
	.dw wNameTable+$151
	.dw wNameTable+$211

	.dw wNameTable+$a2
	.dw wNameTable+$142
	.dw wNameTable+$1e2


; HL - pointer to layout elements
DrawLayoutElements:
	push bc                                                         ; $145e

; Loop through 3 fires, C = bitfield of fires shown
	ld b, $03                                                       ; $145f
	ld ix, Metatile_FireBottom                                      ; $1461

	ld a, (wInGameFiresShown)                                       ; $1465
	ld c, a                                                         ; $1468

@nextFire:
; If bit clear for fire, don't display it
	bit 0, c                                                        ; $1469
	jr z, @toNextFire                                               ; $146b

; Else DE = dest address of fire
	ld e, (hl)                                                      ; $146d
	inc hl                                                          ; $146e
	ld d, (hl)                                                      ; $146f

; Get dest in IY, then display
	push de                                                         ; $1470
	pop iy                                                          ; $1471
	call DisplayFireMetatile                                        ; $1473
	jr +                                                            ; $1476

@toNextFire:
	inc hl                                                          ; $1478

+	inc hl                                                          ; $1479

; To next fire and bitfield bit
	srl c                                                           ; $147a
	dec b                                                           ; $147c
	jr nz, @nextFire                                                ; $147d

; Perform the above, but with puddles
	ld b, $03                                                       ; $147f
	ld a, (wInGameBigPuddlesShown)                                  ; $1481
	ld c, a                                                         ; $1484
	ld ix, Metatile_BigPuddle                                       ; $1485
	call DisplayPuddleMetatile                                      ; $1489

;
	ld b, $03                                                       ; $148c
	ld a, (wInGameSmallPuddlesShown)                                ; $148e
	ld c, a                                                         ; $1491
	ld ix, Metatile_SmallPuddle                                     ; $1492
	call DisplayPuddleMetatile                                      ; $1496

	pop bc                                                          ; $1499
	ret                                                             ; $149a


; B - num puddles
; C - bitfield for puddles shown
; HL - pointer to puddle dest address
; IX - metatile addr
DisplayPuddleMetatile:
@nextPuddle:
; If bit clear for puddle, don't display it
	bit 0, c                                                        ; $149b
	jr z, @toNextPuddle                                             ; $149d

; Else DE = dest address of puddle
	ld e, (hl)                                                      ; $149f
	inc hl                                                          ; $14a0
	ld d, (hl)                                                      ; $14a1

; Get dest in IY, then display
	push de                                                         ; $14a2
	pop iy                                                          ; $14a3
	call LoadMetatile                                               ; $14a5
	jr +                                                            ; $14a8

@toNextPuddle:
	inc hl                                                          ; $14aa

+	inc hl                                                          ; $14ab

; To next puddle and bitfield bit
	srl c                                                           ; $14ac
	dec b                                                           ; $14ae
	jr nz, @nextPuddle                                              ; $14af

	ret                                                             ; $14b1


Layout_FireTop:
	.db $47, $48

Metatile_FireBottom:
	.db $43, $44, $45, $46


Metatile_BigPuddle:
	.db $3f, $40, $41, $42


Metatile_SmallPuddle:
	.db $3b, $3c, $3d, $3e

	
LoadRound1Layout:
; Clear 6 digits of curr score
	ld hl, wCurrScoreDigits                                         ; $14c0
	ld de, wCurrScoreDigits+1                                       ; $14c3
	ld bc, $05                                                      ; $14c6
	ld (hl), $00                                                    ; $14c9
	ldir                                                            ; $14cb

; Add nothing to score, then update score val layout
	ld bc, $00                                                      ; $14cd
	ld d, $00                                                       ; $14d0
	call AddB100sC1ksD10ksToCurrScore                               ; $14d2
	call UpdateShadowScoreValueLayout                               ; $14d5

; Set lives to 3 and round to 1
	ld a, $03                                                       ; $14d8
	ld (wLivesLeft), a                                              ; $14da

	ld a, $01                                                       ; $14dd
	ld (wOrigRound), a                                              ; $14df
	ld (wOrigRoundDigits+1), a                                      ; $14e2

	xor a                                                           ; $14e5
	ld (wOrigRoundDigits), a                                        ; $14e6

; Clear bonus lives acquired and num special items loaded
	ld (wBonusLivesGotten), a                                       ; $14e9
	ld (wOrigSpecialItemsLoaded), a                                 ; $14ec

; Set walls tile idx to the 1st wall tile
	ld a, TILE_WALLS                                                ; $14ef
	ld (wWallsTileIdx), a                                           ; $14f1
	jr LoadRoundAfterSettingWallTile                                ; $14f4


LoadNextRoundLayout:
; Inc walls tile idx, looping it around the 3 tile idxes available
	ld hl, wWallsTileIdx                                            ; $14f6
	inc (hl)                                                        ; $14f9

	ld a, (hl)                                                      ; $14fa
	cp TILE_WALLS+3                                                 ; $14fb
	jr nz, LoadRoundAfterSettingWallTile                            ; $14fd

	ld (hl), TILE_WALLS                                             ; $14ff

LoadRoundAfterSettingWallTile:
; Save that all elements are showing
	ld a, $07                                                       ; $1501
	ld (wOrigFiresShown), a                                         ; $1503
	ld (wOrigBigPuddlesShown), a                                    ; $1506
	ld (wOrigSmallPuddlesShown), a                                  ; $1509

; Clear starting special items loaded
	xor a                                                           ; $150c
	ld (wOrigSpecialItemsLoaded), a                                 ; $150d

LoadRoundAfterRestart:
; Set as if prev btn held was left (start player moving left)
	ld a, $08                                                       ; $1510
	ld (wPlayerLastInputDirection), a                               ; $1512
	ld (wPrevBtnsHeld), a                                           ; $1515

; Restore lives left when round started
	ld a, (wLivesLeft)                                              ; $1518
	ld (wDisplayedLivesLeft), a                                     ; $151b

; Restart round with saved round/digits, then prefix the digits with a blank tile
	ld a, (wOrigRound)                                              ; $151e
	ld hl, (wOrigRoundDigits)                                       ; $1521
	ld (wRound), a                                                  ; $1524
	ld b, a                                                         ; $1527
	ld (wRoundDigits), hl                                           ; $1528

	call PrefixRoundWithBlankTile                                   ; $152b

; If we chose level 2...
	ld a, (wButtonsHeldOnTitleScreen)                               ; $152e
	bit REMAPPED_2, a                                               ; $1531
	jr z, @afterOpt2check                                           ; $1533

; And curr level is 1-3...
	ld a, b                                                         ; $1535
	cp $04                                                          ; $1536
	jr nc, @afterOpt2check                                          ; $1538

; Set difficulty to 1
	ld a, $01                                                       ; $153a
	ld b, a                                                         ; $153c

@afterOpt2check:
; Max difficulty at 10
	ld a, b                                                         ; $153d
	cp $0a                                                          ; $153e
	jr c, +                                                         ; $1540
	ld a, $0a                                                       ; $1542

; Based on difficulty, have HL point to a 6-byte entry in the table for it
+	ld bc, $06                                                      ; $1544
	ld hl, DifficultyMetadata                                       ; $1547

@nextTableEntry:
	dec a                                                           ; $154a
	jr z, @chosenTableEntry                                         ; $154b

	add hl, bc                                                      ; $154d
	jr @nextTableEntry                                              ; $154e

@chosenTableEntry:
	ld de, wDifficultyMetadata                                      ; $1550
	ldir                                                            ; $1553

; Split nybbles into enemy timer thresholds
	ld a, (wEnemyTimerThresholds)                                   ; $1555
	and $0f                                                         ; $1558
	ld (wEnemyTimerThreshold2), a                                   ; $155a

	ld a, (wEnemyTimerThresholds)                                   ; $155d
	srl a                                                           ; $1560
	srl a                                                           ; $1562
	srl a                                                           ; $1564
	srl a                                                           ; $1566
	ld (wEnemyTimerThreshold1), a                                   ; $1568

; Set starting bonus score
	ld hl, (wStartingBonusScore)                                    ; $156b
	ld (wBonusScoreDigits+1), hl                                    ; $156e
	xor a                                                           ; $1571
	ld (wBonusScoreDigits+3), a                                     ; $1572

; Restore fires shown, wInGameBigPuddlesShown and wInGameSmallPuddlesShown
	ld hl, wOrigFiresShown                                          ; $1575
	ld de, wInGameFiresShown                                        ; $1578
	ld bc, $03                                                      ; $157b
	ldir                                                            ; $157e

; Clear most of in-game layout, then re-draw it and status
	ld b, $00                                                       ; $1580
	call SubtractBHundredsFromBonusScore                            ; $1582
	call ClearInGameLayoutExceptStatus                              ; $1585
	call SetLayoutAndDrawIt                                         ; $1588
	call DisplayInGameStatus                                        ; $158b

; Load player sprites
	ld hl, Sprites_Player                                           ; $158e
	ld de, wSprites                                                 ; $1591
	ld bc, Sprites_Player@end-Sprites_Player                        ; $1594
	ldir                                                            ; $1597

; Set water level to full
	ld a, $03                                                       ; $1599
	ld (wPlayerWaterLevel), a                                       ; $159b

; Clear num elements shown, and num special items loaded
	ld hl, wOrigFiresShown                                          ; $159e
	ld a, (wOrigSpecialItemsLoaded)                                 ; $15a1
	ld de, wInGameFiresShown                                        ; $15a4
	ld bc, $03                                                      ; $15a7
	ldir                                                            ; $15aa

	ld (wNumSpecialItemsLoaded), a                                  ; $15ac

; Clear stand-still reason and that an item is loaded in the center
	xor a                                                           ; $15af
	ld (wInGameStandstillReason), a                                 ; $15b0
	ld (wCenterItemLoaded), a                                       ; $15b3

; Clear enemy structs
	ld hl, wEnemyStructs                                            ; $15b6
	ld de, wEnemyStructs+1                                          ; $15b9
	ld bc, wEnemyStructsEnd-wEnemyStructs-1                         ; $15bc
	ld (hl), $00                                                    ; $15bf
	ldir                                                            ; $15c1

; Clear generic timers and their jump funcs
	ld hl, wGenericTimers                                           ; $15c3
	ld de, wGenericTimers+1                                         ; $15c6
	ld bc, wGenericTimerEnd-wGenericTimers-1                        ; $15c9
	ld (hl), $00                                                    ; $15cc
	ldir                                                            ; $15ce
	ret                                                             ; $15d0


DifficultyMetadata:
; Byte 1 - 2 timers for each nybble that tell how fast an enemy moves
; Byte 2 - starting number of 10k bonus pts
; Byte 3 - starting number of 1k bonus pts
; Byte 4-6 - unused
	.db $28, $00, $05, $01, $5a, $01
	.db $25, $00, $05, $01, $5a, $01
	.db $23, $00, $05, $01, $5a, $01
	.db $1f, $01, $00, $02, $5a, $02
	.db $1a, $01, $00, $02, $5a, $02
	.db $18, $01, $00, $02, $5a, $02
	.db $14, $01, $05, $03, $3c, $03
	.db $13, $01, $05, $03, $3c, $03
	.db $12, $01, $05, $03, $3c, $03
	.db $12, $02, $00, $04, $28, $05


Sprites_Player:
	.db $58, $58, $08, $06
	.db $58, $58, $18, $05
@end:


IYequAddrOfObjectNametableTile:
	push bc                                                         ; $1615
	push hl                                                         ; $1616

; HL = object Y, A = 2
	ld a, (wObjectY)                                                ; $1617
	ld l, a                                                         ; $161a
	ld a, $02                                                       ; $161b
	ld h, $00                                                       ; $161d

@nextHLtimesEqu2:
; HL *= 2
	sla l                                                           ; $161f
	jr nc, +                                                        ; $1621

	sla h                                                           ; $1623
	set 0, h                                                        ; $1625

+	dec a                                                           ; $1627
	jr nz, @nextHLtimesEqu2                                         ; $1628

; HL now object Y * 4 (every 8 pixels = $20, ie HL contains object row)
; Below sla to compensate for Y >= $80 that gets sla applied once rather than both times
	ld a, (wObjectY)                                                ; $162a
	cp $80                                                          ; $162d
	jr c, +                                                         ; $162f
	sla h                                                           ; $1631

; L to be start of row
+	ld a, l                                                         ; $1633
	and $e0                                                         ; $1634
	ld l, a                                                         ; $1636

; BC = object X
	ld a, (wObjectX)                                                ; $1637
	ld c, a                                                         ; $163a
	ld b, $00                                                       ; $163b

; HL += object X / 8 (tile X)
	srl c                                                           ; $163d
	srl c                                                           ; $163f
	srl c                                                           ; $1641
	add hl, bc                                                      ; $1643

; BC = nametable offset for object coords
	push hl                                                         ; $1644
	pop bc                                                          ; $1645

; IY points to nametable tile object is on
	ld iy, wNameTable                                               ; $1646
	add iy, bc                                                      ; $164a

	pop hl                                                          ; $164c
	pop bc                                                          ; $164d
	ret                                                             ; $164e


HLequRowColPixelsAtNametableAddrIY:
	push bc                                                         ; $164f

; HL points to nametable area player is colliding with
	push iy                                                         ; $1650
	pop hl                                                          ; $1652

; HL = offset into nametable
	ld de, wNameTable                                               ; $1653
	sbc hl, de                                                      ; $1656

; B = row part of tile's offset
	ld a, l                                                         ; $1658
	and $e0                                                         ; $1659
	ld b, a                                                         ; $165b

; L = col part * 8
	ld a, l                                                         ; $165c
	and $1f                                                         ; $165d
	sla a                                                           ; $165f
	sla a                                                           ; $1661
	sla a                                                           ; $1663
	ld l, a                                                         ; $1665

; Below means HB *= 64, ie H = row part * 8
	ld c, $06                                                       ; $1666

@nextMultBy2:
; HB *= 2
	sla h                                                           ; $1668
	sla b                                                           ; $166a
	jr nc, +                                                        ; $166c
	set 0, h                                                        ; $166e

+	dec c                                                           ; $1670
	jr nz, @nextMultBy2                                             ; $1671

	pop bc                                                          ; $1673
	ret                                                             ; $1674


; H - row pixel of tile to check
; L - col pixel of tile to check
; Returns 1 if no collision with center of metatile
CheckIfCollidingWithMetatileCenter:
	push bc                                                         ; $1675

; HL = center of metatile
	ldbc $07, $07                                                   ; $1676
	add hl, bc                                                      ; $1679

; Return 1 if object Y >= metatile's center
; If equal (object top touching tile center), check X
	ld a, (wObjectY)                                                ; $167a
	cp h                                                            ; $167d
	jr z, @checkX                                                   ; $167e

	jr nc, @return1                                                 ; $1680

; Return 1 if object top+bottom < metatile's center
	add a, $0f                                                      ; $1682
	cp h                                                            ; $1684
	jr z, @checkX                                                   ; $1685

	jr nc, @checkX                                                  ; $1687

@return1:
	ld a, $01                                                       ; $1689
	pop bc                                                          ; $168b
	ret                                                             ; $168c

@checkX:
; Return 1 if object X > metatile's center. 0 if X == metatile's center
	ld a, (wObjectX)                                                ; $168d
	cp l                                                            ; $1690
	jr z, @return0                                                  ; $1691

	jr nc, @return1                                                 ; $1693

; Return 1 if object's right edge < metatile's center, else return 0
	add a, $0f                                                      ; $1695
	cp l                                                            ; $1697
	jr z, @return0                                                  ; $1698

	jr c, @return1                                                  ; $169a

@return0:
	xor a                                                           ; $169c
	pop bc                                                          ; $169d
	ret                                                             ; $169e


PollInput:
; Immediately check joypad input if no keyboard was detected on startup
	ld a, (wKeyboardAttached)                                       ; $169f
	or a                                                            ; $16a2
	jp z, @checkJoypadBtns                                          ; $16a3

; Check if joypad buttons held first...
	ld a, PORT_C_JOYPADS                                            ; $16a6
	out (IO_PORT_C), a                                              ; $16a8

	in a, (IO_PORT_AB)                                              ; $16aa
	or a                                                            ; $16ac
	cp $ff                                                          ; $16ad
	jr z, @noButtonsHeld                                            ; $16af

; If so, read new buttons
	ld a, PORT_C_JOYPADS                                            ; $16b1
	out (IO_PORT_C), a                                              ; $16b3
	jp @checkJoypadBtns                                             ; $16b5

@noButtonsHeld:
; C to mimic joypad input (bits reset if buttons held)
	ld c, $ff                                                       ; $16b8

; Keyboard row 2 bit 4 is 1 btn
	ld a, $02                                                       ; $16ba
	out (IO_PORT_C), a                                              ; $16bc
	in a, (IO_PORT_AB)                                              ; $16be
	bit 4, a                                                        ; $16c0
	jr nz, +                                                        ; $16c2
	res INPUT_1, c                                                  ; $16c4

; Keyboard row 3 bit 4 is 2 btn
+	ld a, $03                                                       ; $16c6
	out (IO_PORT_C), a                                              ; $16c8
	in a, (IO_PORT_AB)                                              ; $16ca
	bit 4, a                                                        ; $16cc
	jr nz, +                                                        ; $16ce
	res INPUT_2, c                                                  ; $16d0

; Keyboard row 4 bit 5 is down btn
+	ld a, $04                                                       ; $16d2
	out (IO_PORT_C), a                                              ; $16d4
	in a, (IO_PORT_AB)                                              ; $16d6
	bit 5, a                                                        ; $16d8
	jr nz, +                                                        ; $16da
	res INPUT_DOWN, c                                               ; $16dc

; Keyboard row 5 bit 5 is left btn
+	ld a, $05                                                       ; $16de
	out (IO_PORT_C), a                                              ; $16e0
	in a, (IO_PORT_AB)                                              ; $16e2
	bit 5, a                                                        ; $16e4
	jr nz, +                                                        ; $16e6
	res INPUT_LEFT, c                                               ; $16e8

; Keyboard row 6 bit 5 is right btn
+	ld a, $06                                                       ; $16ea
	out (IO_PORT_C), a                                              ; $16ec
	in a, (IO_PORT_AB)                                              ; $16ee
	bit 5, a                                                        ; $16f0
	jr nz, +                                                        ; $16f2
	res INPUT_RIGHT, c                                              ; $16f4

; Keyboard row 6 bit 6 is up btn
+	bit 6, a                                                        ; $16f6
	jr nz, +                                                        ; $16f8
	res INPUT_UP, c                                                 ; $16fa

; On keyboard, prevent pressing up+down, or left+right
+	bit INPUT_UP, c                                                 ; $16fc
	jr nz, +                                                        ; $16fe
	set INPUT_DOWN, c                                               ; $1700

+	bit INPUT_LEFT, c                                               ; $1702
	jr nz, +                                                        ; $1704
	set INPUT_RIGHT, c                                              ; $1706

; Jump to remap buttons and only have 1 orthogonal direction at a time
+	ld a, c                                                         ; $1708
	jr +                                                            ; $1709

@checkJoypadBtns:
; Read from input, and cpl to get bits set from buttons held
	in a, (IO_PORT_AB)                                              ; $170b

+	cpl                                                             ; $170d

; Remap buttons, then check if horiz buttons held...
	call RemapButtonsHeldBits                                       ; $170e
	bit REMAPPED_RIGHT, a                                           ; $1711
	jr nz, @checkVertBtnsHeld                                       ; $1713

	bit REMAPPED_LEFT, a                                            ; $1715
	jr nz, @checkVertBtnsHeld                                       ; $1717

	jr @end                                                         ; $1719

@checkVertBtnsHeld:
; If so, don't allow vert buttons at the same time
	res REMAPPED_UP, a                                              ; $171b
	res REMAPPED_DOWN, a                                            ; $171d

@end:
	ld (wRemappedBtnsHeld), a                                       ; $171f
	ret                                                             ; $1722


; A - buttons held
; Returns A with different bits set based on buttons held
RemapButtonsHeldBits:
	ld b, a                                                         ; $1723
	xor a                                                           ; $1724

; Set bit 1 if up held
	srl b                                                           ; $1725
	jr nc, +                                                        ; $1727
	set REMAPPED_UP, a                                              ; $1729

; Set bit 4 if down held
+	srl b                                                           ; $172b
	jr nc, +                                                        ; $172d
	set REMAPPED_DOWN, a                                            ; $172f

; Set bit 3 if left held
+	srl b                                                           ; $1731
	jr nc, +                                                        ; $1733
	set REMAPPED_LEFT, a                                            ; $1735

; Set bit 2 if right held
+	srl b                                                           ; $1737
	jr nc, +                                                        ; $1739
	set REMAPPED_RIGHT, a                                           ; $173b

; Set bit 0 if 1 held
+	srl b                                                           ; $173d
	jr nc, +                                                        ; $173f
	set REMAPPED_1, a                                               ; $1741

; Set bit 5 if 2 held
+	srl b                                                           ; $1743
	ret nc                                                          ; $1745

	set REMAPPED_2, a                                               ; $1746
	ret                                                             ; $1748


UpdateSound:
@updateSound:
; Return if no sound is supposed to be played
	ld a, (wSoundToPlay)                                            ; $1749
	and $0f                                                         ; $174c
	ret z                                                           ; $174e

; Jump if the sound to play is the mute control
	cp SND_MUTE                                                     ; $174f
	jr z, @initSound                                                ; $1751

; Jump if the sound to play is the sound being played
	ld c, a                                                         ; $1753
	ld a, (wSoundBeingPlayed)                                       ; $1754
	cp c                                                            ; $1757
	jr z, @updateCurrSound                                          ; $1758

; Else set that a new sound is being played
	ld a, c                                                         ; $175a
	ld (wSoundBeingPlayed), a                                       ; $175b

; New sound is double-idxed into table
	ld b, $00                                                       ; $175e
	add a, c                                                        ; $1760
	ld c, a                                                         ; $1761
	ld ix, SoundData                                                ; $1762
	add ix, bc                                                      ; $1766

; HL = address of sound data
	ld l, (ix+$00)                                                  ; $1768
	ld h, (ix+$01)                                                  ; $176b

; Set start address of sound bytes
	ld (wSoundByteAddr), hl                                         ; $176e

@nextSoundByte:
; Once sound byte == $ff, stop sound
	ld hl, (wSoundByteAddr)                                         ; $1771
	ld a, (hl)                                                      ; $1774
	cp SND_BYTE_STOP                                                ; $1775
	jr z, @initSound                                                ; $1777

; If sound byte == $f8, clear wSoundBeingPlayed, so check above restarts this sound
	cp SND_BYTE_RESTART                                             ; $1779
	jr z, @restartSound                                             ; $177b

; 1st note byte is for the length and volume
	ld (wNoteLenVol), a                                             ; $177d
	inc hl                                                          ; $1780

; 2nd note byte is for the frequency
	ld a, (hl)                                                      ; $1781
	ld (wNoteFrequency), a                                          ; $1782

; Save address of next note byte
	inc hl                                                          ; $1785
	ld (wSoundByteAddr), hl                                         ; $1786
	ret                                                             ; $1789

@restartSound:
	xor a                                                           ; $178a
	ld (wSoundBeingPlayed), a                                       ; $178b
	jr @updateSound                                                 ; $178e

@initSound:
	call InitSound                                                  ; $1790

	xor a                                                           ; $1793
	ld (wSoundToPlay), a                                            ; $1794
	ld (wSoundBeingPlayed), a                                       ; $1797
	ret                                                             ; $179a

@updateCurrSound:
; Update bytes to send to PSG
	call SetFreqBytesForPSG                                         ; $179b
	call SetVolByteForPSG                                           ; $179e

; Set PSG bytes
	ld b, _sizeof_wPSG                                              ; $17a1
	ld c, PSG                                                       ; $17a3
	ld hl, wPSG                                                     ; $17a5
	otir                                                            ; $17a8

; Subtract 1 from sound length
	ld a, (wNoteLenVol)                                             ; $17aa
	sub $10                                                         ; $17ad
	ld (wNoteLenVol), a                                             ; $17af

; If upper nybble breached 0, process next sound byte
	and $f0                                                         ; $17b2
	jr z, @nextSoundByte                                            ; $17b4

	ret                                                             ; $17b6


InitSound:
; Set all tones to 0, and max all volumes
	ld b, @end-@data                                                ; $17b7
	ld c, PSG                                                       ; $17b9
	ld hl, @data                                                    ; $17bb
	otir                                                            ; $17be
	ret                                                             ; $17c0

@data:
	PSG_LATCH_DATA PSG_TONE_0, PSG_IS_TONE, $0
	PSG_DATA $00
	PSG_LATCH_DATA PSG_TONE_0, PSG_IS_VOL, $f

	PSG_LATCH_DATA PSG_TONE_1, PSG_IS_TONE, $0
	PSG_DATA $00
	PSG_LATCH_DATA PSG_TONE_1, PSG_IS_VOL, $f

	PSG_LATCH_DATA PSG_TONE_2, PSG_IS_TONE, $0
	PSG_DATA $00
	PSG_LATCH_DATA PSG_TONE_2, PSG_IS_VOL, $f

	PSG_LATCH_DATA PSG_NOISE, PSG_IS_TONE, $0
	PSG_LATCH_DATA PSG_NOISE, PSG_IS_VOL, $f
@end:


SetFreqBytesForPSG:
; Low nybble of 2nd sound byte data is double idxed into below table
	ld a, (wNoteFrequency)                                          ; $17cc
	and $0f                                                         ; $17cf
	sla a                                                           ; $17d1
	ld e, a                                                         ; $17d3
	ld d, $00                                                       ; $17d4
	ld hl, FrequencyTable                                           ; $17d6
	add hl, de                                                      ; $17d9

; C = bits 4-6 of this byte (octave adjust)
	ld a, (wNoteFrequency)                                          ; $17da
	srl a                                                           ; $17dd
	srl a                                                           ; $17df
	srl a                                                           ; $17e1
	srl a                                                           ; $17e3
	and $07                                                         ; $17e5
	ld c, a                                                         ; $17e7

; DE = word entry
	ld e, (hl)                                                      ; $17e8
	inc hl                                                          ; $17e9
	ld d, (hl)                                                      ; $17ea

; If adjust == 0, jump ahead
	ld a, c                                                         ; $17eb
	or a                                                            ; $17ec
	jr z, @afterOctaveAdjust                                        ; $17ed

@nextAdjust:
; For every adjustment, de /= 2 (higher octave)
	ld a, d                                                         ; $17ef
	sra a                                                           ; $17f0
	ld d, a                                                         ; $17f2

	ld a, e                                                         ; $17f3
	rra                                                             ; $17f4
	ld e, a                                                         ; $17f5

	dec c                                                           ; $17f6
	jr nz, @nextAdjust                                              ; $17f7

@afterOctaveAdjust:
; Low nybble of E is the low 4 bits of tone for PSG_LATCH_DATA(PSG_TONE_0|PSG_IS_TONE)
	ld a, e                                                         ; $17f9
	and $0f                                                         ; $17fa
	or $80                                                          ; $17fc
	ld (wPSG), a                                                    ; $17fe

; DE /= $10, ie upper 6 bits of tone
	srl e                                                           ; $1801
	srl e                                                           ; $1803
	srl e                                                           ; $1805
	srl e                                                           ; $1807
	sla d                                                           ; $1809
	sla d                                                           ; $180b
	sla d                                                           ; $180d
	sla d                                                           ; $180f

; Use 6 bits for PSG_DATA
	ld a, d                                                         ; $1811
	and $3f                                                         ; $1812
	or e                                                            ; $1814
	ld (wPSG+1), a                                                  ; $1815
	ret                                                             ; $1818


SetVolByteForPSG:
; Low nybble of 1st note byte is for PSG_LATCH_DATA(PSG_IS_VOL), ie volume
	ld a, (wNoteLenVol)                                             ; $1819
	and $0f                                                         ; $181c
	or $90                                                          ; $181e
	ld (wPSG+2), a                                                  ; $1820
	ret                                                             ; $1823


FrequencyTable:
	.dw $0d58 ; C1
	.dw $0c98 ; C#1
	.dw $0be8 ; D1
	.dw $0b38 ; D#1
	.dw $0a98 ; E1
	.dw $0a00 ; F1
	.dw $0970 ; F#1
	.dw $08e8 ; G1
	.dw $0868 ; G#1
	.dw $07f0 ; A1
	.dw $077c ; A#1
	.dw $0710 ; B1


SoundData:
	.dw SoundData0
	.dw SoundData1
	.dw SoundData2_PlayerWalking
	.dw SoundData3_PuddleCollected
	.dw SoundData4_WaterFired
	.dw SoundData5_DiedByFire
	.dw SoundData6_GotSpecialWater
	.dw SoundData7
	.dw SoundData8_EnemySpawned
	.dw SoundData9_FireExtinguished
	.dw SoundDataA_RoundClear
	.dw SoundDataB_DiedOther
	.dw SoundDataC
	.dw SoundDataD
	.dw SoundDataE


SoundData0:
SoundData1:
	.db SND_BYTE_STOP


SoundData2_PlayerWalking:
	LenVolNote 2, 4, _Fsharp, 5
	LenVolNote 2, 3, _Fsharp, 5
	LenVolNote 2, 2, _Fsharp, 5
	LenVolNote 2, 1, _Fsharp, 5
	LenVolNote 6, 1, _Asharp, 5
	LenVolNote 4, 2, _B, 5
	.db SND_BYTE_STOP

	.ds $1877-$1867, 0


SoundData3_PuddleCollected:
	LenVolNote 2, 1, _D, 5
	LenVolNote 2, 2, _D, 5
	LenVolNote 2, 3, _D, 5
	LenVolNote 2, 4, _D, 5
	LenVolNote 3, 4, _E, 5
	LenVolNote 6, 3, _G, 5
	.db SND_BYTE_STOP

	.ds $188a-$1884, 0


SoundData4_WaterFired:
	LenVolNote 2, 3, _Dsharp, 6
	LenVolNote 2, 2, _Dsharp, 6
	LenVolNote 2, 1, _Dsharp, 6
	LenVolNote 2, 2, _Dsharp, 6
	LenVolNote 2, 3, _Dsharp, 6
	LenVolNote 2, 3, _E, 6
	LenVolNote 2, 4, _E, 6
	LenVolNote 2, 5, _E, 6
	LenVolNote 2, 6, _E, 6
	.db SND_BYTE_STOP

	.ds $18a9-$189d, 0


SoundData5_DiedByFire:
	LenVolNote 3, 3, _Dsharp, 5
	LenVolNote 3, 2, _E, 5
	LenVolNote 3, 1, _F, 5
	LenVolNote 3, 2, _E, 5
	LenVolNote 3, 3, _Dsharp, 5
	LenVolNote 3, 3, _Dsharp, 6
	LenVolNote 3, 2, _E, 6
	LenVolNote 3, 1, _F, 6
	LenVolNote 3, 2, _E, 6
	LenVolNote 3, 3, _Dsharp, 6
	LenVolNote 5, 3, _Fsharp, 6
	.db SND_BYTE_STOP

	.ds $18c6-$18c0, 0


SoundData6_GotSpecialWater:
	LenVolNote 3, 2, _C, 7
	LenVolNote 3, 2, _D, 7
	LenVolNote 3, 2, _E, 7
	LenVolNote 3, 2, _Fsharp, 7
	LenVolNote 3, 3, _Gsharp, 7
	.db SND_BYTE_STOP

	.ds $18d7-$18d1, 0


SoundData7:
	.db SND_BYTE_STOP


SoundData8_EnemySpawned:
	LenVolNote 2, 3, _C, 3
	LenVolNote 2, 3, _Csharp, 3
	LenVolNote 2, 3, _C, 3
	LenVolNote 2, 3, _Csharp, 3
	LenVolNote 4, 2, _D, 3
	LenVolNote 4, 3, _E, 3
	.db SND_BYTE_STOP

	.ds $18eb-$18e5, 0


SoundData9_FireExtinguished:
	LenVolNote 3, 2, _G, 5
	LenVolNote 3, 2, _A, 5
	LenVolNote 3, 2, _Csharp, 5
	LenVolNote 3, 2, _G, 5
	LenVolNote 3, 2, _A, 5
	LenVolNote 3, 2, _Csharp, 5
	.db SND_BYTE_STOP

	.ds $18fe-$18f8, 0


SoundDataA_RoundClear:
	LenVolNote 7, 3, _E, 7
	LenVolNote 7, 3, _Fsharp, 7
	LenVolNote 7, 3, _Gsharp, 7
	LenVolNote 7, 3, _E, 7
	LenVolNote 7, 3, _Fsharp, 7
	LenVolNote 7, 3, _Gsharp, 7
	LenVolNote 5, 2, _A, 7
	.db SND_BYTE_RESTART

	.ds $1914-$190e, 0


SoundDataB_DiedOther:
	LenVolNote 4, 3, _C, 6
	LenVolNote 4, 3, _Csharp, 6
	LenVolNote 4, 3, _D, 6
	LenVolNote 4, 3, _E, 6
	LenVolNote 4, 2, _Csharp, 6
	LenVolNote 4, 2, _D, 6
	LenVolNote 4, 2, _Dsharp, 6
	LenVolNote 4, 2, _F, 6
	LenVolNote 4, 1, _D, 6
	LenVolNote 4, 1, _Dsharp, 6
	LenVolNote 4, 1, _E, 6
	LenVolNote 4, 1, _Fsharp, 6
	LenVolNote 3, 2, _Fsharp, 5
	LenVolNote 3, 2, _F, 5
	LenVolNote 3, 3, _F, 4
	LenVolNote 3, 3, _E, 4
	LenVolNote 3, 4, _E, 3
	LenVolNote 3, 4, _Dsharp, 3
	.db SND_BYTE_STOP

	.ds $193e-$1938, 0


SoundDataC:
	.db SND_BYTE_STOP


SoundDataD:
	.db SND_BYTE_STOP


SoundDataE:
	.db SND_BYTE_STOP


; $1942
	.db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $ff, $00
	.db $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $ff
	.db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $ff, $00
	.db $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $ff
	.db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $ff, $00
	.db $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $ff
	.db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $ff, $00
	.db $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $ff
	.db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $ff, $00
	.db $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $00, $ff
	.db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff


; Unused
	ldir                                                            ; $19f0
	jp Begin2                                                       ; $19f2


; $19f5
	.db $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00


Gfx_BG:
	.incbin "build/bg.1bpp" read $2d8


Palette_Ascii:
	.db $f0


Palette_Water:
	.db $70


Palette_Fire:
	.db $80


Palette_Misc:
	.db $00, $00, $00, $00, $00, $00, $00, $00, $a0, $a2, $a2, $a2, $a0, $20, $20, $20
	.db $70, $b7, $b7, $b7, $b7, $b7, $b0, $b0, $90, $9c, $9c, $9c, $9c, $9c, $90, $90
	.db $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $a0, $a0, $70, $70, $70, $70, $70, $70
	.db $70, $70, $70, $70, $70, $70, $70, $70, $a0, $a0, $70, $70, $70, $70, $70, $70
	.db $70, $70, $70, $70, $70, $70, $70, $70, $40, $40, $90, $90, $90, $90, $90, $40
	.db $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $90, $90, $90, $90, $90, $40
	.db $40, $40, $40, $40, $40, $40, $40, $40, $90, $90, $90, $90, $90, $90, $90, $90
	.db $70, $70, $70, $70, $70, $70, $70, $70, $70, $70, $70, $70, $70, $70, $70, $70
@end:


Gfx_Spr:
	.incbin "build/spr.1bpp" read $260

; $1fbb
	.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
	.db $00, $ff, $00, $ff, $00, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00
	.db $ff, $00, $ff, $00, $ff, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff, $00, $ff
	.db $00, $ff, $00, $ff, $00
