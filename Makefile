all: wc

wc.o: wc.s
	as -g --32 -o $@ $<

wc: wc.o
	ld -m elf_i386 -o $@ $<

clean:
	rm -f wc.o wc
