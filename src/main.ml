
open Printf

let () =
  try Ocamlscript.main ()
  with Failure s ->
    (eprintf "ocamlscript: %s\n%!" s;
     exit 2)
