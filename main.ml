open Core
open Format
open Lwt
open Cohttp
open Cohttp_lwt_unix
open Soup
open Yojson

(* Types and Configurations. *)
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

(* Intermedium Data *)
type fetch_result = { page_id : string (* target ID *) }
type analyze_result = { page_id : string (* target ID *) }
type convert_result = { page_id : string (* target ID *) }
type process_result = { page_id : string (* target ID *) }

let pp_fetch_result fmt r = Format.fprintf fmt "fetch_result{%s}" ""
let pp_convert_result fmt r = Format.fprintf fmt "convert_result{%s}" ""
let pp_process_result fmt r = Format.fprintf fmt "process_result{%s}" ""

(* Utils for General *)
let write_to_file body filename =
  (*TODO: have a better typing. *)
  let oc = open_out filename in
  Printf.fprintf oc "%s\n" body;
  (* TODO: Make it simpler *)
  close_out oc

let read_from_file filename =
  (*TODO: have a better typing. *)
  let ic = open_in filename in
  let s = really_input_string ic (in_channel_length ic) in
  close_in ic;
  s

let copy_file from_filename to_filename =
  (*TODO: have a better typing. *)
  let body = read_from_file from_filename in
  write_to_file body to_filename

let at_mark_regexp = Str.regexp "@"

(* Utils for fetching phase. *)
let basic_auth_pair conf =
  let encoded_user =
    Str.global_replace at_mark_regexp "%40" conf.confluence_user
  in
  String.concat ~sep:":" [ encoded_user; conf.confluence_password ]

