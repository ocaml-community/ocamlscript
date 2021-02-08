(*
 ocamlscript: a utility to have shell-like optimised scripts in OCaml

 Copyright 2005 David MENTRE <dmentre@linux-france.org>
 Copyright 2006 Martin Jambon <martin_jambon@emailuser.net>
*)

open Printf
open Ocamlscript

module Opt =
struct
  let set what opt s =
    match !opt with
	Some _ -> failwith (sprintf "%s is already set" what)
      | None -> opt := Some s

  let help = ref false (* help and exit *)
  let c = ref false (* compile only *)
  let f = ref false (* force recompile *)
  let debug = ref false (* additional stdout output *)
  let version = ref false (* show version and exit *)
  let from = ref (None : [`File of string | `String of string | `Stdin] option)
  let o = ref None (* choose a name for the compiled executable *)
  let vm = ref None (* possible bytecode interpreter *)
  let extra_args = ref []

  let help_message = "\
Usage: ocamlscript [ PACKED_OPTIONS [ OPTIONS ] [ -- ] [SCRIPTNAME] [ARGS] ]

Ocamlscript normally reads the source code of a program from a file, looks
if a compiled executable exists for this program. If it exists and if it
is more recent than the source file, the executable is executed immediately,
otherwise it is updated by executing compilation instructions that can
be specified in the program file.

A typical self-executable script looks as follows:

  #!/usr/bin/env ocamlscript
  (* this is the compilation section, in OCaml *)
  Ocaml.packs := [\"unix\"; \"micmatch_pcre\"] (* Findlib packages *)
  --
  (* this is the program section *)
  let _ =
    ...


Structure of the command line:

PACKED_OPTIONS:
  the first argument of ocamlscript. It is either unpacked into
  several arguments that are passed to ocamlscript or into a script name
  if this name doesn't start with \"-\". Double-quotes can be used
  to enclose arguments that contain whitespace or double-quotes.
  Double-quotes must be doubled. For instance, the following
  self-executable script would be compiled into an executable named
  Hello \"World\":
    #!/usr/bin/ocamlscript -o \"Hello \"\"World\"\"\"
    print_endline \"Hello \"World\"\"

  Important note: on some Unix systems, the whole
  '-o \"Hello \"\"World\"\"\"' string is passed as a single argument
  to ocamlscript. This is why the first argument must be unpacked,
  even if ocamlscript is called explicitely from the command line.

OPTIONS:
  any number of arguments in this section are treated like options
  to ocamlscript until a either a non-option is encountered, which is
  understood as the script name (SCRIPTNAME) or \"--\" which stops
  the list of arguments that are passed to ocamlscript.

Ocamlscript supports the following options:
  --  marks the end of ocamlscript arguments
  -help  displays a help message and exit
  --help  same as -help
  -c  compile only
  -o EXEC_NAME  specify a name for the executable
                (required if the program is not read from a file)
  -e PROGRAM  execute the code given here instead of reading it from a file
  -f  force recompilation which is otherwise based on last modification dates
  -debug  print messages about what ocamlscript is doing
  -version  prints the version identifier to stdout and exit
  -  read program from stdin instead of a file
  -vm VIRTUAL_MACHINE  run the executable using this virtual machine (e.g.
                       ocamlrun)

\"--\": passed as an argument to ocamlscript in the PACKED_OPTIONS argument
        or in the OPTIONS argument marks the end of the arguments that
        are passed to ocamlscript. Arguments that follow will be
        interpreted as arguments of the script.
        Arguments that follow \"--\" in the PACKED_OPTIONS argument
        will be passed as arguments to the final executable. The first
        argument that follows \"--\" in the OPTIONS command line arguments
        is treated as the script name, unless the program is read from
        another source, as specified by options \"-e\" (a string) or \"-\"
        (standard input).


For a full documentation on the structure of the compilation section, go to
ocamlscript's website (http://martin.jambon.free.fr/ocamlscript.html).
"
end

(* more generic than .opt since we can compile with other commands than
   ocamlopt *)
let bin_suffix = ".exe"

let bin_name src =
  match !Opt.o with
      Some s -> s
    | None -> src ^ bin_suffix

let obin_name src =
  match !Opt.o with
      Some s -> s
    | None ->
	match src with
	    `Stdin | `String _ -> failwith "please specify a name \
                                            for the executable with -o"
	  | `File s -> s ^ bin_suffix

let source_name = function
    None -> assert false
  | Some s -> s

let ( // ) = Filename.concat

let endline = if Sys.os_type = "Win32" then "\r\n" else "\n"
let output_line oc s = output_string oc s; output_string oc endline

(* based on last modification date only.
   Doesn't handle dependencies toward runtime things that might change
   incompatibly (DLLs, bytecode version, ...).
   ocamlscript -f can be used to force recompilation in these cases. *)
let needs_recompile ?log = function
    `Stdin | `String _ -> true
  | `File source ->
      let bin = bin_name source in
      not (Sys.file_exists bin) ||
      (Unix.stat bin).Unix.st_mtime <= (Unix.stat source).Unix.st_mtime

(*
RE sep = "--" blank* eos
*)
(*
RE_STR "--" blank* eos
*)
let sep = Str.regexp "--[\t ]*$"
let is_sep s = Str.string_match sep s 0

let rec split_list accu is_sep = function
    [] -> `One (List.rev accu)
  | hd :: tl ->
      if is_sep hd then `Two (List.rev accu, tl)
      else split_list (hd :: accu) is_sep tl

let read_locstyle = function
    "ocaml" -> `Ocaml
  | "blank" -> `Blank
  | "none" -> `None
  | _ -> failwith "invalid locstyle directive"

(*
let process_directives lines =
  let style = ref `Ocaml in
  let ocaml_lines =
    List.map
      (function
	   / "#" blank* "locstyle" blank*
	     (lower ['_'alnum*] as x) blank* ";;"? blank* eol / as s ->
	     style := read_locstyle x;
	     String.make (String.length s) ' '
	 | s -> s)
      lines in
  (ocaml_lines, !style)
*)
let process_directives =
  let micmatch_1 =
    Str.regexp
      "#[\t ]*locstyle[\t ]*\\([a-z][0-9A-Z_a-z]*\\)[\t ]*\\(;;\\)?[\t ]*$"
  in
  fun lines ->
    let style = ref `Ocaml in
    let ocaml_lines =
      List.map
        (fun micmatch_any_target ->
           let micmatch_match_target_1 = micmatch_any_target in
           (try
              match micmatch_match_target_1 with
                micmatch_1_target as s when true ->
                  if Str.string_match micmatch_1 micmatch_1_target 0 then
                    let x = Str.matched_group 1 micmatch_1_target in
                    fun () ->
                      style := read_locstyle x;
                      String.make (String.length s) ' '
                  else raise Exit
              | _ -> raise Exit
            with
              Exit ->
                let s = micmatch_match_target_1 in fun () -> s)
             ())
        lines
    in
    ocaml_lines, !style

(*
let split_lines lines =
  let lines1, lines2 = split_list [] is_sep lines in
  let pos1, header =
    match lines1 with
	/ "#!" / :: header -> (2, header)
      | _ -> (1, lines1) in
  let pos2 = List.length lines1 + 2 in
  (pos1, header, pos2, lines2)
*)

let split_lines lines =
  let test s = String.length s >= 2 && s.[0] = '#' && s.[1] = '!' in
  let lines1, lines2 =
    match split_list [] is_sep lines with
	`One (s :: prog) when test s -> [s], prog
      | `One prog -> [], prog
      | `Two (a, b) -> (a, b) in
  let (pos1, header) =
    match lines1 with
        s :: header when test s -> 2, header
      | _ -> 1, lines1 in
  let pos2 = List.length lines1 + 2 in
  (pos1, header, pos2, lines2)

let get_dir file =
  let dir = Filename.dirname file in
  if Filename.is_relative dir then Filename.concat (Sys.getcwd ()) dir
  else dir

let write_header ~pos ~source ~source_option ~verbose ~prog_file lines =
  let bin = obin_name source_option in
  let extra_args =
    match !Opt.extra_args with
	[] -> ""
      | l ->
	  sprintf "Ocamlscript.Common.extra_args := [ %s];;\n"
	    (String.concat "; " (List.map (fun s -> sprintf "%S" s) l)) in
  let trash, script_dir =
    match source_option with
	`Stdin
      | `String _ -> (sprintf "Ocamlscript.Common.trash := \
                               %S :: !Ocamlscript.Common.trash;;\n"
			bin,
			Sys.getcwd ())
      | `File script_name -> "", get_dir script_name in

  let file, oc = Filename.open_temp_file "meta" ".ml" in
  fprintf oc "\
#%i %S;;
(* Opam installations of findlib place topfind in a different directory *)
let () =
  try Topdirs.dir_directory (Sys.getenv \"OCAML_TOPLEVEL_PATH\")
  with Not_found -> ()
;;
#use \"topfind\";;
#require \"ocamlscript\";;
Ocamlscript.Common.verbose := %s;;
Ocamlscript.Common.script_dir := %S;;
%s%sOcamlscript.Common.compile := Ocamlscript.Ocaml.compile;;
open Ocamlscript;;
open Utils;;
#%i %S;;\n"
     pos source verbose script_dir extra_args trash pos source;

  List.iter (output_line oc) lines;

  fprintf oc "\
let _ = exit (!Ocamlscript.Common.compile %S %S);;\n" prog_file bin;
  close_out oc;
  file


let write_body ~pos ~source ~locstyle lines =
  let file, oc = Filename.open_temp_file "prog" ".ml" in
  (match locstyle with
       `Ocaml -> fprintf oc "#%i %S;;\n" pos source
     | `Blank -> for i = 1 to pos - 1 do output_string oc endline done
     | `None -> ());
  List.iter (output_line oc) lines;
  close_out oc;
  file

module Text =
struct
  exception Internal_exit

  let iter_lines_of_channel f ic =
    try
      while true do
	let line =
	  try input_line ic
	  with End_of_file -> raise Internal_exit in
	f line
      done
    with Internal_exit -> ()

  let iter_lines_of_file f file =
    let ic = open_in file in
    try
      iter_lines_of_channel f ic;
      close_in ic
    with exn ->
      close_in_noerr ic;
      raise exn

  let lines_of_channel ic =
    let l = ref [] in
    iter_lines_of_channel (fun line -> l := line :: !l) ic;
    List.rev !l

  let lines_of_file file =
    let l = ref [] in
    iter_lines_of_file (fun line -> l := line :: !l) file;
    List.rev !l
end


let split_file =
  let newline = Str.regexp "\r?\n" in
  fun ?log source_option ->
    let source, lines =
      match source_option with
	  `Stdin -> "", Text.lines_of_channel stdin
	| `String s -> "", (Str.split newline) s
	| `File file -> file, Text.lines_of_file file in

    let pos1, unprocessed_header, pos2, body = split_lines lines in
    let header, locstyle = process_directives unprocessed_header in

    let verbose = if log = None then "false" else "true" in

    let prog_file =
      write_body ~pos:pos2 ~source ~locstyle body in
    let meta_file =
      write_header
	~pos:pos1 ~source ~source_option ~verbose ~prog_file header in
    (meta_file, prog_file)


let compile_script ?log source_option =
  let meta_name, prog_name = split_file ?log source_option in
  Fun.protect (fun () -> Pipeline.run_command (Pipeline.command ["ocaml"; meta_name]))
    ~finally:(fun () ->
        (* comment out for debugging: *)
        Pipeline.remove meta_name;
        Pipeline.remove prog_name
      )

let absolute path =
  if Filename.is_relative path then
    Sys.getcwd () // path
  else path

let option0 ?(refuse_input = false) x =
  let result = ref `Yes in
  (match x with
       "--" -> result := `Stop
     | "-help"
     | "--help" -> Opt.help := true
     | "-c" -> Opt.c := true
     | "-f" -> Opt.f := true
     | "-debug" -> Opt.debug := true
     | "-version" -> Opt.version := true
     | "-" ->
	 if refuse_input then
	   failwith "option - is disabled in this context"
	 else
	   Opt.set "source" Opt.from `Stdin
     | _ -> result := `No);
  !result

let option1 ?(refuse_input = false) x y =
  let result = ref true in
  (match x with
       "-o" -> Opt.set "executable name" Opt.o y
     | "-vm" -> Opt.set "virtual machine" Opt.vm y
     | "-e" ->
	if refuse_input then
	  failwith "option -e is disabled in this context"
	else
	  Opt.set "source" Opt.from (`String y)
     | _ -> result := false);
  !result

let start_option1 =
  function
      "-o"
    | "-vm"
    | "-e" ->  true
    | _ -> false

let optionx = function
    "" -> false
  | s when s.[0] = '-' -> failwith (sprintf "%s is not a valid option" s)
  | _ -> false

let other_arg x =
  Opt.extra_args := x :: !Opt.extra_args


let process_ocamlscript_args ?refuse_input ?(accept_non_option = false) l =
  let rec loop = function
      x :: rest as l ->
	begin
	  match option0 x with
	      `Stop -> (None, true, rest)
	    | `Yes -> loop rest
	    | `No ->
		match l with
		    x :: y :: rest when option1 ?refuse_input x y -> loop rest
		  | x :: rest ->
		      if start_option1 x then
			(Some x, false, rest)
		      else if optionx x then
			loop rest
		      else if accept_non_option then
			(other_arg x; loop rest)
		      else (None, false, l)
		  | [] -> assert false
	end
    | [] -> (None, false, []) in
  loop l


let unquote s =
  let buf = Buffer.create (String.length s) in
  let i = ref 0 in
  let len = String.length s in
  while !i < len do
    match s.[!i] with
	'"' -> Buffer.add_char buf '"'; i := !i + 2
      | c -> Buffer.add_char buf c; i := !i + 1
  done;
  Buffer.contents buf

(*
let tokenize_args =
  COLLECT '"' (([^'"']|"\"\"")* as x := unquote) '"'
        | ([^space '"']+ as x) -> x
*)
(*
  RE_STR '"' ([^'"']|"\"\"")* '"' | [^space '"']+
*)
let tokenize_args =
  let token = Str.regexp "\"\\([^\"]\\|\"\"\\)*\"\\|[^ \"]+" in
  fun s ->
    List.fold_right
    (fun x accu ->
       match x with
	   Str.Delim s ->
	     (if s <> "" && s.[0] = '"' then
		unquote (String.sub s 1 (String.length s - 2))
	      else s) :: accu
	 | _ -> accu)
    (Str.full_split token s) []


let guess_arg1 s =
  match tokenize_args s with
      [s'] when String.length s' >= 1 && s'.[0] <> '-' -> `Script_name
    | l ->
	`Ocamlscript_args (process_ocamlscript_args
			     ~refuse_input:true
			     ~accept_non_option:true l)

(* name of Sys.argv.(0) in the final process (execution of the binary)
   depending on where the source program comes from:
   - from a file: the name of the source file
   - from stdin:
      sh: sh
      perl: -
      python: ""
      ocamlscript: ""
   - from a string:
      sh -c: sh
      perl -e: -e
      python -c: -c
      ocamlscript -e: -e
*)

let main () =
  let script_path_option, script_args =
    match Array.to_list Sys.argv with
	ocamlscript :: (arg1 :: other_args as l) ->
	  (match guess_arg1 arg1 with
	       `Script_name -> (`File (absolute arg1), l)
	     | `Ocamlscript_args (opt1, stopped, hardcoded_script_args) ->
		 let command_line_script_args =
		   let continued_args =
		     match opt1 with
			 None -> other_args
		       | Some o1 -> o1 :: other_args in
		   if stopped then continued_args
		   else
		     let opt1', stopped', command_line_script_args =
	               process_ocamlscript_args continued_args in
                     (match opt1' with
                      | None -> ()
                      | Some x -> failwith
                                    (sprintf "%s option expects an argument" x));
		     command_line_script_args in
		 match !Opt.from with
		     Some `Stdin ->
		       (`Stdin,
			"" ::
			  (hardcoded_script_args @ command_line_script_args))
		   | Some (`String s) ->
		       (`String s,
			"-e" ::
			  (hardcoded_script_args @ command_line_script_args))
		   | Some (`File s) -> assert false
		   | None ->
		       match command_line_script_args with
			   [] ->
			     Opt.set "source" Opt.from `Stdin;
			     (`Stdin,
			      "" :: hardcoded_script_args)
			 | script_name :: l ->
			     Opt.set "source" Opt.from (`File script_name);
			     (`File (absolute script_name),
			      script_name :: (hardcoded_script_args @ l)))
      | [_] | [] ->
	  Opt.set "source" Opt.from `Stdin;
	  (`Stdin, [""]) in

  if !Opt.help then
    print_string Opt.help_message
  else if !Opt.version then
    print_endline Version.version
  else
    let bin = obin_name script_path_option in
    let log = if !Opt.debug then Some stdout else None in
    let compilation_status =
      if !Opt.f || needs_recompile script_path_option then
	let status = compile_script ?log script_path_option in
        Pipeline.maybe_log log "compilation exit status: %i\n%!" status;
	status
      else 0 in

    if compilation_status = 0 && not !Opt.c then
      let real_bin, real_args =
	match !Opt.vm with
	    None -> bin, script_args
	  | Some vm -> vm, (bin :: List.tl script_args) in
      Unix.execv real_bin (Array.of_list real_args)
    else (* includes the case where there is non-writeable executable *)
      exit compilation_status

let _ =
  try main ()
  with Failure s ->
    eprintf "ocamlscript: %s\n%!" s;
    exit 2
