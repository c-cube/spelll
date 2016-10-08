(* quickcheck for Spelll *)

let strg = QCheck.Gen.(string_size ~gen:printable (0--20))
let strarb = QCheck.(string_gen_of_size Gen.(0 -- 20) Gen.printable)

(* test that automaton accepts its string *)
let test_automaton =
  let gen = QCheck.(map_keep_input (Spelll.of_string ~limit:1) strarb) in
  let test (s,a) =
    Spelll.match_with a s
  in
  let name = "string accepted by its own automaton" in
  QCheck.Test.make ~name gen test

(* test that building a from s, and mutating one char of s, yields
   a string s' that is accepted by a *)
let test_mutation =
  (* generate triples (s, i, c) where c is a char, s a non empty string
     and i a valid index in s *)
  let gen = QCheck.Gen.(
    3 -- 10 >>= fun len ->
    int_bound (len-1) >>= fun i ->
    string_size ~gen:printable (return len) >>= fun s ->
    char >>= fun c ->
    return (s,i,c)
  ) in
  let gen =
    QCheck.make
      ~print:QCheck.Print.(triple string int char)
      ~small:(fun (s,_,_)->String.length s) 
      ~shrink:QCheck.Shrink.(triple string int (fun c->QCheck.Iter.empty))
      gen
  in
  let test (s,i,c) =
    let s' = Bytes.of_string s in
    Bytes.set s' i c;
    let a = Spelll.of_string ~limit:1 s in
    Spelll.match_with a (Bytes.to_string s')
  in
  let name = "mutating s.[i] into s' still accepted by automaton(s)" in
  QCheck.Test.make ~name gen test

(* test that, for an index, all retrieved strings are at a distance to
   the key that is not too high *)
let test_index =
  let gen = QCheck.Gen.(
    list_size (1--30) strg >>= fun l ->
    let l = List.map (fun s->s,s) l in
    return (List.map fst l, Spelll.Index.of_list l)
  ) in
  let gen = QCheck.make gen
      ~print:QCheck.Print.(pair (list string) (fun _->"<index>"))
  in
  let test (l, idx) =
    List.for_all
      (fun s ->
        let retrieved = Spelll.Index.retrieve ~limit:2 idx s
          |> Spelll.klist_to_list in
        List.for_all
          (fun s' -> Spelll.edit_distance s s' <= 2) retrieved
      ) l
  in
  let name = "strings retrieved from automaton with limit:n are at distance <= n" in
  QCheck.Test.make ~name gen test

let suite =
  [ 
    test_index;
    test_mutation;
    test_automaton;
  ]

let () =
  QCheck_runner.run_tests_main suite
