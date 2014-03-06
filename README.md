Spelll
======

Fuzzy string searching, using Levenshtein automaton. Can be used for spell-checking.

API documentation can be found [here](http://cedeela.fr/~simon/software/spelll/Spelll.html),
and the source code [here](https://github.com/c-cube/spelll).

Some examples:

````ocaml

    # let dfa = Spelll.of_string ~limit:1 "hello";;
    val dfa : Spelll.automaton = <abstr>
    # Spelll.match_with dfa "hell";;
    - : bool = true
    # Spelll.match_with dfa "hall";;
    - : bool = false
    # let idx = Spelll.Index.of_list ["hello", "world"; "hall", "vestibule"];;
    val idx : string Spelll.Index.t = <abstr>
    # Spelll.Index.retrieve idx ~limit:1 "hell" |> Spelll.klist_to_list;;
    - : string list = ["world"; "vestibule"]
    # Spelll.Index.retrieve idx ~limit:1 "hall" |> Spelll.klist_to_list;;
    - : string list = ["vestibule"]

````


License
-------

This software is free, under the BSD-2 license. See the LICENSE file.

Build
-----

You only need OCaml (>= 3.11 should be enough). Type

    $ make
    $ make install

