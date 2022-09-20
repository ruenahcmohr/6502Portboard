GALIC=GAL16V8
all:	main.ujed

%.ujed: %.pld
	galasm $<
	tr -d '\015' <$(@:.ujed=.jed) >$@

upload: erase
	minipro -p $(GALIC) -w $(file)

erase:
	minipro -p $(GALIC) -E

clean:
	rm *.ujed *.jed *.pin *.fus *.chp

.phony: all
