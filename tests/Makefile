.PHONY: default clean
default:
	@echo '*** These tests are for developers only! ***'
	@echo -e '*** They might not work on your platform! ***\n\n'
	cp -f ../_build/default/src/ocamlscript.exe ./ocamlscript
	./unpack
	'./Hello "World"'
	./fulltest arg1 arg2
	./ocamlscript -- '-full test' arg1 arg2 arg3
	./ocamlscript -c -o hello -e 'print_endline "Hello"'
	./hello
	echo 'Printf.printf "Goodbye %s\n" Sys.argv.(1)' \
            | ocamlscript - -o goodbye '$(USER)'
	./goodbye again
clean:
	$(RM) -- ocamlscript *~ \
	  "-full test.exe" fulltest.exe 'Hello "World"' hello goodbye
