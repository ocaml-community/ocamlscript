VERSION = 2.0.4
RESULT = ocamlscript
SOURCES = \
  version.ml pipeline.mli pipeline.ml common.mli common.ml \
  utils.mli utils.ml ocaml.mli ocaml.ml std.ml

CAMLP4 := $(shell ocamlfind query camlp4)

STDBIN = $(shell dirname `which ocamlfind`)
ifndef PREFIX
  PREFIX = $(shell dirname $(STDBIN))
endif
export PREFIX

ifndef BINDIR
  BINDIR = $(PREFIX)/bin
endif
export BINDIR

PACKS = unix str
PP = camlp4o -I . -parser pa_tryfinally.cmo -parser pa_opt.cmo
export PP

CAMLP4_VARIANTS = pa_tryfinally.ml pa_opt.ml
OCAMLFLAGS = -dtypes


.PHONY: init default common bytelib optlib optexe bytelib optlib \
        install uninstall test tests examples ocamldoc version meta archive

default: common bytelib optlib optexe

# GODI targets
.PHONY: all opt
all: common bytelib byteexe
opt: common optlib optexe
###

common: version.ml
	ocamlc -pp 'camlp4orf -loc _loc' -c \
		-I $(CAMLP4) pa_opt310.ml && \
		cp pa_opt310.cmo pa_opt.cmo && \
		cp pa_opt310.cmi pa_opt.cmi
	ocamlc -pp 'camlp4orf -loc _loc' -c \
		-I $(CAMLP4) pa_tryfinally310.ml && \
		cp pa_tryfinally310.cmo pa_tryfinally.cmo && \
		cp pa_tryfinally310.cmi pa_tryfinally.cmi

byteexe: bytelib
	ocamlfind ocamlc -o ocamlscript.byte -pp '$(PP)' \
	  -package '$(PACKS)' -linkpkg $(OCAMLFLAGS) \
	  ocamlscript.cmo main.ml
optexe: optlib
	ocamlfind ocamlopt -o ocamlscript -pp '$(PP)' \
	  -package '$(PACKS)' -linkpkg $(OCAMLFLAGS) \
	  ocamlscript.cmx main.ml
bytelib: pabc
	touch bc.done
optlib: panc
	touch nc.done
install:
	test -f ocamlscript$(EXE) && \
	  install -m 0755 ocamlscript$(EXE) $(BINDIR)/ocamlscript$(EXE) || :
	test -f ocamlscript.byte$(EXE) && \
	  install -m 0755 ocamlscript.byte$(EXE) \
		$(BINDIR)/ocamlscript.byte$(EXE) || :
	ocamlfind install ocamlscript META \
		ocamlscript.cmi \
		`test -f bc.done && echo ocamlscript.cmo` \
		`test -f nc.done && echo ocamlscript.cmx ocamlscript.o`
uninstall:
	rm -f $(BINDIR)/ocamlscript$(EXE) $(BINDIR)/ocamlscript.byte$(EXE)
	ocamlfind remove ocamlscript

test: tests
tests:
	cd tests && $(MAKE)
examples:
	cd examples && $(MAKE)

ocamldoc:
	ocamldoc -d ocamldoc -html pipeline.mli common.mli utils.mli ocaml.mli

.PHONY: version
version: version.ml
version.ml: Makefile
	echo 'let version = "$(VERSION)"' > version.ml
	echo 'version = "$(VERSION)"' > META
	cat META.in >> META

.PHONY: help
help:
	./ocamlscript --help > ocamlscript-help.txt


archive: all version help
	rm -rf /tmp/ocamlscript /tmp/ocamlscript-$(VERSION) && \
	 	cp -r . /tmp/ocamlscript && \
		cd /tmp/ocamlscript && \
			$(MAKE) clean && \
			rm -f *~ ocamlscript*.tar* && \
			cp ocamldoc/* $$WWW/ocamlscript-doc && \
		cd /tmp && cp -r ocamlscript ocamlscript-$(VERSION) && \
		tar czf ocamlscript.tar.gz ocamlscript && \
		tar cjf ocamlscript.tar.bz2 ocamlscript && \
		tar czf ocamlscript-$(VERSION).tar.gz \
			ocamlscript-$(VERSION) && \
		tar cjf ocamlscript-$(VERSION).tar.bz2 ocamlscript-$(VERSION)
	mv /tmp/ocamlscript.tar.gz /tmp/ocamlscript.tar.bz2 .
	mv /tmp/ocamlscript-$(VERSION).tar.gz \
			/tmp/ocamlscript-$(VERSION).tar.bz2 .
	cp ocamlscript.tar.gz ocamlscript.tar.bz2 $$WWW/
	cp ocamlscript-$(VERSION).tar.gz ocamlscript-$(VERSION).tar.bz2 $$WWW/
	cp LICENSE $$WWW/ocamlscript-license.txt
	echo 'let ocamlscript_version = "$(VERSION)"' \
		> $$WWW/ocamlscript-version.ml
	cp Changes $$WWW/ocamlscript-changes.txt
	cp ocamlscript-help.txt $$WWW/
	rm -rf $$WWW/ocamlscript-examples
	cd examples && $(MAKE) clean
	cp -r examples $$WWW/ocamlscript-examples

TRASH = \
  bc.done nc.done main.cm* main.o main.annot \
  ocamlscript$(EXE) ocamlscript.byte$(EXE) \
  pa_opt*.cm* pa_tryfinally*.cm* *~ \
  version.ml META


clean::
	cd tests && $(MAKE) clean
	cd examples && $(MAKE) clean
	rm -rf ocamldoc

OCAML_VERSION = $(shell ocamlc -v | head -1 | \
                  sed -e 's/.*version \([0-9]\.[0-9][0-9]\).*/\1/')

OCAMLBCFLAGS = -for-pack Ocamlscript
OCAMLNCFLAGS = -for-pack Ocamlscript

OCAMLMAKEFILE = OCamlMakefile
include $(OCAMLMAKEFILE)
