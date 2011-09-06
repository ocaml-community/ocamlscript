.PHONY: default clean
default:
	../ocamlscript factorial.ml 100
	../ocamlscript revised.ml
	../ocamlscript with-includes.ml
	echo "1+1" | ../ocamlscript calc.ml
clean:
	$(RM) *~ *.exe
