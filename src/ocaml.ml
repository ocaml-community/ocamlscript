open Printf
open Pipeline
open Utils


let camlp4o = ref "camlp4o"
let camlp4r = ref "camlp4r"
let ocamllex = ref "ocamllex"
let ocamlyacc = ref "ocamlyacc"
let ocamlc = ref "ocamlc"
let ocamlopt = ref "ocamlopt"
let ocamlfind = ref "ocamlfind"

let packs = ref []         (* findlib packages *)
let sources = ref []       (* extra sources *)
let use_ocamllex = ref false (* preprocess with ocamllex before camlp4 *)
let use_camlp4 = ref true  (* by default camlp4 is used *)
let use_ocamlc = ref false (* by default we want native code *)
let use_ocamlfind = ref false (* used only if necessary *)
let revised = ref false    (* use this to use the revised syntax *)
let ocamlflags = Common.extra_args (* any options that you may want to pass
                                      to ocamlopt *)
let ppopt = ref []         (* any options that you may want to pass
                              to camlp4o or camlp4r *)

type pp = string -> (Pipeline.command * string list)

let pp : pp option ref = ref None (* additional preprocessor *)
let ppsrcloc = ref None      (* non-standard source location generator *)



let exe s =
  match Sys.os_type with
  | "Win32" | "Cygwin"->
    if Filename.check_suffix s ".exe" then s
    else s ^ ".exe"
  | "Unix" | _ -> s

let import path =
  let src = !+ path in
  let dst = Filename.basename src in
  let head =
    match !pp, !ppsrcloc, !revised with
    | Some _, Some f, _ -> f src
    | _, _, false -> sprintf "#1 %S;;\n" src
    | _, _, true -> sprintf "#1 %S;\n" src in
  Pipeline.copy_file ~head src dst

(* let ocamllex_command input =
 *   if !use_ocamllex then
 *     Some ((fun () -> ()),
 *           new_cmd [!ocamllex; input;
 *                    "-o"; "ocamlscript_ocamllex_out.ml"; "-q"],
 *           "ocamlscript_ocamllex_out.ml")
 *   else None *)

let file_kind file =
  if Filename.check_suffix file ".mli" then `Mli
  else if Filename.check_suffix file ".ml" then `Ml
  else if Filename.check_suffix file ".mll" then `Mll
  else if Filename.check_suffix file ".mly" then `Mly
  else
    try
      let prefix = Filename.chop_extension file in
      let len = String.length file - String.length prefix in
      `Ext (String.sub file (String.length file - len) len)
    with Invalid_argument _ ->
      `Unknown

let extra_command file =
  match file_kind file with
  | `Mli | `Ml -> ([], [file])
  | `Mll ->
    ([command [!ocamllex; file; "-q"]],
     [(Filename.chop_extension file) ^ ".ml"])
  | `Mly ->
    let p = Filename.chop_extension file in
    ([command [!ocamlyacc; file]],
     [p ^ ".mli"; p ^ ".ml"])
  | `Ext s ->
    failwith (sprintf "don't know how to handle %s files: %s" s file)
  | `Unknown ->
    failwith (sprintf "don't know how to handle this file: %s" file)

let pp_command file =
  match !pp with
  | None -> [], [file]
  | Some f ->
    let cmd, files = f file in
    ([cmd], files)


let extra_commands sources =
  let input_files1 = List.map Filename.basename sources in
  let cmds1, input_files2 = List.split (List.map pp_command input_files1) in
  let cmds2, files =
    List.split (List.map extra_command (List.flatten input_files2)) in
  (List.flatten (cmds1 @ cmds2), List.flatten files)


let ocaml_command input =
  let really_use_ocamlfind =
    match !use_ocamlfind, !packs with
    | true, _ | _, _ :: _ -> true
    | _ -> false in
  let compiler =
    if really_use_ocamlfind then
      if !use_ocamlc then [!ocamlfind; "ocamlc"]
      else [!ocamlfind; "ocamlopt"]
    else if !use_ocamlc then [!ocamlc]
    else [!ocamlopt] in

  let flags = !ocamlflags in
  let camlp4_stuff =
    if !use_camlp4 then
      let syntax, camlp4 =
	if !revised then "camlp4r", !camlp4r
	else "camlp4o", !camlp4o in
      let ppoptions =
	if !ppopt = [] then []
	else
	if really_use_ocamlfind then
	  List.flatten (List.map (fun s -> ["-ppopt"; s]) !ppopt)
	else !ppopt in
      if really_use_ocamlfind then
	"-syntax" :: syntax :: ppoptions
      else
	let space = function | "" -> "" | s -> " " ^ s in
	["-pp"; sprintf "'%s%s'" camlp4 (space (String.concat " " ppoptions))]
    else [] in
  let packages =
    if really_use_ocamlfind then
      ["-linkpkg"; "-package";
       String.concat ","
	 (if !use_camlp4 && not (List.mem "camlp4" !packs) then
	    "camlp4" :: !packs
	  else !packs) ]
    else [] in

  let extra_sources = !sources in
  let init () = List.iter import extra_sources in
  let all_sources = extra_sources @ [input] in

  let xcommands, all_ml_files = extra_commands all_sources in

  let args = compiler @ "-o" :: "prog" ::
	                flags @ camlp4_stuff @ packages @ all_ml_files in
  (init, xcommands, command args, exe "prog")


let compile source result =
  let internal_input =
    if !use_ocamllex then "ocamlscript_main.mll"
    else "ocamlscript_main.ml" in

  let before, xcommands, main_command, internal_output =
    ocaml_command internal_input in
  let input = [internal_input, source] in
  let output = [internal_output, exe result] in
  let log = if !Common.verbose then Some stdout else None in
  run ?log ~before ~input ~output
    { input = [internal_input];
      output = [internal_output];
      commands = xcommands @ [main_command] }
