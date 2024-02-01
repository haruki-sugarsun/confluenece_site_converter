Confluence Site Converter
=========================

# Environment
(confirmed on 2024-02-01)
- OCaml 4.14.1
  - with https://opam.ocaml.org/doc/Usage.html#opam-switch `opam switch create 4.14.1`
  - We have some dependencies in libraries to the older version of OCaml and specific old lib version.
- Core v0.14.1
  - v0.14 → v0.15 splitted the modules
  - https://github.com/janestreet/core_unix/blob/v0.15/core_unix/src/core_unix.ml#L1455 
  - and had a breaking change. My current code supports v0.14,

# Setup
```
$ opam switch create 4.14.1
$ eval $(opam env --switch=4.14.1)
```

Maybe required in some environment (for me WSL2 Debian with brew)
```
$ brew unlink openssl
$ brew unlink pkg-config
```

```
$ opam install core.v0.14.1 ppx_let tls-lwt lwt cohttp cohttp-lwt-unix cohttp-lwt ssl lambdasoup yojson
or reinstall
$ make
```


# Concept
* ~~~

## API dependency
API simply following https://developer.atlassian.com/cloud/confluence/basic-auth-for-rest-apis/
and use https://developer.atlassian.com/cloud/confluence/rest/api-group-content/#api-wiki-rest-api-content-id-get
to fetch content.

## Used libraries
* <https://github.com/mirage/ocaml-cohttp>
* <https://github.com/aantron/lambdasoup>



Task Roadmap: (roughly ordered by dependency)
* Apply command line option parser.
* Write the architectural thing in README.
* Parse JSON content.
* Parse HTML content
* Traverse the tree and output the metadata to JSON files in working directory.
* first start from just generating the <PAGE_ID>.html files and put it?
* Convert the files into my own styled ones.
* Apply node-by-node conversion to have some specific features.
  * e.g. link each other pages by page IDs.



# Tips for development
make clean && ls | entr sh -c 'clear; make && ./confluence_site_converter'

## OCaml package management
* https://opam.ocaml.org/

---
We need the following packages:
$ opam install cohttp-lwt-unix cohttp-async lambdasoup yojson lwt_ssl



- Brief direction
- reuse body.view as much as possible.
process the DOM tree a little.

links <a> should be processed apparently.
