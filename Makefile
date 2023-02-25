
SOURCES = main.ml
RESULT = confluence_site_converter
PACKS = str core ppx_let lwt cohttp cohttp-lwt-unix cohttp-lwt threads ssl lambdasoup yojson
THREADS=yes

include OCamlMakefile

.PHONY: format_files

# process_files: $(FILES)
#     for file in $^; do \
#         echo "Processing $$file"; \
#         your_command_here $$file; \
#     done

format_files: $(SOURCES)
	ocamlformat --inplace --enable-outside-detected-project $(SOURCES)
