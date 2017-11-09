ACMD=java -jar ~/bin/AppleCommander-1.3.5-ac.jar

.PHONY: all
all:  mig.insp.po

mig.insp.po: mig.insp
	$(ACMD) -pro140 mig.insp.po MIG.INSP
	$(ACMD) -p mig.insp.po MIG.INSP BIN 0x2000 < mig.insp

mig.insp: mig.insp.o
	ld65 -t none -o mig.insp mig.insp.o

mig.insp.o: mig.insp.s
	ca65 -o mig.insp.o -l mig.insp.lst mig.insp.s

.PHONY: clean
clean:
	rm -f mig.insp.po mig.insp mig.insp.o mig.insp.lst

