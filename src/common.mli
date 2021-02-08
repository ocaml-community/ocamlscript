(** Options that are shared by all compilation modules. *)

(** All arguments which are not valid options for ocamlscript 
  but are not arguments of the script either. 
  Typically it would be the case of unix.cmxa in
  "#!/usr/bin/ocamlscript unix.cmxa".
  It is the responsibility of the "compile" function to handle these
  arguments. The default "compile" command (Ocamlscript.Ocaml.compile)
  simply passes these arguments to ocamlopt.
*)
val extra_args : string list ref

(** runtime trash which may contain the name of the executable itself, 
  for self-removal, in case it is a temporary file (e.g. generated from
  standard input). *)
val trash : string list ref

(** If this option is true, ocamlscript prints some debugging information 
  to stdout. *)
val verbose : bool ref

(** [script_dir] is meant to hold the absolute path to the directory which
  contains the script, or just the current directory at the time when
  ocamlscript was started if the script is not read from a file. *)
val script_dir : string ref

(** The function which is used to compile the program.
  [compile source result] reads the source code from file [source] and
  writes the executable to file [result]. This function
  should return 0 if it succeeds, and 1 or another code otherwise.
  Its default value is [Ocamlscript.Ocaml.compile].
*)
val compile : (string -> string -> int) ref
