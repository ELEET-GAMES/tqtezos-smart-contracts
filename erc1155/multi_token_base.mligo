(*
  Reference implementation if `multi_token` core API.

  Since Babylon does not support pairs as keys for big_map,
  This implementation uses composite `balance_key` represented as `nat`.
  Assumed number of different token types is 2^32 (`max_tokens` constant).
  Both token ID and owner ID are "packed" into single `nat` using first 32 bits
  for token ID and the rest of the bits for owner ID.
  Contract storage also keeps mapping between owner address and owner ID
  represented as `nat` (see `owner_lookup`).

  If tokens are transferred to a new owner address which does not exist
  in `owner_loop` yet, new entry withing lookup is created and the owner
  is assigned a new `nat` ID. This implementation may change in future,
  if support for white list is needed.

  Current implementation is optimized for token transfer, but makes it
  difficult for adding functionality in future which might need retrieve
  aggregate data (like list all token types held by the owner).
*)

#include "multi_token.mligo"

(*  owner -> operator set *)
type approvals = (address, address set) big_map


let add_operator (operator : address) (approvals : approvals) : approvals =
  let new_operators =
    match Map.find_opt sender approvals with
    | Some(ops) -> Set.add operator ops
    | None      -> Set.literal [operator]
  in
  Map.update sender (Some new_operators) approvals

let remove_operator (operator : address) (approvals : approvals) : approvals =
  let new_operators_opt =
    match Map.find_opt sender approvals with
    | Some(ops) -> 
        let ops = Set.remove operator ops in
        if Set.size ops = 0n
        then (None : address set option)
        else Some(ops)
    | None      -> (None : address set option)
  in
  Map.update sender new_operators_opt approvals
  
let is_operator
    (param : is_operator_param) (approvals : approvals) : operation = 
  let req = param.is_operator_request in
  let operators = Map.find_opt req.owner approvals in
  let result = 
    match operators with
    | None      -> false
    | Some ops  -> Set.mem req.operator ops
  in
  param.is_operator_view (req, result)


let max_tokens = 4294967295n  (* 2^32-1 *)
let owner_offset = 4294967296n  (* 2^32 *)

(* owner_token_id -> balance *)
type balances = (nat, nat) big_map
type owner_lookup = {
  owner_count : nat;
  (* owner_address -> owner_id *)
  owners: (address, nat) big_map
}

type balance_storage = {
  owners : owner_lookup;
  balances : balances;  
}

type owner_result = {
  id : nat;
  owners : owner_lookup;
}

(* return updated storage and newly added owner id *)
let add_owner (owner : address) (s : owner_lookup) : owner_result =
  let owner_id  = s.owner_count + 1n in
  let os = Map.add owner owner_id s.owners in
  let new_s = 
    { 
      owner_count = owner_id;
      owners = os;
    } in
  {
    id = owner_id;
    owners = new_s;
  }

(* 
  gets existing owner id. If owner does not have one, creates a new id and adds
  it to an owner_lookup 
*)
let ensure_owner_id (owner : address) (s : owner_lookup) : owner_result =
  let owner_id = Map.find_opt owner s.owners in
  match owner_id with
  | Some id -> { id = id; owners = s; }
  | None    -> add_owner owner s

let get_owner_id (owner: address) (s: owner_lookup) : nat =
   let owner_id = Map.find_opt owner s.owners in
  match owner_id with
  | None    -> (failwith("No such owner") : nat)
  | Some id -> id

let make_balance_key_impl (owner_id : nat) (token_id : nat) : nat =
  if token_id > max_tokens
  then (failwith("provided token ID is out of allowed range") : nat)
  else token_id + (owner_id * owner_offset)

let make_balance_key (owner : address) (token_id : nat) (s : owner_lookup) : nat =
  let owner_id = get_owner_id owner s in
  make_balance_key_impl owner_id token_id

type owner_key_result = {
  key : nat;
  owners: owner_lookup;
}

