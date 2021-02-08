.PHONY: default clean
default:
	../_build/default/src/main.exe factorial.ml 100
	../_build/default/src/main.exe revised.ml
	../_build/default/src/main.exe with-includes.ml
	echo "1+1" | ../_build/default/src/main.exe calc.ml
clean:
	$(RM) *~ *.exe
