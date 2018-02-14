(** Typeclass for decidable propositions *)
(** simplification of  fiat-crypto/src/Util/Decidable.v *)

Require Import Coq.Arith.PeanoNat.
Require Import Coq.Arith.Compare_dec.
Require Import Coq.ZArith.BinInt.
Require Import Coq.Structures.OrderedTypeEx.
Require Import Coq.Numbers.BinNums.

Class Decidable (P : Prop) := dec : {P} + {~P}.
Arguments dec _%type_scope {_}.

Notation DecidableRel R := (forall x y, Decidable (R x y)).
Notation DecidableEq T := (forall (x y: T), Decidable (x = y)).

Global Instance dec_eq_nat : DecidableEq nat := Nat.eq_dec.
Global Instance dec_eq_Z : DecidableEq Z := Z.eq_dec.
Global Instance dec_eq_positive: DecidableEq positive := PositiveOrderedTypeBits.eq_dec.
Global Instance dec_le_nat : DecidableRel le := Compare_dec.le_dec.
Global Instance dec_lt_nat : DecidableRel lt := Compare_dec.lt_dec.
Global Instance dec_ge_nat : DecidableRel ge := Compare_dec.ge_dec.
Global Instance dec_gt_nat : DecidableRel gt := Compare_dec.gt_dec.

Instance decidable_eq_option {A} `{DecidableEq A}: DecidableEq (option A).
  intros. unfold Decidable. destruct x; destruct y.
  - destruct (DecidableEq0 a a0).
    + subst. left. reflexivity.
    + right. unfold not in *. intro E. inversion E. auto.
  - right. intro. discriminate.
  - right. intro. discriminate.
  - left. reflexivity.
Defined.
