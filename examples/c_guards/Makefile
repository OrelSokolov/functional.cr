CC      ?= cc
CRYSTAL ?= crystal

all: unsafe guarded

mathlib.o: mathlib.c
	$(CC) -c -O2 -o $@ $<

unsafe: unsafe.cr mathlib.o
	$(CRYSTAL) build -o $@ --link-flags "$(CURDIR)/mathlib.o" $<

guarded: guarded.cr mathlib.o
	$(CRYSTAL) build -o $@ --link-flags "$(CURDIR)/mathlib.o" $<

demo: all
	@echo '=== WITHOUT guards ==='; ./unsafe; echo "exit code: $$?"; \
	 echo; echo '=== WITH guards ==='; ./guarded; echo "exit code: $$?"

clean:
	rm -f unsafe guarded mathlib.o

.PHONY: all demo clean
