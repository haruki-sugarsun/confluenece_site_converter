(* Configurations. *)
type run_mode =
  | PROCESS_TREE of string (* root page ID *)
  | PROCESS_ONE of string (* target page ID *)

let pp_run_mode fmt m =
  match m with
  | PROCESS_TREE root -> Format.fprintf fmt "PROCESS_TREE(%s)" root
  | PROCESS_ONE target -> Format.fprintf fmt "PROCESS_ONE(%s)" target

type configuration = {
  (* Basic auth pair for REST API *)
  confluence_domain : string;
  confluence_user : string;
  confluence_password : string;
  (* Replace or Implement environment variable support. *)
  (* Page structure variables *)
  root_page_id : string; (* TODO: Deprecate in favor of `run_mode`. *)
  run_mode : run_mode;
  (* Behavior varibles *)
  sleep_duration_per_fetch : int;
  (* TODO: We want a cache mode param too. e.g. force_fetch, fetch_if_mod, cache_only*)
  use_cache : bool;
  (* Local filesytem variables *)
  local_cache_dir : string;
  local_output_dir : string;
}