(* https://developer.atlassian.com/cloud/confluence/rest/api-group-content/#api-wiki-rest-api-content-id-get *)
let build_uri_of_page_id conf page_id =
  let user_token_pair_str = basic_auth_pair conf in
  Uri.of_string
    (String.concat
       [
         "https://";
         user_token_pair_str;
         "@";
         conf.confluence_domain;
         "/wiki/rest/api/content/";
         page_id;
         "?expand=body.view,children.page,history.lastUpdated,version,ancestors,metadata.labels";
       ])

(* Utils for convert phase. *)
let yaml_dbquote text = "\"" ^ text ^ "\""

let build_jekyll_front_matter_string json =
  (* TODO: Better Error Handling *)
  let open Yojson.Safe.Util in
  (* local open *)
  let title = json |> member "title" |> to_string in
  let last_updated =
    json |> member "history" |> member "lastUpdated" |> member "when"
    |> to_string
  in
  printf "last_updated: %s\n" last_updated;
  let label_objs =
    json |> member "metadata" |> member "labels" |> member "results" |> to_list
  in
  let labels =
    List.map label_objs (member "name") |> fun l -> List.map l to_string
  in
  let kv_list =
    [
      ("layout", "single");
      ("title", yaml_dbquote title);
      ("date", yaml_dbquote last_updated);
      ("toc", "true");
      ("toc_sticky", "true");
    ]
  in
  String.concat ~sep:"\n"
    (List.concat
       [
         [ "---" ];
         (* general key-values*)
         List.map kv_list (fun (k, v) -> k ^ ": " ^ v);
         (* tags as list. Labels are `tags` in Jekyll. *)
         [ "tags:" ];
         List.map labels (fun l -> "  - " ^ l);
         [ "---"; "" ];
       ])

(* Easy Tools *)
(* https://github.com/mirage/ocaml-cohttp#dealing-with-redirects *)
let rec http_get_and_follow ~max_redirects uri =
  let open Lwt.Syntax in
  let* ans = Cohttp_lwt_unix.Client.get uri in
  follow_redirect ~max_redirects uri ans

and follow_redirect ~max_redirects request_uri (response, body) =
  let open Lwt.Syntax in
  let status = Cohttp.Response.status response in
  (* The unconsumed body would otherwise leak memory *)
  let* () =
    if Poly.(status <> `OK) then Cohttp_lwt.Body.drain_body body
    else Lwt.return_unit
  in
  match status with
  | `OK -> Lwt.return (response, body)
  | `Permanent_redirect | `Moved_permanently ->
      handle_redirect ~permanent:true ~max_redirects request_uri response
  | `Found | `Temporary_redirect ->
      handle_redirect ~permanent:false ~max_redirects request_uri response
  | `Not_found | `Gone -> Lwt.fail_with "Not found"
  | status ->
      Lwt.fail_with
        (Printf.sprintf "Unhandled status: %s"
           (Cohttp.Code.string_of_status status))

and handle_redirect ~permanent ~max_redirects request_uri response =
  if Poly.(max_redirects <= 0) then Lwt.fail_with "Too many redirects"
  else
    let headers = Cohttp.Response.headers response in
    let location = Cohttp.Header.get headers "location" in
    match location with
    | None -> Lwt.fail_with "Redirection without Location header"
    | Some url ->
        let open Lwt.Syntax in
        let uri = Uri.of_string url in
        let* () =
          if permanent then
            (* TODO: replace with Logger impl *)
            printf "Permanent redirection from %s to %s"
              (Uri.to_string request_uri)
              url;
          Lwt.return_unit
        in
        http_get_and_follow uri ~max_redirects:(max_redirects - 1)

(* Utils for convert phase. *)
(* HTML processing *)
let simple_html_trimmer html_string =
  let node = Soup.parse html_string in
  Soup.pretty_print node

(* Desctuctively and recusively remove attributes
   let rec attr_drop_rec node =
     let top_gnodes = Soup.children node in
     let processed_top = Soup.map (fun n ->
       Soup.fold_attributes (fun _ k v ->
         Soup.delete_attribute k n) () n;
        n
       ) top_gnodes in
     let new_top = Soup.create_soup () in
     Soup.iter (fun n -> Soup.append_root new_top n) processed_top;
     new_top;; *)

let simple_html_attr_dropper html_string =
  let node = Soup.parse html_string in
  printf "before: %s\n" (Soup.pretty_print node);
  Soup.select "*" node
  |> Soup.iter (fun n ->
         Soup.fold_attributes (fun _ k v -> Soup.delete_attribute k n) () n);
  (* let processed_node = attr_drop_rec node in *)
  printf " after: %s\n" (Soup.pretty_print node);
  Soup.pretty_print node

let generate_inner_site_link page_id =
  (* TODO: Implement when we implement URL generation with title. *)
  "/c/" ^ page_id

(* download the file to _CACHE_DIR_/_PAGE_ID_/_FILENAME_ *)
(* TODO: Consider pack the common parameters into a context record type to simplify. *)
let download_resource conf page_id uri filename =
  (* TODO: Implement *)
  if not conf.use_cache then (
    let uri = Uri.with_userinfo uri (Some (basic_auth_pair conf)) in
    let body =
      http_get_and_follow ~max_redirects:1 uri >>= fun (resp, body) ->
      let code = resp |> Response.status |> Code.code_of_status in
      Printf.eprintf "Response code: %d\n" code;
      Printf.eprintf "Headers: %s\n"
        (resp |> Response.headers |> Header.to_string);
      body |> Cohttp_lwt.Body.to_string >|= fun body ->
      Printf.eprintf "Body of length: %d\n" (String.length body);
      body
    in
    let body = Lwt_main.run body in
    (* We can eagarly parse it here? *)
    Core.Unix.mkdir_p (conf.local_cache_dir ^ "/" ^ page_id ^ "/");
    write_to_file body (conf.local_cache_dir ^ "/" ^ page_id ^ "/" ^ filename));
  ()

let a_attr_processor node =
  Soup.fold_attributes
    (fun _ k v ->
      printf "Attr:%s=%s\n" k v;
      if Poly.(k = "data-linked-resource-id") then (
        let new_href = generate_inner_site_link v in
        Soup.set_attribute "href" new_href node;
        printf "Link rewritten to :%s\n" new_href;
        if Poly.(k = "href") then () else Soup.delete_attribute k node))
    () node

(* img tag processor *)
(* Here we just use `src` attr. TODO: Consider handling the visible size? *)
let img_attr_processor conf page_id node =
  let resource_uri_opt = Soup.attribute "src" node in
  let filename_opt = Soup.attribute "data-linked-resource-default-alias" node in
  printf "Img src:%s\n" (Option.value ~default:"" resource_uri_opt);
  match (resource_uri_opt, filename_opt) with
  | Some resource_uri_string, Some filename ->
      let resource_uri = Uri.of_string resource_uri_string in
      printf "Img src:%s\n" resource_uri_string;
      printf "filename:%s\n" filename;

      download_resource conf page_id resource_uri filename;
      (* Make the attachment URL pattern configurable by command line. *)
      Core.Unix.mkdir_p ("./c_attachments/" ^ page_id ^ "/");
      copy_file
        (conf.local_cache_dir ^ "/" ^ page_id ^ "/" ^ filename)
        ("./c_attachments/" ^ page_id ^ "/" ^ filename);
      let new_src = "/c_attachments/" ^ page_id ^ "/" ^ filename in
      Soup.fold_attributes
        (fun _ k v ->
          printf "Attr:%s=%s\n" k v;
          Soup.delete_attribute k node)
        () node;
      Soup.set_attribute "src" new_src node
  | _, _ ->
      printf "Img src or filename missing.\n";
      ()

(* Entrypoint for a whole `document` processing *)
let html_attr_processer conf page_id html_string =
  let node = Soup.parse html_string in
  printf "before: %s\n" (Soup.pretty_print node);
  Soup.select "*" node
  |> Soup.iter (fun n ->
         (* Consider per type handling? *)
         (* Consider extracting into functions? *)
         printf "Tag name:%s\n" (Soup.name n);
         match Soup.name n with
         | "a" -> a_attr_processor n
         | "img" -> img_attr_processor conf page_id n
         | _ ->
             Soup.fold_attributes
               (fun _ k v ->
                 if Poly.(k = "id") then () else Soup.delete_attribute k n)
               () n);
  (* let processed_node = attr_drop_rec node in *)
  printf " after: %s\n" (Soup.pretty_print node);
  Soup.pretty_print node

(* Fetching phase implementations *)
let fetch_one_page conf page_id : fetch_result =
  printf "fetching one page: %s.\n" page_id;
  let content =
    if conf.use_cache then
      (* TODO: Extract cache file path generation .*)
      read_from_file (conf.local_cache_dir ^ "/" ^ page_id ^ ".raw")
    else
      (* https://github.com/mirage/ocaml-cohttp *)
      let targetUrl = build_uri_of_page_id conf page_id in
      let body =
        Client.get targetUrl >>= fun (resp, body) ->
        let code = resp |> Response.status |> Code.code_of_status in
        Printf.eprintf "Response code: %d\n" code;
        Printf.eprintf "Headers: %s\n"
          (resp |> Response.headers |> Header.to_string);
        body |> Cohttp_lwt.Body.to_string >|= fun body ->
        Printf.eprintf "Body of length: %d\n" (String.length body);
        body
      in
      let body = Lwt_main.run body in
      (* Save to cache. *)
      write_to_file body (conf.local_cache_dir ^ "/" ^ page_id ^ ".raw");
      body
  in
  { page_id; content }
(* TODO: implement. *)

(* Analyzing phase implementations *)
let analyze_one_page conf page_id (fetch_result : fetch_result) : analyze_result
    =
  printf "analyzing one page: %s.\n" page_id;
  (* Parse JSON. *)
  let open Yojson.Safe.Util in
  (* local open *)
  let json = Yojson.Safe.from_string fetch_result.content in
  (* List the children *)
  let pages = json |> member "children" |> member "page" |> member "results" in
  (* Printf.printf "children:%s\n" (Yojson.Safe.pretty_to_string pages); *)
  let children_ids =
    List.map (to_list pages) (fun p -> p |> member "id" |> to_string)
  in
  (* TODO: implement. *)
  { page_id; parsed_content = json; children_ids }

(* Converting phase implementations *)
let convert_one_page conf page_id (analyze_result : analyze_result) :
    convert_result =
  (* TODO: implement. *)
  let open Yojson.Safe.Util in
  (* local open *)
  let body_view =
    analyze_result.parsed_content |> member "body" |> member "view"
    |> member "value" |> to_string
  in
  let jekyll_front_matter =
    build_jekyll_front_matter_string analyze_result.parsed_content
  in
  write_to_file
    (jekyll_front_matter ^ html_attr_processer conf page_id body_view)
    (conf.local_output_dir ^ "/" ^ page_id ^ ".html");

  { page_id }

(* (Old) DFS TRAVERSING implementation: process recursively. Fetching all the pages under the root. *)
(* TODO: Have the metadata management. *)
let fetch_page_content conf page_id =
  (* TODO: Replace with direct usage of fetch_one_page. *)
  (* let r = fetch_one_page conf page_id in r.content *)
  if conf.use_cache then
    read_from_file (conf.local_cache_dir ^ "/" ^ page_id ^ ".raw")
  else
    (* https://github.com/mirage/ocaml-cohttp *)
    let targetUrl = build_uri_of_page_id conf page_id in
    let body =
      Client.get targetUrl >>= fun (resp, body) ->
      let code = resp |> Response.status |> Code.code_of_status in
      Printf.eprintf "Response code: %d\n" code;
      Printf.eprintf "Headers: %s\n"
        (resp |> Response.headers |> Header.to_string);
      body |> Cohttp_lwt.Body.to_string >|= fun body ->
      Printf.eprintf "Body of length: %d\n" (String.length body);
      body
    in
    let body = Lwt_main.run body in
    (* We can eagarly parse it here? *)
    write_to_file body (conf.local_cache_dir ^ "/" ^ page_id ^ ".raw");
    body

let rec fetch_pages_tree conf page_id =
  print_endline
    ("fetch_pages_tree ... " ^ page_id ^ " use_cache="
    ^ Bool.to_string conf.use_cache);
  (* fetch and write in the cache *)
  Unix.sleep conf.sleep_duration_per_fetch;
  let body = fetch_page_content conf page_id in
  (* process recursively. *)
  process_content conf page_id body

and process_content conf page_id body =
  print_endline "process_content ...";
  let open Yojson.Safe.Util in
  (* local open *)
  let json = Yojson.Safe.from_string body in
  (* Printf.printf "json:%s\n" (Yojson.Safe.pretty_to_string json); *)
  (* Save the body.view content *)
  (* TODO: Implement proper content filtering and transformation. *)
  let body_view =
    json |> member "body" |> member "view" |> member "value" |> to_string
  in

  let jekyll_front_matter = build_jekyll_front_matter_string json in
  write_to_file
    (jekyll_front_matter ^ html_attr_processer conf page_id body_view)
    (conf.local_output_dir ^ "/" ^ page_id ^ ".html");

  (* List the children *)
  let pages = json |> member "children" |> member "page" |> member "results" in
  Printf.printf "children:%s\n" (Yojson.Safe.pretty_to_string pages);
  List.iter (to_list pages) (fun p ->
      let child_page_id = p |> member "id" |> to_string in
      Printf.printf "stepping in to child:%s\n" child_page_id;
      fetch_pages_tree conf child_page_id);
  () (* XXX *)

(*
  TODO: Redefine the steps and implement.
  process = fetch + analyze + convert
    fetch = content fecth and store in cache
    analyze = analyze the fetched content and return metadata, including children page IDs.
    convert = convert from cahce and produce in output
*)
(* Composed Processing phases implementations *)
let process_one_page conf page_id : process_result =
  let fetch_result = fetch_one_page conf page_id in
  let convert_result = convert_one_page conf page_id in
  printf "fetch_result = %a. convert_result = %a\n" pp_fetch_result fetch_result
    pp_convert_result convert_result;
  (* TODO: implement. *)
  { page_id }

(* TODO: Implement. *)

(*
- body.editor,
- body.anonymous_export_view,
- body.export_view,
- body.storage,
- ,body.styled_view
*)
let main config =
  (* TODO: has params as confuguration? *)
  (match config.run_mode with
  | PROCESS_TREE root_id ->
      printf "   *****   START Process Tree mode!\n";
      fetch_pages_tree config config.root_page_id
  | PROCESS_ONE target ->
      printf "   *****   START Process One mode!\n";
      let result = process_one_page config target in
      printf "process_result = %a\n" pp_process_result result
      (* TODO: Implement. *));
  printf "   *****   FINISHED!\n"

(* Re-process the remaining data? *)
(* TODO: Store the execution metadata? *)

let () =
  Command.basic ~summary:"Tool to import Confluence pages into Jekyll site."
    [%map_open.Command
      let confluence_domain = flag ~doc:"domain" "--domain" (required string)
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
        printf "Confluence Site Converter starting with the config: {\n";
        printf "  confluence_user: %s\n" c.confluence_user;
        printf "  confluence_password: *** (masked)\n";
        printf "  root_page_id: %s\n" c.root_page_id;
        printf "  sleep_duration_per_fetch: %d\n" c.sleep_duration_per_fetch;
        printf "  run_mode: %a\n" pp_run_mode c.run_mode;
        printf "  use_cache: %b\n" c.use_cache;
        printf "  local_cache_dir: %s\n" c.local_cache_dir;
        printf "  local_output_dir: %s\n" c.local_output_dir;
        printf "}\n";

        main c]
  |> Command.run
