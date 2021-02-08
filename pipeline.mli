(** Portable command pipeline *)

type command

(** A given pipeline always executes the same commands from a given temporary
  directory. The input files have been copied into the directory by the time
  the execution starts. After execution, the output files are copied
  to some specified location and then the directory is removed. *)
type pipeline = {
  input : string list; (** internal names of the input files *)
  output : string list; (** internal names of the result files *)
  commands : command list; (** commands which operate on the 
                               internal file names *)
}

(** [command ?stdin ?stdout l] creates a command which redirects stdin and
  stdout to the given files, if these options are used.
  For example, [command ~stdout:"bigfile" ["cat"; "file1"; "file2"]]
  is equivalent to the shell command [cat file1 file2 > bigfile]. *)
val command : ?stdin:string -> ?stdout:string -> string list -> command

(** [run ~input ~output pip] executes the given pipeline [pip] by
  instanciating the internal file names used in the pipeline using
  input and output files.
  For example, a pipeline [pip] which works on one input file named file1
  and on one output file named file2 would be executed using
  [run ~input:["file1", any_input_file] 
  ~output:["file2", any_output_file] pip].
  The [log] option can be used to collect information for debugging. *)
val run :
  ?log:out_channel ->
  ?before:(unit -> unit) ->
  ?after:(unit -> unit) ->
  ?input:(string * string) list ->
  ?output:(string * string) list -> pipeline -> int
    
(**/**)

val remove : ?log:out_channel -> string -> unit
val copy_file : 
  ?log:out_channel -> ?head:string -> ?tail:string -> ?force:bool ->
  string -> string -> unit
val run_command : ?log:out_channel -> command -> int

val maybe_log : out_channel option -> ('a, out_channel, unit) format -> 'a
