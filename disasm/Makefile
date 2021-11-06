OBJS = build/main.o
RAM_OBJS = build/wram.o
GFX_OBJS = $(shell find gfx/ -name '*.png' | sed "s/gfx/build/" | sed "s/.png/.1bpp/")

all: guzzler.sg

build/%.1bpp: gfx/%.png
	./gfx.py 1bpp $< --out=$@

build/wram.o: include/wram.s
	wla-z80 -o $@ $<

build/main.o: code/main.s
	wla-z80 -o $@ $<

guzzler.sg: $(GFX_OBJS) $(OBJS) $(RAM_OBJS)
	wlalink -S linkfile $@
