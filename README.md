# Spelll [![build](https://github.com/c-cube/spelll/actions/workflows/main.yml/badge.svg)](https://github.com/c-cube/spelll/actions/workflows/main.yml)

Fuzzy string searching, using Levenshtein automaton. Can be used for spell-checking.

API documentation can be found [here](http://c-cube.github.io/spelll/),
and the source code [here](https://github.com/c-cube/spelll).

Some examples:

```ocaml
# #require "spelll";;
# let dfa = Spelll.of_string ~limit:1 "hello";;
val dfa : Spelll.automaton = <abstr>
# Spelll.match_with dfa "hell";;
- : bool = true
# Spelll.match_with dfa "hall";;
- : bool = false
# let idx = Spelll.Index.of_list ["hello", "world"; "hall", "vestibule"];;
val idx : string Spelll.Index.t = <abstr>
# Spelll.Index.retrieve_l idx ~limit:1 "hell" ;;
- : string list = ["world"; "vestibule"]
# Spelll.Index.retrieve_l idx ~limit:1 "hall" ;;
- : string list = ["vestibule"]
```


## License

This software is free, under the BSD-2 license. See the LICENSE file.

## Build

You only need OCaml (>= 4.02 should be enough) and `dune` and `seq`. Type

```
$ make
$ make install
```

