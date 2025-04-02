(lang dune 2.0)
(generate_opam_files true)

(name spelll)
(source (github c-cube/spelll))
(license BSD-2-Clause)
(version 0.4)

(package
  (name spelll)
  (depends (ocaml (>= 4.08)) seq (qcheck :with-test)
           (ocaml-mdx :with-test)
           (odoc :with-doc)))
