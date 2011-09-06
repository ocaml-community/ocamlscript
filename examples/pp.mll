(* Using ocamllex as if it were not supported by default,
   to show how to use a custom preprocessor. *)
Ocaml.pp := 
 Some (fun file ->
	 let o = if not (Filename.check_suffix file ".mll") then "main.ml"
	 else Filename.chop_extension file ^ ".ml" in
	 Pipeline.command ["ocamllex"; file; "-o"; o; "-q"], [o])
--
rule token = parse
  _   { () }
| eof { () }
{ print_endline "Hello from pp.ml using ocamllex" }
