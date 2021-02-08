let ( // ) = Filename.concat
let ( !+ ) path =
  if Filename.is_relative path then !Common.script_dir // path
  else path