(* 
  Makes the key to access balance and if owner does not have an id, creates
  a new id and adds it to an owner_lookup 
*)
let make_balance_key_ensure 
    (owner : address) (token_id : nat) (s : owner_lookup) : owner_key_result = 
  let o = ensure_owner_id owner s in
  let key = make_balance_key_impl o.id token_id in
  {
    key =key;
    owners = o.owners;
  }
 
let get_balance (key : nat) (b : balances) : nat =
  let bal : nat option = Map.find_opt key b in
  match bal with
  | None    -> 0n
  | Some b  -> b

let get_balance_req (r : balance_request) (s : balance_storage) : nat =
  let balance_key = make_balance_key r.owner r.token_id s.owners in
  get_balance balance_key s.balances

let balance_of 
    (param : balance_of_param) (s : balance_storage) : operation =
  let to_balance = fun (r: balance_request) ->
    let bal = get_balance_req r s in
    (r, bal) 
  in
  let requests_2_bals = List.map param.balance_request to_balance in
  param.balance_view requests_2_bals

let transfer_balance
    (from_key : nat) (to_key : nat) (amt : nat) (s : balances) : balances = 
  let from_bal = get_balance from_key s in
  if from_bal < amt
  then (failwith ("Insufficient balance") : balances)
  else
    let fbal = abs (from_bal - amt) in
    let s1 = 
      if fbal = 0n 
      then Map.remove from_key s
      else Map.update from_key (Some fbal) s 
    in
    let to_bal = get_balance to_key s1 in
    let tbal = to_bal + amt in
    let s2 = Map.update to_key (Some tbal) s1 in
    s2

let transfer_safe_check
    (param : transfer_param) : operation list =
  let receiver : multi_token_receiver contract = 
    Operation.get_contract param.to_ in
  let p : on_multi_tokens_received_param = {
      operator = sender;
      from_ = Some param.from_;
      batch = param.batch;
      data = param.data;
    } in
  let op = Operation.transaction (On_multi_tokens_received p) 0mutez receiver in
  [op]

let transfer 
    (param : transfer_param) (s : balance_storage) : (operation  list) * balance_store = 
  let from_id = get_owner_id param.from_ s.owners in
  let to_o = ensure_owner_id param.to_ s.owners in
  let make_transfer = fun (bals: balances) (t: tx) ->
    let from_key  = make_balance_key_impl from_id t.token_id in
    let to_key  = make_balance_key_impl to_o.id t.token_id in
    transfer_balance from_key to_key t.amount bals in 

  let new_balances = List.fold param.batch s.balances make_transfer in
  let new_store: balance_storage = {
    owners = to_o.owners;
    balances = new_balances;
  } in
  let ops = transfer_safe_check param in
  (ops, new_store)

let approved_transfer_from (from_ : address) (approvals : approvals) : unit =
  if sender = from_
  then unit
  else 
    let ops = Map.find_opt sender approvals in
    let is_op = match ops with
      | None -> (failwith ("operator not approved to transfer tokens") : bool)
      | Some o -> Set.mem from_ o 
    in
    if is_op
    then unit
    else failwith ("operator not approved to transfer tokens")
    

type multi_token_storage = {
  approvals : approvals;
  balance_storage: balance_storage;
}

let multi_token_main
    (param : multi_token) (s : multi_token_storage) : (operation  list) * multi_token_storage =
  match param with
  | Transfer p ->
      let u : unit = approved_transfer_from p.from_ s.approvals in
      let ops_bstore =transfer p s.balance_storage in
      let new_s = {
        approvals = s.approvals;
        balance_storage = ops_bstore.1;
      } in
      (ops_bstore.0, new_s)

  | Balance_of p ->
      let op = balance_of p s.balance_storage in
      ([op], s)

  | Add_operator o ->
      let new_approvals = add_operator o s.approvals in
      let new_s = {
        approvals = new_approvals;
        balance_storage = s.balance_storage;
      } in
      (([] : operation list), new_s)

    | Remove_operator o ->
      let new_approvals = remove_operator o s.approvals in
      let new_s = {
        approvals = new_approvals;
        balance_storage = s.balance_storage;
      } in
      (([] : operation list), new_s)

  | Is_operator p  ->
      let op = is_operator p s.approvals in
      ([op], s)

