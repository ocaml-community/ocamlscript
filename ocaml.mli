(** Default compilation module: settings for the Ocaml compilers *)

(** the name of the camlp4o command; default: "camlp4o" *)
val camlp4o : string ref

(** the name of the camlp4r command; default: "camlp4r" *)
val camlp4r : string ref

(** the name of the ocamllex command; default: "ocamllex" *)
val ocamllex : string ref

(** the name of the ocamlyacc command; default: "ocamlyacc" *)
val ocamlyacc : string ref

(** the name of the ocamlc command; default: "ocamlc" *)
val ocamlc : string ref

(** the name of the ocamlopt command; default: "ocamlopt" *)
val ocamlopt : string ref

(** the name of the ocamlfind command; default: "ocamlfind" *)
val ocamlfind : string ref

(** Specific Findlib/ocamlfind packages to use *)
val packs : string list ref

(** Extra source files (processed with camlp4 but not ocamllex). 
  They can be referenced either by an absolute path or by a path relative 
  to the script directory.
  They are compiled and linked in like regular OCaml compilation units. *)
val sources : string list ref

(** whether to use ocamllex or not; default: false *)
val use_ocamllex : bool ref

(** whether to use camlp4 preprocessing or not; default: true *)
val use_camlp4 : bool ref

(** whether to use ocamlc instead of ocamlopt; default: false *)
val use_ocamlc : bool ref

(** whether to use ocamlfind even if [!packs] is empty; default: false *)
val use_ocamlfind : bool ref

(** whether the revised syntax of OCaml should be used; default: false *)
val revised : bool ref

(** any other options to pass to the compiler *)
val ocamlflags : string list ref

(** any other options to pass to the preprocessor *)
val ppopt : string list ref

(** type of a preprocessor: takes an input file and returns a command and 
  the list of files to be processed further. *)
type pp = string -> (Pipeline.command * string list)

(** optional preprocessor that comes before all other preprocessors *)
val pp : pp option ref

(** the function which takes the source file path and generates the string
  the will be inserted at the beginning of files when they are copied.
  The default is set to follow OCaml's standard syntax, 
  like "#1 \"file.ml\";;\n" for instance. *)
val ppsrcloc : (string -> string) option ref


(** the compilation function which is used
  to set [Ocamlscript.Common.compile] *)
val compile : string -> string -> int
