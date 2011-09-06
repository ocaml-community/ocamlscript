Ocaml.packs := ["num"]
--
open Printf
open Big_int

let rec fac n =
  if le_big_int n zero_big_int then unit_big_int
  else mult_big_int n (fac (pred_big_int n))

let rec get_int attempt =
  try 
    printf "Please enter a number: ";
    read_int ()
  with _ ->
    if attempt >= 3 then
      (printf "Bye.\n";
       exit 1)
    else
      (printf "This is not a number. Please try again.\n";
       get_int (attempt + 1))

let _ =
  let x = 
    match Sys.argv with
	[| _; s |] -> (try int_of_string s with _ -> get_int 2)
      | _ -> get_int 1 in
  let y = fac (big_int_of_int x) in
  printf "%i! = %s\n" x (string_of_big_int y)
