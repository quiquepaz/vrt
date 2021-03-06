open Core.Std
open Async.Std

type error = No_aws_user
exception Copy_error of error

let do_scp logger identity ip target remote =
  Async_shell.sh "scp -i %s ubuntu@%s:%s %s" identity ip remote target
  >>= fun _ ->
  return @@ Ok ()

let do_copy ~log_level ~target ~remote =
  let open Deferred.Result.Monad_infix in
  let logger = Vrt_common.Logging.create log_level in
  let actual_target = match target with
    | Some target -> target
    | None -> "." in
  Prj_vagrant.project_root ()
  >>= fun project_root ->
  Log.info logger "Project root is %s" project_root;
  Log.info logger "Starting vagrant ...";
  Vrt_common.Logging.flush logger
  >>= fun _ ->
  Prj_vagrant.start_vagrant project_root
  >>= fun ip ->
  Log.info logger "Remote IP is %s" ip;
  Log.info logger "Getting identity ";
  Vrt_common.Aws.identity ()
  >>= fun identity ->
  Log.info logger "Doing copy";
  do_scp logger identity ip actual_target remote
  >>= fun _ ->
  Log.info logger "Copy complete to %s" actual_target;
  Vrt_common.Logging.flush logger

let spec =
  let open Command.Spec in
  empty
  +> Vrt_common.Logging.flag
  +> flag ~aliases:["-t"] "--target" (optional string)
    ~doc:"the local target file or directory that the remote file will be copied into"
  +> anon ("remote" %: string)

let name = "copy-local"

let command =
  Command.async_basic
    ~summary:"Copies a remote file to the local disk if it exists"
    spec
    (fun log_level target remote () ->
       Vrt_common.Cmd.result_guard
         (fun _ -> do_copy ~log_level ~target ~remote))

let desc = (name, command)
