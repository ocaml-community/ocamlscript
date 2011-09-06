#!/usr/bin/env ocamlscript
Ocaml.packs := ["cgi"]
--
let get actobj =
  try 
    (match (actobj#argument "foo")#value with
	 "0" -> "No"
       | "1" -> "Yes"
       | _ -> "Other")
  with Not_found -> "Undefined"

let print (actobj : Netcgi.std_activation) s =
  actobj#set_header ~content_type:"text/plain" ();
  actobj#output#output_string s;
  actobj#output#commit_work ()

let _ =
  let actobj = new Netcgi.std_activation () in
  print actobj (get actobj)
