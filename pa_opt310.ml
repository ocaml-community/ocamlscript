(*
  Public Domain. Use at your own risk!
  Author: Martin Jambon <martin_jambon@emailuser.net>
*)

open Camlp4.PreCast

EXTEND Gram
  Syntax.expr: LEVEL "top" [
    [ id = LIDENT; "??"; e = Syntax.expr LEVEL "top" -> 
	<:expr< 
	match $lid:id$ with
            [ None -> ()
            | Some $lid:id$ -> $e$ ] >> ]
  ];
END
