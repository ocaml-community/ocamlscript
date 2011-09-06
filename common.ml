let extra_args = ref ([]  : string list)
let trash = ref ([]  : string list)
let verbose = ref false
let script_dir = ref (Sys.getcwd ())
let compile : (string -> string -> int) ref = 
  ref (fun source result -> failwith "Compile.compile is unset")
