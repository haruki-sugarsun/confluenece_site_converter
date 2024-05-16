find bin/ lib/ test/ | entr -r sh -c 'echo -----START; dune test && dune exec confluence_site_converter -- 500 confluence_site_converter.opam'
