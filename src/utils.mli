(** Handy utilities for file manipulation.
  This module is automatically opened by ocamlscript. *)

(** shortcut for portable file path concatenation *)
val ( // ) : string -> string -> string

(** prefix operator to reference a file relatively to the script directory. *)
val ( !+ ) : string -> string
