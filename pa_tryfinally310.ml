(*
  Public Domain. Use at your own risk!
  Author: Martin Jambon <martin_jambon@emailuser.net>

  This syntax extension provides a "try ... finally ..." construct
  is used to force the execution of a statement after some computation
  even if that computation raises an exception. For instance, the following
  expression has type "int" and always prints "done" at the end, 
  but propagates the Division_by_zero exception:

  try
    print_string "trying a hard division...";
    0 / 0
  finally
    print_endline " done";
    flush stdout

  In "try e1 finally e2", if e2 raises an exception, it is propagated.
  If this behavior is not wanted, it is the user's responsibility to 
  insert a catch-all statement, i.e. write
  "try e1 finally try e2 with _ -> ()" instead.
*)

open Camlp4.PreCast

let unique = 
  let counter = ref 0 in
  fun () -> incr counter; "__pa_tryfinally" ^ string_of_int !counter

let expand _loc e1 e2 =
  let result = unique () in
  <:expr<
  let $lid:result$ =
    try `Result $e1$
    with [ exn -> `Exn exn ] in
  let () = $e2$ in
  match $lid:result$ with
      [ `Result x -> x
      | `Exn exn -> raise exn ]
  >>

EXTEND Gram
  Syntax.expr: LEVEL "top" [
    [ "try"; e1 = Syntax.sequence; 
      "finally"; e2 = Syntax.expr LEVEL ";" -> expand _loc e1 e2 ]
  ];
END
