.define SPRITE_TABLE_ADDR = $1c00
.define NAME_TABLE_ADDR = $3800

.define TILE_WATER_SHOT_RIGHT = $2c
.define TILE_WATER_SHOT_LEFT = $30
.define TILE_WATER_SHOT_UP = $34
.define TILE_WATER_SHOT_DOWN = $38
.define TILE_SMALL_PUDDLE_BOTTOM_RIGHT = $3e
.define TILE_BIG_PUDDLE_BOTTOM_RIGHT = $42
.define TILE_FIRE_MAIN_BOTTOM_RIGHT = $46
.define TILE_FIRE_HEAD_LEFT_1 = $47
.define TILE_FIRE_HEAD_RIGHT_1 = $48
.define TILE_FIRE_HEAD_LEFT_2 = $49
.define TILE_FIRE_HEAD_RIGHT_2 = $4a
.define TILE_BLANK = $4b
.define TILE_WALLS = $4c ; this up to $4e
.define TILE_WALL_3RD = $4e
.define TILE_GREEN = $4f
.define TILE_HEART = $58

.define SPR_WATER_LEVEL_HIGH = $18
.define SPR_WATER_LEVEL_MID = $1c
.define SPR_WATER_LEVEL_LOW = $20
.define SPR_ENEMY_TAIL_TOP_LEFT = $3c
.define SPR_ENEMY_TAIL_BOTTOM_RIGHT = $40
.define SPR_ENEMY_TAIL_BOTTOM_LEFT = $44
.define SPR_ENEMY_TAIL_TOP_RIGHT = $48
.define SPR_WATER_LEVEL_EMPTY = $4c

.define COLL_NONE = $00
.define COLL_WALL = $01
.define COLL_CENTER = $02
.define COLL_BIG_PUDDLE = $03
.define COLL_SMALL_PUDDLE = $04
.define COLL_FIRE_MAIN = $05

.define GS_INIT = $00
.define GS_TITLE_SCREEN = $01
.define GS_IN_GAME = $02

.define SND_PLAYER_WALKING = $02
.define SND_PUDDLE_COLLECTED = $03
.define SND_WATER_FIRED = $04
.define SND_DIED_BY_FIRE = $05
.define SND_GOT_SPECIAL_WATER = $06
.define SND_ENEMY_SPAWNED = $08
.define SND_FIRE_EXTINGUISHED = $09
.define SND_ROUND_CLEAR = $0a ; only looping sound
.define SND_DIED_OTHER = $0b
.define SND_MUTE = $0f

.define SND_BYTE_RESTART = $f8
.define SND_BYTE_STOP = $ff