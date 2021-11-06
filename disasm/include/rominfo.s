.memorymap
	defaultslot 0

	slotsize $2000
	slot 0 $0000

	slotsize $400
	slot 1 $c000
.endme

.banksize $2000
.rombanks 1

.asciitable
	map "0" to "9" = $00
	map "-" = $0a
	map "@" = $0b ; copyright
	map "A" = $0c
	map "C" to "E" = $0d
	map "K" to "L" = $10
	map "N" to "P" = $12
	map "R" to "V" = $15
	map "Y" = $1a
	map " " = $4b
.enda
