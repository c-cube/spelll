(lang dune 2.0)
(generate_opam_files true)

(name spelll)
(maintainers c-cube)
(authors c-cube)

(source (github c-cube/spelll))
(license BSD-2-Clause)
(version 0.4)

(package
  (name spelll)
  (synopsis "Fuzzy string searching, using Levenshtein automaton")
  (depends (ocaml (>= 4.08)) seq (qcheck :with-test)
           (mdx :with-test)
           (odoc :with-doc)))
