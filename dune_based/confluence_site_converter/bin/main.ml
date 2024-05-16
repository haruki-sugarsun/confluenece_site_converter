open Core
open Confluence_site_converter.Configuration

(* Main entry point *)
let main config =
  (match config.run_mode with
  | PROCESS_TREE root_id ->
      let _ = root_id in
      printf "   *****   START Process Tree mode!\n"
      (* fetch_pages_tree config config.root_page_id *)
  | PROCESS_ONE target ->
      let _ = target in
      printf "   *****   START Process One mode!\n" (* TODO: Implement. *));
  printf "   *****   FINISHED!\n"

(* CLI interfave *)
let command =
  Command.basic ~summary:"Tool to import Confluence pages into Jekyll site."
    ~readme:(fun () ->
      "Visit https://github.com/haruki-sugarsun/confluenece_site_converter for \
       more detailed information.")
    (let open Command.Let_syntax in
     let open Command.Param in
     let%map confluence_domain = flag ~doc:"domain" "--domain" (required string)
     and confluence_user = flag ~doc:"user" "--user" (required string)
     and confluence_password =
       flag ~doc:"password" "--password" (required string)
     and root_page_id =
       flag ~doc:"Page ID of the root" "--root-page-id" (required string)
     and process_one_target_id =
       flag ~doc:"TODO: write" "--process-one-target-id" (required string)
     and sleep_duration_per_fetch =
       flag ~doc:"TODO: write" "--sleep" (required int)
     and use_cache = flag ~doc:"TODO: write" "--cache" (required bool)
     and local_cache_dir =
       flag ~doc:"TODO: write" "--cache-dir" (required string)
     and local_output_dir =
       flag ~doc:"TODO: write" "--output-dir" (required string)
     in
     fun () ->
       print_endline "AAA";
       (* Build a configuration *)
       (* Printf.printf "process_one_target_id %s\n" process_one_target_id ; *)
       let run_mode =
         match process_one_target_id with
         | "-" -> PROCESS_TREE root_page_id
         | _ -> PROCESS_ONE process_one_target_id
       in
       let c =
         {
           confluence_domain : string;
           confluence_user : string;
           confluence_password : string;
           root_page_id : string;
           run_mode : run_mode;
           sleep_duration_per_fetch : int;
           use_cache : bool;
           local_cache_dir : string;
           local_output_dir : string;
         }
       in

       (* Run the Application *)
       Format.printf "Confluence Site Converter starting with the config: {\n";
       Format.printf "  confluence_user: %s\n" c.confluence_user;
       Format.printf "  confluence_password: *** (masked)\n";
       Format.printf "  root_page_id: %s\n" c.root_page_id;
       Format.printf "  sleep_duration_per_fetch: %d\n"
         c.sleep_duration_per_fetch;
       Format.printf "  run_mode: %a\n" pp_run_mode c.run_mode;
       Format.printf "  use_cache: %b\n" c.use_cache;
       Format.printf "  local_cache_dir: %s\n" c.local_cache_dir;
       Format.printf "  local_output_dir: %s\n" c.local_output_dir;
       Format.printf "}\n";

       main c)

let () = Command_unix.run ~version:"1.0" ~build_info:"RWO" command
