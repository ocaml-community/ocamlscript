(* Using Camlp4 revised syntax *)

(* Camlp4 is used by default *)
(* Ocaml.use_camlp4 := true *)

(* this selects the revised syntax: *)
Ocaml.revised := true
--

(* This is the program in the revised syntax: *)

value hello () = 
  do { print_endline "Hello!";
       print_endline "Goodbye!" }
;

value _ = hello ()
;
