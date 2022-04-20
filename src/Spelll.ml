
(* this file is part of Spelll. See `opam` for the license. *)

(** {1 Levenshtein distance} *)

module type STRING = sig
  type char_
  type t

  val of_list : char_ list -> t
  val get : t -> int -> char_
  val length : t -> int
  val compare_char : char_ -> char_ -> int
end

let list_of_seq s =
  let l = Seq.fold_left (fun acc x->x::acc) [] s in
  List.rev l

module type S = sig
  type char_
  type string_

  (** {6 Edit Distance} *)

  val edit_distance : string_ -> string_ -> int
  (** Edition distance between two strings. This satisfies the classical
      distance axioms: it is always positive, symmetric, and satisfies
      the formula [distance a b + distance b c >= distance a c] *)

  (** {6 Automaton}
      An automaton, built from a string [s] and a limit [n], that accepts
      every string that is at distance at most [n] from [s]. *)

  type automaton
  (** Levenshtein automaton *)

  val of_string : limit:int -> string_ -> automaton
  (** Build an automaton from a string, with a maximal distance [limit].
      The automaton will accept strings whose {!edit_distance} to the
      parameter is at most [limit]. *)

  val of_list : limit:int -> char_ list -> automaton
  (** Build an automaton from a list, with a maximal distance [limit] *)

  val debug_print : (out_channel -> char_ -> unit) ->
    out_channel -> automaton -> unit
  (** Output the automaton's structure on the given channel. *)

  val match_with : automaton -> string_ -> bool
  (** [match_with a s] matches the string [s] against [a], and returns
      [true] if the distance from [s] to the word represented by [a] is smaller
      than the limit used to build [a] *)

  (** {6 Index for one-to-many matching} *)

  module Index : sig
    type 'b t
    (** Index that maps strings to values of type 'b. Internally it is
        based on a trie. A string can only map to one value. *)

    val empty : 'b t
    (** Empty index *)

    val is_empty : _ t -> bool

    val add : 'b t -> string_ -> 'b -> 'b t
    (** Add a pair string/value to the index. If a value was already present
        for this string it is replaced. *)

    val remove : 'b t -> string_ -> 'b t
    (** Remove a string (and its associated value, if any) from the index. *)

    val retrieve : limit:int -> 'b t -> string_ -> 'b Seq.t 
    (** Lazy list of objects associated to strings close to the query string *)

    val retrieve_l : limit:int -> 'b t -> string_ -> 'b list
    (** List of objects associated to strings close to the query string
        @since 0.3 *)

    val of_list : (string_ * 'b) list -> 'b t
    (** Build an index from a list of pairs of strings and values *)

    val to_list : 'b t -> (string_ * 'b) list
    (** Extract a list of pairs from an index *)

    val fold : ('a -> string_ -> 'b -> 'a) -> 'a -> 'b t -> 'a
    (** Fold over the stored pairs string/value *)

    val iter : (string_ -> 'b -> unit) -> 'b t -> unit
    (** Iterate on the pairs *)

    val to_seq : 'b t -> (string_ * 'b) Seq.t
    (** Conversion to an iterator
        @since 0.3 *)
  end
end

module Make(Str : STRING) = struct
  type string_ = Str.t
  type char_ = Str.char_

  let edit_distance s1 s2 =
    if Str.length s1 = 0
    then Str.length s2
    else if Str.length s2 = 0
    then Str.length s1
    else if s1 = s2
    then 0
    else begin
      (* distance vectors (v0=previous, v1=current) *)
      let v0 = Array.make (Str.length s2 + 1) 0 in
      let v1 = Array.make (Str.length s2 + 1) 0 in
      (* initialize v0: v0(i) = A(0)(i) = delete i chars from t *)
      for i = 0 to Str.length s2 do
        v0.(i) <- i
      done;
      (* main loop for the bottom up dynamic algorithm *)
      for i = 0 to Str.length s1 - 1 do
        (* first edit distance is the deletion of i+1 elements from s *)
        v1.(0) <- i+1;

        (* try add/delete/replace operations *)
        for j = 0 to Str.length s2 - 1 do
          let cost = if Str.compare_char (Str.get s1 i) (Str.get s2 j) = 0 then 0 else 1 in
          v1.(j+1) <- min (v1.(j) + 1) (min (v0.(j+1) + 1) (v0.(j) + cost));
        done;

        (* copy v1 into v0 for next iteration *)
        Array.blit v1 0 v0 0 (Str.length s2 + 1);
      done;
      v1.(Str.length s2)
    end

  module NDA = struct
    type char =
      | Any
      | Char of char_
    type transition =
      | Success
      | Upon of char * int * int
      | Epsilon of int * int

    (* non deterministic automaton *)
    type t = transition list array array

    let length (nda:t) = Array.length nda

    let rec mem_tr tr l = match tr, l with
      | _, [] -> false
      | Success, Success::_ -> true
      | Epsilon (i,j), Epsilon(i',j')::_ -> i=i' && j=j'
      | Upon (Any,i,j), Upon(Any,i',j')::_ when i=i' && j=j' -> true
      | Upon (Char c,i,j), Upon(Char c',i',j')::_
        when Str.compare_char c c' = 0 && i=i' && j=j' -> true
      | _, _::l' -> mem_tr tr l'

    (* build NDA from the string *)
    let make ~limit s =
      let len = Str.length s in
      let m = Array.make_matrix (len +1) (limit+1) [] in
      let add_transition i j tr =
        if not (mem_tr tr m.(i).(j))
        then m.(i).(j) <- tr :: m.(i).(j)
      in
      (* internal transitions *)
      for i = 0 to len-1 do
        for j = 0 to limit do
          (* correct char *)
          add_transition i j (Upon (Char (Str.get s i), i+1, j));
          (* other transitions *)
          if j < limit then begin
            (* substitution *)
            add_transition i j (Upon (Any, i+1, j+1));
            (* deletion in indexed string *)
            add_transition i j (Upon (Any, i, j+1));
            (* addition to indexed string *)
            add_transition i j (Epsilon (i+1, j+1));
          end
        done
      done;
      for j = 0 to limit do
        (* deletions at the end *)
        if j < limit
        then add_transition len j (Upon (Any, len, j+1));
        (* win in any case *)
        add_transition len j Success;
      done;
      m

    let get nda (i,j) =
      nda.(i).(j)

    let is_final nda (i,j) =
      List.exists
        (function Success -> true | _ -> false)
        (get nda (i,j))
  end

  (** deterministic automaton *)
  module DFA = struct
    type t = {
      mutable transitions : (char_ * int) list array;
      mutable is_final : bool array;
      mutable otherwise : int array;  (* transition by default *)
      mutable len : int;
    }

    let create size = {
      len = 0;
      transitions = Array.make size [];
      is_final = Array.make size false;
      otherwise = Array.make size ~-1;
    }

    let _double_array ~init a =
      let a' = Array.make (2 * Array.length a) init in
      Array.blit a 0 a' 0 (Array.length a);
      a'

    (* add a new state *)
    let add_state dfa =
      let n = dfa.len in
      (* resize *)
      if n = Array.length dfa.transitions then begin
        dfa.transitions <- _double_array ~init:[] dfa.transitions;
        dfa.is_final <- _double_array ~init:false dfa.is_final;
        dfa.otherwise <- _double_array ~init:~-1 dfa.otherwise;
      end;
      dfa.len <- n + 1;
      n

    let rec __mem_tr tr l = match tr, l with
      | _, [] -> false
      | (c,i), (c',i')::l' ->
        (i=i' && compare c c' = 0)
        || __mem_tr tr l'

    (* add transition *)
    let add_transition dfa i tr =
      if not (__mem_tr tr dfa.transitions.(i))
      then dfa.transitions.(i) <- tr :: dfa.transitions.(i)

    let add_otherwise dfa i j =
      dfa.otherwise.(i) <- j

    let set_final dfa i =
      dfa.is_final.(i) <- true

    (* set of pairs of ints: used for representing a set of states of the NDA *)
    module NDAStateSet = Set.Make(struct
        type t = int * int
        let compare = Stdlib.compare
      end)

    let _set_to_string s =
      let b = Buffer.create 15 in
      Buffer.add_char b '{';
      NDAStateSet.iter
        (fun (x,y) -> Printf.bprintf b "(%d,%d)" x y)
        s;
      Buffer.add_char b '}';
      Buffer.contents b

    (* list of characters that can specifically be followed from the given set *)
    let chars_from_set nda set =
      NDAStateSet.fold
        (fun state acc ->
           let transitions = NDA.get nda state in
           List.fold_left
             (fun acc tr -> match tr with
                | NDA.Upon (NDA.Char c, _, _) ->
                  if List.exists (fun c' -> Str.compare_char c c' = 0) acc
                  then acc
                  else c :: acc (* new char! *)
                | _ -> acc
             ) acc transitions
        ) set []

    (* saturate current set w.r.t epsilon links *)
    let saturate_epsilon nda set =
      let q = Queue.create () in
      NDAStateSet.iter (fun s -> Queue.push s q) set;
      let set = ref set in
      while not (Queue.is_empty q) do
        let state = Queue.pop q in
        (*Printf.printf "saturate epsilon: add state %d,%d\n" (fst state)(snd state);*)
        set := NDAStateSet.add state !set;
        List.iter
          (fun tr' -> match tr' with
             | NDA.Epsilon (i,j) ->
               if not (NDAStateSet.mem (i,j) !set)
               then Queue.push (i,j) q
             | _ -> ()
          ) (NDA.get nda state)
      done;
      !set

    (* find the transition that matches the given char (if any), or "*";
       may raise exceptions Not_found or LeadToSuccess. *)
    let rec get_transition_for_char nda c acc transitions =
      match transitions with
      | NDA.Upon (NDA.Char c', i, j) :: transitions' when Str.compare_char c c' = 0 ->
        (* follow same char *)
        let acc = NDAStateSet.add (i, j) acc in
        get_transition_for_char nda c acc transitions'
      | NDA.Upon (NDA.Any, i, j) :: transitions' ->
        (* follow '*' *)
        let acc = NDAStateSet.add (i,j) acc in
        get_transition_for_char nda c acc transitions'
      | _ :: transitions' -> get_transition_for_char nda c acc transitions'
      | [] ->  acc

    let rec get_transitions_for_any nda acc transitions =
      match transitions with
      | NDA.Upon (NDA.Char _, _, _) :: transitions' ->
        get_transitions_for_any nda acc transitions'
      | NDA.Upon (NDA.Any, i, j) :: transitions' ->
        let acc = NDAStateSet.add (i,j) acc in
        get_transitions_for_any nda acc transitions'
      | _:: transitions' -> get_transitions_for_any nda acc transitions'
      | [] -> acc

    (* follow transition for given NDA.char, returns a new state
       and a boolean indicating whether it's final *)
    let follow_transition nda set c =
      let set' = NDAStateSet.fold
          (fun state acc ->
             let transitions = NDA.get nda state in
             (* among possible transitions, follow the one that matches c
                the most closely *)
             get_transition_for_char nda c acc transitions
          ) set NDAStateSet.empty
      in
      saturate_epsilon nda set'

    let follow_transition_any nda set =
      let set' = NDAStateSet.fold
          (fun state acc ->
             let transitions = NDA.get nda state in
             (* among possible transitions, follow the ones that are labelled with "*" *)
             get_transitions_for_any nda acc transitions
          ) set NDAStateSet.empty
      in
      saturate_epsilon nda set'

    (* call [k] with every [transition'] that can be reached from [set], with
       a bool that states whether it's final *)
    let iterate_transition_set nda set k =
      (*Printf.printf "iterate_transition at set %s\n" (_set_to_string set);*)
      (* all possible "fixed char" transitions *)
      let chars = chars_from_set nda set in
      List.iter
        (fun c ->
           (*Printf.printf "iterate_transition follows %c (at %s)\n"
             (Obj.magic c) (_set_to_string set);*)
           let set' = follow_transition nda set c in
           if not (NDAStateSet.is_empty set')
           then k (NDA.Char c) set';
        ) chars;
      (* remaining transitions, with only "Any" *)
      (*Printf.printf "iterate transition follows * (at %s)\n" (_set_to_string set);*)
      let set' = follow_transition_any nda set in
      if not (NDAStateSet.is_empty set')
      then k NDA.Any set'

    module StateSetMap = Map.Make(NDAStateSet)

    (* get the state that corresponds to the given set of NDA states.
       [states] is a map [nda set] -> [nfa state] *)
    let get_state dfa states set =
      try StateSetMap.find set !states
      with Not_found ->
        let i = add_state dfa in
        states := StateSetMap.add set i !states;
        i

    (* traverse the NDA. Currently we're at [set] *)
    let rec traverse nda dfa states set =
      let set_i = get_state dfa states set in
      (* does this set lead to success? *)
      let is_final = NDAStateSet.exists (NDA.is_final nda) set in
      if is_final
      then set_final dfa set_i;
      iterate_transition_set nda set
        (fun c set' ->
           (*Printf.printf "traverse %s --%c--> %s\n" (_set_to_string set)
             (match c with NDA.Char c' -> Obj.magic c' | NDA.Any -> '*')
             (_set_to_string set');*)
           let set_i' = get_state dfa states set' in
           (* link set -> set' *)
           match c with
           | NDA.Char c' ->
             add_transition dfa set_i (c', set_i');
             traverse nda dfa states set'
           | NDA.Any ->
             add_otherwise dfa set_i set_i';
             traverse nda dfa states set'
        )

    let of_nda nda =
      let dfa = create (NDA.length nda) in
      (* map (set of NDA states) to int (state in DFA) *)
      let states = ref StateSetMap.empty in
      (* traverse the NDA to build the NFA *)
      let set = NDAStateSet.singleton (0,0) in
      let set = saturate_epsilon nda set in
      traverse nda dfa states set;
      (*StateSetMap.iter
        (fun set i ->
          Printf.printf "set %s --> state %d\n" (_set_to_string set) i
        ) !states;*)
      dfa

    let get dfa i =
      dfa.transitions.(i)

    let otherwise dfa i =
      dfa.otherwise.(i)

    let is_final dfa i =
      dfa.is_final.(i)
  end

  let debug_print pp_char oc dfa =
    Printf.fprintf oc "automaton of %d states\n" dfa.DFA.len;
    for i = 0 to dfa.DFA.len-1 do
      let transitions = DFA.get dfa i in
      if DFA.is_final dfa i
      then Printf.fprintf oc "  success %d\n" i;
      List.iter
        (fun (c, j) -> Printf.fprintf oc "  %d --%a--> %d\n" i pp_char c j ) transitions;
      let o = DFA.otherwise dfa i in
      if o >= 0
      then Printf.fprintf oc "  %d --*--> %d\n" i o
    done

  type automaton = DFA.t

  let of_string ~limit s =
    let nda = NDA.make ~limit s in
    let dfa = DFA.of_nda nda in
    dfa

  let of_list ~limit l =
    of_string ~limit (Str.of_list l)

  let rec __find_char c l = match l with
    | [] -> raise Not_found
    | (c', next) :: l' ->
      if compare c c' = 0
      then next
      else __find_char c l'

  (* transition for [c] in state [i] of [dfa];
     @raise Not_found if no transition matches *)
  let __transition dfa i c =
    let transitions = DFA.get dfa i in
    try
      __find_char c transitions
    with Not_found ->
      let o = DFA.otherwise dfa i in
      if o >= 0
      then o
      else raise Not_found

  let match_with dfa a =
    let len = Str.length a in
    let rec search i state =
      (*Printf.printf "at state %d (dist %d)\n" i dist;*)
      if i = len
      then DFA.is_final dfa state
      else begin
        (* current char *)
        let c = Str.get a i in
        try
          let next = __transition dfa state c in
          search (i+1) next
        with Not_found -> false
      end
    in
    search 0 0

  (** {6 Index for one-to-many matching} *)

  module Index = struct
    type key = char_

    module M = Map.Make(struct
        type t = key
        let compare = Str.compare_char
      end)

    type 'b t =
      | Node of 'b option * 'b t M.t

    let empty = Node (None, M.empty)

    let is_empty = function
      | Node (None, m) -> M.is_empty m
      | _ -> false

    let () = assert (is_empty empty)

    (** get/add/remove the leaf for the given array.
        the continuation k takes the leaf, and returns a leaf option
        that replaces the old leaf.
        This function returns the new trie. *)
    let goto_leaf s node k =
      let len = Str.length s in
      (* insert the value in given [node], assuming the current index
         in [arr] is [i]. [k] is given the resulting tree. *)
      let rec goto node i rebuild = match node with
        | _ when i = len ->
          let node' = k node in
          rebuild node'
        | Node (opt, m) ->
          let c = Str.get s i in
          let t' =
            try M.find c m
            with Not_found -> empty
          in
          goto t' (i+1)
            (fun t'' ->
               if is_empty t''
               then rebuild (Node (opt, M.remove c m))
               else rebuild (Node (opt, M.add c t'' m)))
      in
      goto node 0 (fun t -> t)

    let add trie s value =
      goto_leaf s trie
        (function
          | Node (_, m) -> Node (Some value, m))

    let remove trie s =
      goto_leaf s trie
        (function
          | Node (_, m) -> Node (None, m))

    (* traverse the automaton and the idx, yielding a klist of values *)
    let retrieve ~limit idx s =
      let dfa = of_string ~limit s in
      (* traverse at index i in automaton, with
          [fk] the failure continuation *)
      let rec traverse node i ~(fk:'a Seq.t) () =
        match node with
        | Node (opt, m) ->
          (* all alternatives: continue exploring [m], or call [fk] *)
          let fk =
            M.fold
              (fun c node' fk ->
                 try
                   let next = __transition dfa i c in
                   traverse node' next ~fk
                 with Not_found -> fk)
              m fk
          in
          match opt with
          | Some v when DFA.is_final dfa i ->
            (* yield one solution now *)
            Seq.Cons (v, fk)
          | _ -> fk ()   (* fail... or explore subtrees *)
      in
      traverse idx 0 ~fk:Seq.empty

    let retrieve_l ~limit idx s = list_of_seq @@ retrieve ~limit idx s

    let of_list l =
      List.fold_left
        (fun acc (arr,v) -> add acc arr v)
        empty l

    let fold f acc idx =
      let rec explore acc trail node = match node with
        | Node (opt, m) ->
          (* first, yield current value, if any *)
          let acc = match opt with
            | None -> acc
            | Some v ->
              let str = Str.of_list (List.rev trail) in
              f acc str v
          in
          M.fold
            (fun c node' acc -> explore acc (c::trail) node')
            m acc
      in
      explore acc [] idx

    let iter f idx =
      fold (fun () str v -> f str v) () idx

    let to_list idx =
      fold (fun acc str v -> (str,v) :: acc) [] idx

    let to_seq idx =
      let rec traverse node trail ~(fk:(string_*'a) Seq.t) () =
        match node with
        | Node (opt, m) ->
          (* all alternatives: continue exploring [m], or call [fk] *)
          let fk =
            M.fold
              (fun c node' fk -> traverse node' (c::trail) ~fk)
              m fk
          in
          match opt with
          | Some v ->
            let str = Str.of_list (List.rev trail) in
            Seq.Cons ((str,v), fk)
          | _ -> fk ()   (* fail... or explore subtrees *)
      in
      traverse idx [] ~fk:Seq.empty
  end
end

include Make(struct
    type t = string
    type char_ = char
    let compare_char = Char.compare
    let length = String.length
    let get = String.get
    let of_list l =
      let buf = Bytes.make (List.length l) ' ' in
      List.iteri (fun i c -> Bytes.set buf i c) l;
      Bytes.to_string buf
  end)

let debug_print = debug_print output_char

