
SOURCES = main.ml
RESULT = confluence_site_converter
PACKS = str core ppx_let lwt cohttp cohttp-lwt-unix cohttp-lwt threads ssl lambdasoup yojson
THREADS=yes

include OCamlMakefile
