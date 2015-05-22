#!/usr/bin/env ocamlscript
let open Ocamlscript.Std in (** Inclues Ocamlscript and special (--) operator *)
begin 
  Ocaml.packs := ["cmdliner"]
end
-- 
(* ^^^ opened as infix operator here, returning a unit.
 * Must be on its own line! *)
() (* need to close out the -- operator *)

let f x y = x + 1 (* can parse basic staements after the () *)

let arg_info = Cmdliner.Arg.info (* ensure packs are present *)

let () = print_endline "look ma, no merlin errors!"
