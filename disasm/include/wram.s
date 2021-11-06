.include "include/hardware.s"
.include "include/rominfo.s"
.include "include/constants.s"
.include "include/structs.s"
.include "include/macros.s"

.ramsection "WRAM 0" bank 0 slot 1

wTopScoreDigits: ; $c000
    ds 6

wPauseCounter: ; $c006
    db

wVBlankInterruptCounter: ; $c007
    db

wGameState: ; $c008
    db

wKeyboardAttached: ; $c009
    db

wButtonsHeldOnTitleScreen: ; $c00a
    db

; 0 - empty, 3 - full
wPlayerWaterLevel: ; $c00b
    db

; 0 - not in a stand-still
; 1 - on collision
; 2 - when killed
; 3 - when time ran out
; 4 - when no fires shown
wInGameStandstillReason: ; $c00c
    db

wPlayerHitByEnemy: ; $c00d
    db

wc00e:
    ds $f-$e

wNumSpecialItemsLoaded: ; $c00f
    db

wOrigSpecialItemsLoaded: ; $c010
    db

wCenterItemLoaded: ; $c011
    db

wCenterItemMetatileAddr: ; $c012
    dw

wIsProcessingObjectCollision: ; $c014
    db

wDisplayedLivesLeft: ; $c015
    db

wWallsTileIdx: ; $c016
    db

wCurrScoreDigits: ; $c017
    ds 6

; 1-indexed
wRound: ; $c01d
    db

wBonusScoreDigits: ; $c01e
    ds 6

wBonusScoreDeductionTimer: ; $c024
    db

wTopScoreLayout: ; $c025
    ds 6
wCurrScoreLayout: ; $c02b
    ds 6

wRoundDigits: ; $c031
    dw

wBonusScoreLayout: ; $c033
    ds 6

wGenericTimers: ; $c039
    ds 7
wc040:
    ds 2-0
wTimer1JumpAddr: ; $c042
    dw
wTimer2JumpAddr: ; $c044
    dw
wEnemyTimers: ; $c046
    ds 3*2
wTimer6JumpAddr: ; $c04c
    dw
wGenericTimerEnd: ; $c04e
    .db

wRemappedBtnsHeld: ; $c04e
    db
wPlayerLastInputDirection: ; $c04f
    db
; Prev action buttons, directions is current
wPrevBtnsHeld: ; $c050
    db

wLivesLeft: ; $c051
    db

wBonusLivesGotten: ; $c052
    db

wOrigRound: ; $c053
    db

wOrigRoundDigits: ; $c054
    dw

; 1-indexed
wInGameLayout: ; $c056
    db

wWaterPanicTimer: ; $c057
    db

; For the following 3 vars, bits 0-2 in that order determine if the element is shown
wInGameFiresShown: ; $c058
    db
wInGameBigPuddlesShown: ; $c059
    db
wInGameSmallPuddlesShown: ; $c05a
    db

wOrigFiresShown: ; $c05b
    db
wOrigBigPuddlesShown: ; $c05c
    db
wOrigSmallPuddlesShown: ; $c05d
    db

wDifficultyMetadata: ; $c05e
    .db
wEnemyTimerThresholds: ; $c05e
    db
wStartingBonusScore: ; $c05f
    dw
wc061:
    ds 3

wPlayerCoords: ; $c064
    .db
wObjectY: ; $c064
    db
wObjectX: ; $c065
    db

wc066:
    ds 8-6

wPlayerMovementTimer1: ; $c068
    db
wPlayerMovementTimer2: ; $c069
    db

wEnemySpawnTimer: ; $c06a
    db

wEnemyStructs: ; $c06b
    .db
; Bit 2 - tail top-left (REMAPPED_RIGHT)
; Bit 3 - tail bottom-right (REMAPPED_LEFT)
; Bit 1 - tail bottom-left (REMAPPED_UP)
; Else (assumes bit 4) tail top-right (REMAPPED_DOWN)
wEnemyDirection: ; $c06b
    ds 3
wUnusedEnemyStructVars_c06e: ; $c06e
    ds 3
wEnemyDirsAttempted: ; $c071
    ds 3
wEnemyStructsEnd: ; $c074
    .db

wEnemyTimerThreshold1: ; $c074
    db
wEnemyTimerThreshold2: ; $c075
    db

wPreservedPuddleAddr: ; $c076
    dw

wPreservedPlayerCoordsDuringWaterShot: ; $c078
    dw

wPreservedPlayerBtnsHeldAndDir: ; $c07a
    ds 2

wDestAddressesOfDestroyedFires: ; $c07c
    .db
wDestAddrOfDestroyedStaticFire: ; $c07c
    dw
wDestAddrOfDestroyedFireEnemies: ; $c07e
    ds 3*2

wDestroyedFireEnemyX: ; $c084
    db
wDestroyedFireEnemyY: ; $c085
    db

wPreservedPlayerCoordsDuringEnemyDeath: ; $c086
    ds 2

wDoneAddingBonusPtsToCurrScore: ; $c088
    db

wWaterShotLifeTimer: ; $c089
    db

wWaterExtinguishedStaticFire: ; $c08a
    db
wc08b:
    ds $c-$b

wWaterExtinguishedFireEnemy1: ; $c08c
    db
wWaterExtinguishedFireEnemy2: ; $c08d
    db

wPreservedRemappedBtnsHeld: ; $c08e
    ds 3

wc091:
    ds $c-1

wPreservedPlayerSprites: ; $c09c
    ds 4*2

wc0a4
    ds 7-4

wFire1SpawnCoords: ; $c0a7
    dw
wFire2SpawnCoords: ; $c0a9
    dw
wFire3SpawnCoords: ; $c0ab
    dw
wFiresPixelDistanceToPlayer: ; $c0ad
    ds 3*2

wc0b3:
    ds 5-3

wSoundToPlay: ; $c0b5
    db

wSoundBeingPlayed: ; $c0b6
    db

wSoundByteAddr: ; $c0b7
    dw

wNoteFrequency: ; $c0b9
    db

wNoteLenVol: ; $c0ba
    db

wPSG: ; $c0bb
    ds 3

wc0be
    ds $100-$be

wStackTop: ; $c100
    .db

wNameTable: ; $c100
    ds $2e0

wSprites: ; $c3e0
    ds $14

wc3f4:
    .db

.ends
