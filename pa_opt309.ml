(*
  Public Domain. Use at your own risk!
  Author: Martin Jambon <martin_jambon@emailuser.net>
*)

EXTEND
  Pcaml.expr: LEVEL "expr1" [
    [ id = LIDENT; "??"; e = Pcaml.expr LEVEL "expr1" -> 
	<:expr< 
	match $lid:id$ with
            [ None -> ()
            | Some $lid:id$ -> $e$ ] >> ]
  ];
END
