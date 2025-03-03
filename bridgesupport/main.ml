open Lib
open Util
open Bridgesupport

module M = Markup
module S = Soup

let fw_name = ref ""

let emit fw x =
  match S.name x with
  | "struct" ->
    let name, lines = emit_struct fw x in
    let file = open_out (Printf.sprintf "data/%s/%s.ml" fw name) in
    emit_prelude ~fw file;
    lines |> List.iter (Printf.fprintf file "%s\n");
    close_out file
  | "constant" -> emit_const x
  | "enum" -> emit_enum x
  | "function" -> emit_func fw x
  | "opaque" -> emit_opaque fw x |> List.iter print_endline
  | "cftype" -> emit_cftype fw x
  | n -> Printf.eprintf "Not emiting %s\n" n
;;

let usage = "bs-to-ml -fw <framework-name> < <FW.bridgesupport>"

let speclist = [ ("-fw", Arg.Set_string fw_name, "Framework name") ]

let emit_funcs_prelude file fw =
  match String.lowercase_ascii fw with
  | "corefoundation" ->
    Printf.fprintf file "open CoreFoundation_globals\n\n"
  | "coregraphics" ->
    Printf.fprintf file "open CoreGraphics_globals\n\n"
  | _ -> ()

let main () =
  Arg.parse speclist ignore usage;
  let fw = !fw_name in
  emit_globals_prelude fw;

  M.channel stdin
  |> M.parse_xml
  |> M.signals
  |> S.from_signals
  |> S.select_one "signatures"
  |> Option.iter (fun x -> S.children x |> S.elements |> S.iter (emit fw));

  emit_funcs () |> function
    | [] -> ()
    | lines ->
      let filename = Printf.sprintf "data/%s/%s_fn.ml" fw fw
      and to_globals = List.length lines < 200
      in
      let file =
        if to_globals then stdout else open_out filename in
      if not to_globals then emit_prelude ~fw file;
      emit_funcs_prelude file fw;
      lines |> List.iter (Printf.fprintf file "%s\n");
      close_out file;

  emit_inlines fw |> function
    | [] -> ()
    | lines ->
      let filename = Printf.sprintf "data/%s/%s_inlines.c" fw fw in
      let file = open_out filename in
      lines |> List.iter (Printf.fprintf file "%s\n");
      close_out file
;;

let () = main ()