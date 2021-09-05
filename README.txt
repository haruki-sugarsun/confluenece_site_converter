Confluence Site Converter
=========================


# Concept
* ~~~

## API dependency
API simply following https://developer.atlassian.com/cloud/confluence/basic-auth-for-rest-apis/

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
