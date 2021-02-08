
open Printf
open Unix

(*
   - input: list of files which are copied from the base directory
   to a temporary directory
   - output: list of files which are copied from the temporary directory
   to the base directory
   - the current directory is set to the temporary directory during
   the execution of the pipeline
*)

type command = { args : string list;
		 stdin : string option;
		 stdout : string option }

type pipeline = { input : string list;
		  output : string list;
		  commands : command list }

let ( // ) = Filename.concat
let ( @@ ) a b = if Filename.is_relative b then a // b else b

let command ?stdin ?stdout args = { args = args;
				    stdin = stdin;
				    stdout = stdout }

let prng = Random.State.make_self_init ();;

let temporary_directory =
  match Sys.os_type with
  | "Unix" | "Cygwin" -> (try Sys.getenv "TMPDIR" with Not_found -> "/tmp")
  | "Win32" -> (try Sys.getenv "TEMP" with Not_found -> ".")
  | _ -> assert false

let temp_file_name prefix suffix =
  let rnd = (Random.State.bits prng) land 0xFFFFFF in
  temporary_directory // (sprintf "%s%06x%s" prefix rnd suffix)

let temp_dir prefix suffix =
  let rec try_name counter =
    let name = temp_file_name prefix suffix in
    try
      mkdir name 0o700;
      name
    with Unix_error _ as e ->
      if counter >= 1000 then raise e else try_name (counter + 1)
  in try_name 0

let stderr_out_chan = Unix.out_channel_of_descr stderr

let maybe_log maybe_out fmt =
  (match maybe_out with
   | Some out -> fprintf out
   | None -> ifprintf stderr_out_chan) fmt

(* rm -rf *)
let rec remove ?log file =
  try
    let st = stat file in
    match st.st_kind with
    | S_DIR ->
      Array.iter (fun name -> remove (file // name)) (Sys.readdir file);
      maybe_log log "remove directory %S\n%!" file;
      rmdir file
    | S_REG
    | S_CHR
    | S_BLK
    | S_LNK
    | S_FIFO
    | S_SOCK ->
      maybe_log log "remove file %S\n%!" file;
      Sys.remove file
  with _e -> ()


(* like Sys.command, but without shell interpretation *)
let array_command ?stdin ?stdout prog args =
  let real_stdin, close_stdin =
    match stdin with
    | None -> Unix.stdin, false
    | Some file -> Unix.openfile file [Unix.O_RDONLY] 0, true in
  let real_stdout, close_stdout =
    match stdout with
    | None -> Unix.stdout, false
    | Some file ->
      Unix.openfile file
	[Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC] 0o600, true in
  let pid = Unix.create_process prog args real_stdin real_stdout Unix.stderr in
  let pid', process_status = Unix.waitpid [] pid in
  assert (pid = pid');
  if close_stdin then
    (try Unix.close real_stdin with _ -> ());
  if close_stdout then
    (try Unix.close real_stdout with _ -> ());
  match process_status with
  | Unix.WEXITED n -> n
  | Unix.WSIGNALED _ -> 2 (* like OCaml's uncaught exceptions *)
  | Unix.WSTOPPED _ ->
    (* only possible if the call was done using WUNTRACED
       or when the child is being traced *)
    assert false

let concat_cmd cmd = String.concat " " cmd.args

let run_command ?log cmd =
  match cmd.args with
  | [] ->
    maybe_log log "empty command\n%!"; 0
  | prog :: _ ->
    maybe_log log "%s: %s\n%!" prog (concat_cmd cmd);
    let status =
      array_command ?stdin:cmd.stdin ?stdout:cmd.stdout
	prog (Array.of_list cmd.args) in
    maybe_log log "exit status %i\n%!" status;
    status

let exec ?log cmd =
  maybe_log log "%s\n%!" (concat_cmd cmd);
  let status = run_command cmd in
  maybe_log log "exit status %i\n%!" status;
  status

let copy_file ?log ?(head = "") ?(tail = "") ?(force = false) src dst =
  maybe_log log "copy %S to %S\n%!" src dst;
  if not force && Sys.file_exists dst then
    invalid_arg
      (sprintf "Pipeline.copy_file: destination file %s already exists" dst);
  let ic = open_in_bin src in
  Fun.protect (fun () ->
      let oc = open_out_bin dst in
      Fun.protect (fun () ->
          try
            output_string oc head;
            while true do
              output_char oc (input_char ic)
	    done
          with End_of_file -> output_string oc tail
        )
        ~finally:(fun () ->
            close_out_noerr oc;
            let perm = (stat src).st_perm in
            chmod dst perm
          )
    )
    ~finally:(fun () -> close_in_noerr ic)

let copy_files ?log ?force src dst l =
  List.iter
    (fun (src_name, dst_name) ->
       copy_file ?log ?force (src @@ src_name) (dst @@ dst_name))
    l

let match_files names settings =
  let tbl = Hashtbl.create 10 in
  List.iter (fun id -> Hashtbl.replace tbl id None) names;
  List.iter (fun (id, s) -> Hashtbl.replace tbl id (Some s)) settings;
  let pairs =
    Hashtbl.fold (fun id opt l ->
	let x =
	  match opt with
          | None -> (id, id)
	  | Some s -> (id, s) in
	x :: l) tbl [] in
  pairs

let flip (a, b) = (b, a)

let run ?log
    ?(before = fun () -> ()) ?(after = fun () -> ())
    ?(input = []) ?(output = []) p =
  let rec loop l =
    match l with
    | [] -> 0
    | cmd :: rest when cmd.stdin = None && cmd.stdout = None ->
      (try
	 let status = exec ?log cmd in
	 if status = 0 then loop rest
	 else status
       with _ -> 127)
    | _ -> failwith "IO redirections: not implemented" in
  let dir = temp_dir "ocamlpipeline" "" in
  Fun.protect
    (fun () ->
       let base = Sys.getcwd () in
       maybe_log log "change directory %S\n%!" dir;
       Sys.chdir dir;
       before ();
       copy_files ?log base dir (List.map flip (match_files p.input input));
       let status = loop p.commands in
       maybe_log log "change directory %S\n%!" base;
       after ();
       Sys.chdir base;
       maybe_log log "command pipeline exits with status %i\n%!" status;
       if status = 0 then
         copy_files ?log ~force:true dir base (match_files p.output output);
       status
    )
    ~finally:(fun () -> remove ?log dir)
