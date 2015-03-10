Require Import Ssreflect.ssreflect Ssreflect.ssrfun Ssreflect.ssrbool.
Require Import Ssreflect.ssrnat Ssreflect.eqtype Ssreflect.seq.
Require Import Ssreflect.choice Ssreflect.fintype.

Require Import MathComp.path MathComp.bigop.

Require Import ord.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Module FSet.

Section Def.

Variables (T : ordType).

Local Open Scope ord_scope.

CoInductive fset_type := FSet {
  fsval : seq T;
  _ : sorted (@Ord.lt T) fsval
}.
Definition fset_of of phant T := fset_type.
Identity Coercion type_of_fset_of : fset_of >-> fset_type.

End Def.

Module Exports.

Notation "{ 'fset' T }" := (@fset_of _ (Phant T))
  (at level 0, format "{ 'fset'  T }") : type_scope.
Coercion fsval : fset_type >-> seq.
Canonical fset_subType T := [subType for @fsval T].
Definition fset_eqMixin T := [eqMixin of fset_type T by <:].
Canonical fset_eqType T :=
  Eval hnf in EqType (fset_type T) (fset_eqMixin T).

End Exports.

End FSet.

Export FSet.Exports.

Delimit Scope fset_scope with fset.

(* Redefine the partmap constructor with a different signature, in
order to keep types consistent. *)
Definition fset (T : ordType) s Ps : {fset T} :=
  @FSet.FSet T s Ps.

Section Operations.

Variables (T : ordType).

Implicit Type s : {fset T}.

Local Open Scope ord_scope.

Definition fset0 := @fset T [::] erefl.

Definition fset1 x := @fset T [:: x] erefl.

Fixpoint fsetU1' (s : seq T) x : seq T :=
  if s is x' :: s' then
    if x < x' then x :: s
    else if x == x' then s
    else x' :: fsetU1' s' x
  else [:: x].

Lemma fsetU1_proof s x : sorted (@Ord.lt T) (fsetU1' s x).
Proof.
have E: forall s : seq T, fsetU1' s x =i x :: s.
  elim=> {s} // x' s /= IH x''; rewrite ![in X in X = _]fun_if /= !inE.
  rewrite IH inE.
  case: (Ord.ltgtP x x') => // H; try by bool_congr.
  by rewrite H orbA orbb.
case: s; elim=> // x' s /= IH Ps.
move: (order_path_min (@Ord.lt_trans T) Ps) => lb.
rewrite ![in X in is_true X]fun_if /= path_min_sorted; last exact: (allP lb).
rewrite (path_sorted Ps); case: Ord.ltgtP=> [x_x'//|x_x'|_ //] /=.
rewrite path_min_sorted ?(IH (path_sorted Ps)) //=; apply/allP.
by rewrite !(eq_all_r (E s)) {E} /= lb andbT.
Qed.

Definition fsetU1 s x := fset (fsetU1_proof s x).

Definition fsetU s1 s2 := foldr (fun x s => fsetU1 s x) s2 s1.

Definition fsubset s1 s2 := fsetU s1 s2 == s2.

Definition mkfset xs := foldr (fun x s => fsetU1 s x) fset0 xs.

Definition mem_fset s :=
  [pred x : T | x \in val s].

Canonical mem_fset_predType := mkPredType mem_fset.

Definition fset_filter P s := mkfset [seq x <- s | P x].

Definition fsetD1 s x := fset_filter (predC1 x) s.

Definition fsetD s1 s2 := fset_filter [pred x | x \notin s2] s1.

End Operations.

Arguments fset0 {_}.
Prenex Implicits fsetU1 fsetU mkfset.

Notation "x |: s" := (fsetU1 s x) : fset_scope.
Notation "s1 :|: s2" := (fsetU s1 s2) : fset_scope.
Notation "s :\ x" := (fsetD1 s x) : fset_scope.
Notation "s1 :\: s2" := (fsetD s1 s2) : fset_scope.

Section Properties.

Variables (T : ordType).
Local Open Scope fset_scope.

Implicit Types (s : {fset T}) (x y : T) (xs : seq T).

Lemma eq_fset s1 s2 : s1 =i s2 <-> s1 = s2.
Proof.
split; last congruence.
case: s1 s2 => [s1 Ps1] [s2 Ps2] /= E; apply/val_inj=> /=.
have anti: antisymmetric (@Ord.lt T).
  move=> x y /andP [/Ord.ltW xy /Ord.ltW yx].
  exact: Ord.anti_leq (introT andP (conj xy yx)).
have {E} E := E : s1 =i s2; apply: (eq_sorted _ _ Ps1 Ps2) => //.
  exact: Ord.lt_trans.
apply: uniq_perm_eq => //; [move: Ps1|move: Ps2]; apply/sorted_uniq => //;
by [apply: Ord.ltxx|apply: Ord.lt_trans].
Qed.

Lemma in_fset0 x : x \in fset0 = false.
Proof. by []. Qed.

Lemma in_fset1 x y : x \in fset1 y = (x == y).
Proof. by rewrite inE. Qed.

Lemma in_fsetU1 x y s : x \in y |: s = (x == y) || (x \in s).
Proof.
case: s => s Ps; rewrite !inE /=; elim: s Ps => [|z s IH /=] // Ps.
rewrite /= !inE /= ![in LHS]fun_if !inE.
case: (Ord.ltgtP y z) =>[//|z_lt_y |<-].
  by rewrite IH ?(path_sorted Ps) //; bool_congr.
by rewrite orbA orbb.
Qed.

CoInductive fset_spec : {fset T} -> Type :=
| FSetSpec0 : fset_spec fset0
| FSetSpecS x s of x \notin s : fset_spec (x |: s).

Lemma fsetP s : fset_spec s.
Proof.
case: s=> [[|x xs] /= Pxs]; first by rewrite eq_axiomK; apply: FSetSpec0.
have Pxs' := path_sorted Pxs.
set s' : {fset T} := FSet.FSet Pxs'; set s : {fset T} := FSet.FSet _.
have x_nin_s : x \notin s'.
  apply/negP=> /(allP (order_path_min (@Ord.lt_trans T) Pxs)).
  by rewrite Ord.ltxx.
suff ->: s = x |: s' by apply: FSetSpecS.
by apply/eq_fset=> x'; rewrite in_fsetU1 !inE.
Qed.

Lemma fset_rect (P : {fset T} -> Type) :
  P fset0 ->
  (forall x s, x \notin s -> P s -> P (x |: s)) ->
  forall s, P s.
Proof.
move=> H0 HS []; elim=> [|/= x xs IH] Pxs; first by rewrite eq_axiomK.
move: IH => /(_ (path_sorted Pxs)).
set s : {fset T} := FSet.FSet _; set s' : {fset T} := FSet.FSet _ => Ps.
have x_nin_s : x \notin s.
  apply/negP=> /(allP (order_path_min (@Ord.lt_trans T) Pxs)).
  by rewrite Ord.ltxx.
suff ->: s' = x |: s by eauto.
by apply/eq_fset=> x'; rewrite in_fsetU1 !inE.
Qed.

Definition fset_ind (P : {fset T} -> Prop) :
  P fset0 ->
  (forall x s, x \notin s -> P s -> P (x |: s)) ->
  forall s, P s := @fset_rect P.

Lemma size_fset0 : size (fset0 : {fset T}) = 0.
Proof. by []. Qed.

Lemma size_fsetU1 s x : size (x |: s) = (x \notin s) + size s.
Proof.
rewrite /fsetU1 /= [in RHS]inE /=; move: (valP s)=>/=; move: (s : seq _).
elim{s} => [|x' xs IH] //=.
rewrite inE negb_or; case: Ord.ltgtP=> //=.
  move=> xx' hxs {IH}; suff -> : x \notin xs by [].
  apply/negP=> /(allP (order_path_min (@Ord.lt_trans T) hxs)).
  by rewrite Ord.ltNge (Ord.ltW xx').
move=> x'x hxs; move: IH => /(_ (path_sorted hxs)) ->.
by rewrite addnS.
Qed.

Lemma in_fsetU x s1 s2 : (x \in s1 :|: s2) = (x \in s1) || (x \in s2).
Proof.
case: s1=> [/= s1 Ps1]; rewrite /fsetU !inE /= {Ps1}.
by elim: s1=> [|y s1 IH] //=; rewrite in_fsetU1 IH inE; bool_congr.
Qed.

Lemma fsetU1P x y s : reflect (x = y \/ x \in s) (x \in y |: s).
Proof. by rewrite in_fsetU1; apply/predU1P. Qed.

Lemma fsetU1E y s : y |: s = fset1 y :|: s.
Proof. by apply/eq_fset=> x; rewrite in_fsetU1. Qed.

Lemma fsetUP x s1 s2 : reflect (x \in s1 \/ x \in s2) (x \in s1 :|: s2).
Proof. by rewrite in_fsetU; apply/orP. Qed.

Lemma fsetUC : commutative (@fsetU T).
Proof. by move=> s1 s2; apply/eq_fset=> x; rewrite !in_fsetU orbC. Qed.

Lemma fsetUA : associative (@fsetU T).
Proof.
by move=> s1 s2 s3; apply/eq_fset=> x; rewrite !in_fsetU orbA.
Qed.

Lemma fset0U : left_id fset0 (@fsetU T).
Proof. by []. Qed.

Lemma fsetU0 : right_id fset0 (@fsetU T).
Proof. by move=> s; rewrite fsetUC fset0U. Qed.

Lemma fsetUid : idempotent (@fsetU T).
Proof. by move=> s; apply/eq_fset=> x; rewrite in_fsetU orbb. Qed.

Lemma fsubsetP s1 s2 : reflect {subset s1 <= s2} (fsubset s1 s2).
Proof.
apply/(iffP idP)=> [/eqP <- x|hs1s2]; first by rewrite in_fsetU => ->.
apply/eqP/eq_fset=> x; rewrite in_fsetU.
have [/hs1s2|//] //= := boolP (x \in s1).
Qed.

Lemma fsubsetxx s : fsubset s s.
Proof. by apply/fsubsetP. Qed.

Lemma fsubsetUl s1 s2 : fsubset s1 (s1 :|: s2).
Proof. by rewrite /fsubset fsetUA fsetUid. Qed.

Lemma fsubsetUr s1 s2 : fsubset s2 (s1 :|: s2).
Proof. by rewrite fsetUC fsubsetUl. Qed.

Lemma fsubU1set x s1 s2 :
  fsubset (x |: s1) s2 = (x \in s2) && (fsubset s1 s2).
Proof.
apply/(sameP idP)/(iffP idP).
  case/andP=> [hx /fsubsetP hs1]; apply/fsubsetP=> x'.
  by rewrite in_fsetU1=> /orP [/eqP ->|hx']; eauto.
move/fsubsetP=> h; apply/andP; split.
  by apply: h; rewrite in_fsetU1 eqxx.
by apply/fsubsetP=> x' hx'; apply: h; rewrite in_fsetU1 hx' orbT.
Qed.

Lemma fsubUset s1 s2 s3 :
  fsubset (s1 :|: s2) s3 = (fsubset s1 s3 && fsubset s2 s3).
Proof.
apply/(sameP idP)/(iffP idP).
  case/andP=> [/fsubsetP hs1 /fsubsetP hs2]; apply/fsubsetP=> x.
  by rewrite in_fsetU=> /orP [hx|hx]; eauto.
by move/fsubsetP=> h; apply/andP; split; apply/fsubsetP=> x hx; apply: h;
rewrite in_fsetU hx ?orbT.
Qed.

Lemma in_mkfset x xs : (x \in mkfset xs) = (x \in xs).
Proof. by elim: xs => [|x' xs IH] //=; rewrite in_fsetU1 IH inE. Qed.

Lemma mkfset_cons x xs : mkfset (x :: xs) = x |: mkfset xs.
Proof. by []. Qed.

Lemma uniq_fset s : uniq s.
Proof. exact: (sorted_uniq (@Ord.lt_trans T) (@Ord.ltxx T) (valP s)). Qed.

Lemma size_mkfset xs : size (mkfset xs) <= size xs.
Proof.
have fsub: {subset mkfset xs <= xs} by move=> x; rewrite in_mkfset.
exact: (uniq_leq_size (uniq_fset _) fsub).
Qed.

Lemma uniq_size_mkfset xs : uniq xs = (size xs == size (mkfset xs)).
Proof. exact: (uniq_size_uniq (uniq_fset _) (fun x => in_mkfset x _)). Qed.

Lemma in_fset_filter P s x : (x \in fset_filter P s) = P x && (x \in s).
Proof. by rewrite /fset_filter in_mkfset mem_filter. Qed.

Lemma in_fsetD1 x s y : (x \in s :\ y) = (x != y) && (x \in s).
Proof. by rewrite in_fset_filter. Qed.

Lemma in_fsetD x s1 s2 : (x \in s1 :\: s2) = (x \notin s2) && (x \in s1).
Proof. by rewrite in_fset_filter. Qed.

Lemma size_fsetD1 x s : size s = (x \in s) + size (s :\ x).
Proof.
have [x_in|x_nin] /= := boolP (x \in s).
  rewrite [in LHS](_ : s = x |: s :\ x) ?size_fsetU1 ?in_fsetD1 ?eqxx ?x_in //.
  apply/eq_fset=> x'; rewrite in_fsetU1 in_fsetD1 orb_andr orbN /=.
  by have [->|//] := altP eqP.
rewrite add0n; congr size; congr val; apply/eq_fset=> x'.
by rewrite in_fsetD1; have [->|] //= := altP eqP; apply/negbTE.
Qed.

Lemma fsubset_leq_size s1 s2 : fsubset s1 s2 -> size s1 <= size s2.
Proof.
elim/fset_ind: s1 s2 => [|x s1 Px IH] s2; first by rewrite leq0n.
rewrite fsubU1set size_fsetU1 (size_fsetD1 x s2) Px add1n.
case/andP=> [-> ]; rewrite ltnS=> /fsubsetP hs1s2.
apply: IH; apply/fsubsetP=> x' Hx'; rewrite in_fsetD1 hs1s2 // andbT.
by apply: contra Px=> /eqP <-.
Qed.

Lemma sizes_eq0 s : (size s == 0) = (s == fset0).
Proof.
case: s / fsetP=> [|x s Px] //.
rewrite size_fsetU1 Px /= add1n eqE /=.
apply/esym/negbTE/eqP=> h; move: (in_fset0 x); rewrite -h.
by rewrite in_fsetU1 eqxx.
Qed.

Lemma fsubset_sizeP s1 s2 :
  size s1 = size s2 -> reflect (s1 = s2) (fsubset s1 s2).
Proof.
elim/fset_rect: s1 s2=> [|x s1 Px IH] s2.
  rewrite size_fset0 => /esym/eqP; rewrite sizes_eq0=> /eqP ->.
  by rewrite fsubsetxx; constructor.
rewrite size_fsetU1 Px add1n fsubU1set => h_size.
apply/(iffP idP)=> [/andP [x_in_s2 hs1s2]|].
  have ->: s2 = x |: s2 :\ x.
    apply/eq_fset=> x'; rewrite in_fsetU1 in_fsetD1 orb_andr orbN /=.
    by have [->|] := altP (x' =P x).
  congr fsetU1; apply: IH.
    by move: h_size; rewrite (size_fsetD1 x s2) x_in_s2 add1n=> - [?].
  apply/fsubsetP=> x' x'_in_s1; rewrite in_fsetD1 (fsubsetP _ _ hs1s2) //.
  by rewrite andbT; apply: contraTN x'_in_s1 => /eqP ->.
move=> hs2; rewrite -{}hs2 {s2} in h_size *.
by rewrite in_fsetU1 eqxx /= fsetU1E fsubsetUr.
Qed.

Definition fpick P s := ohead (fset_filter P s).

CoInductive fpick_spec (P : pred T) s : option T -> Type :=
| FPickSome x of P x & x \in s : fpick_spec P s (Some x)
| FPickNone of (forall x, x \in s -> ~~ P x) : fpick_spec P s None.

Lemma fpickP P s : fpick_spec P s (fpick P s).
Proof.
rewrite /fpick; case E: (val (fset_filter P s))=> [|x xs] /=.
  constructor=> x x_in_s; apply/negP => Px.
  by move: (in_fset_filter P s x); rewrite inE E Px x_in_s.
move: (in_fset_filter P s x); rewrite inE E inE eqxx /=.
by case/esym/andP=> ??; constructor.
Qed.

End Properties.

Section setOpsAlgebra.

Import Monoid.

Variable T : ordType.

Canonical fsetU_monoid := Law (@fsetUA T) (@fset0U T) (@fsetU0 T).
Canonical fsetU_comoid := ComLaw (@fsetUC T).

End setOpsAlgebra.

Notation "\bigcup_ ( i <- r | P ) F" :=
  (\big[@fsetU _/fset0]_(i <- r | P) F%fset) : fset_scope.
Notation "\bigcup_ ( i <- r ) F" :=
  (\big[@fsetU _/fset0]_(i <- r) F%fset) : fset_scope.
Notation "\bigcup_ ( m <= i < n | P ) F" :=
  (\big[@fsetU _/fset0]_(m <= i < n | P%B) F%fset) : fset_scope.
Notation "\bigcup_ ( m <= i < n ) F" :=
  (\big[@fsetU _/fset0]_(m <= i < n) F%fset) : fset_scope.
Notation "\bigcup_ ( i | P ) F" :=
  (\big[@fsetU _/fset0]_(i | P%B) F%fset) : fset_scope.
Notation "\bigcup_ i F" :=
  (\big[@fsetU _/fset0]_i F%fset) : fset_scope.
Notation "\bigcup_ ( i : t | P ) F" :=
  (\big[@fsetU _/fset0]_(i : t | P%B) F%fset) (only parsing): fset_scope.
Notation "\bigcup_ ( i : t ) F" :=
  (\big[@fsetU _/fset0]_(i : t) F%fset) (only parsing) : fset_scope.
Notation "\bigcup_ ( i < n | P ) F" :=
  (\big[@fsetU _/fset0]_(i < n | P%B) F%fset) : fset_scope.
Notation "\bigcup_ ( i < n ) F" :=
  (\big[@fsetU _/fset0]_ (i < n) F%fset) : fset_scope.
Notation "\bigcup_ ( i 'in' A | P ) F" :=
  (\big[@fsetU _/fset0]_(i in A | P%B) F%fset) : fset_scope.
Notation "\bigcup_ ( i 'in' A ) F" :=
  (\big[@fsetU _/fset0]_(i in A) F%fset) : fset_scope.

Section BigSetOps.

Variable T : ordType.
Variable I : finType.

Implicit Types (U : pred T) (P : pred I) (F :  I -> {fset T}).

Local Open Scope fset_scope.

Lemma bigcup_sup j P F : P j -> fsubset (F j) (\bigcup_(i | P i) F i).
Proof. by move=> Pj; rewrite (bigD1 j) //= fsubsetUl. Qed.

Lemma bigcupP x P F :
  reflect (exists2 i, P i & x \in F i) (x \in \bigcup_(i | P i) F i).
Proof.
apply/(iffP idP)=> [|[i Pi]]; last first.
  apply: fsubsetP x; exact: bigcup_sup.
by elim/big_rec: _ => [|i _ Pi _ /fsetUP[|//]]; [rewrite inE | exists i].
Qed.

End BigSetOps.

Section Image.

Variables T S : ordType.

Implicit Type s : {fset T}.

Local Open Scope fset_scope.

Definition imfset (f : T -> S) s := mkfset (map f s).

Lemma imfsetP f s x :
  reflect (exists2 y, y \in s & x = f y) (x \in imfset f s).
Proof.
apply/(iffP idP).
  rewrite /imfset in_mkfset=> /mapP [y Py ->].
  by eexists; eauto.
move=> [y Py {x}->]; rewrite /imfset in_mkfset.
by apply/mapP; eauto.
Qed.

Lemma imfset_eq f1 f2 : f1 =1 f2 -> imfset f1 =1 imfset f2.
Proof.
move=> h_f s; apply/eq_fset=> x.
by apply/(sameP idP)/(iffP idP)=> /imfsetP [y Py ->]; apply/imfsetP;
eexists; eauto.
Qed.

Lemma mem_imfset f x s : x \in s -> f x \in imfset f s.
Proof. by move=> Px; apply/imfsetP; eauto. Qed.

Lemma imfset0 f : imfset f fset0 = fset0.
Proof. by []. Qed.

Lemma imfset1 f x : imfset f (fset1 x) = fset1 (f x).
Proof. by apply/eq_fset=> y; rewrite in_fset1. Qed.

Lemma imfsetU f s1 s2 : imfset f (s1 :|: s2) = imfset f s1 :|: imfset f s2.
Proof.
apply/eq_fset=> y; apply/(sameP idP)/(iffP idP)=> [/fsetUP|/imfsetP].
  move=> [|] => /imfsetP [x' x'_in_s ->{y}]; apply/imfsetP;
  exists x'=> //; apply/fsetUP; eauto.
by move=> [y' /fsetUP [?|?] -> {y}]; apply/fsetUP; [left|right]; apply/imfsetP;
eauto.
Qed.

Lemma imfsetU1 f x s : imfset f (x |: s) = f x |: imfset f s.
Proof. by rewrite fsetU1E imfsetU imfset1 fsetU1E. Qed.

End Image.

Notation "f @: s" := (imfset f s) (at level 24) : fset_scope.

Prenex Implicits imfset.

Section ImageProps.

Local Open Scope fset_scope.

Variables T S R : ordType.

Implicit Types (s : {fset T}) (f : T -> S) (g : S -> R).

Lemma imfset_id s : id @: s = s.
Proof.
apply/eq_fset=> x; apply/(sameP idP)/(iffP idP).
  by move=> x_in; apply/imfsetP; eauto.
by case/imfsetP=> [/= ? ? ->].
Qed.

Lemma imfset_comp f g s : (g \o f) @: s = g @: (f @: s).
Proof.
apply/eq_fset=> x; apply/(sameP idP)/(iffP idP).
  case/imfsetP=> [y /imfsetP [z Pz ->] ->].
  by apply/imfsetP; eauto.
case/imfsetP=> [y /= Py ->]; apply/imfsetP; exists (f y)=> //.
exact: mem_imfset.
Qed.

Lemma imfsetK f f_inv : cancel f f_inv -> cancel (imfset f) (imfset f_inv).
Proof.
move=> fK s; apply/eq_fset=> x; apply/(sameP idP)/(iffP idP).
  move=> x_in; apply/imfsetP; exists (f x); first by apply mem_imfset.
  by rewrite fK.
case/imfsetP=> [y /imfsetP [z Pz ->] ->].
by rewrite fK.
Qed.

Lemma imfset_inj f : injective f -> injective (imfset f).
Proof.
move=> f_inj s1 s2 e; apply/eq_fset=> x; apply/(sameP idP)/(iffP idP).
  by move=> /(mem_imfset f); rewrite -{}e=> /imfsetP [y Py /f_inj ->].
by move=> /(mem_imfset f); rewrite {}e=> /imfsetP [y Py /f_inj ->].
Qed.

Lemma imfsetS f s1 s2 : fsubset s1 s2 -> fsubset (f @: s1) (f @: s2).
Proof.
move/fsubsetP=> h_sub; apply/fsubsetP=> x /imfsetP [y /h_sub Py ->].
by apply: mem_imfset.
Qed.

End ImageProps.

Section CardImage.

Local Open Scope fset_scope.

Variables T S : ordType.

Implicit Types (s : {fset T}) (f : T -> S).

Lemma size_imfset f s : size (f @: s) <= size s.
Proof.
by rewrite /imfset (leq_trans (size_mkfset (map f s))) // size_map.
Qed.

Lemma imfset_injP f s :
  reflect {in s &, injective f} (size (f @: s) == size s).
Proof.
elim/fset_rect: s => [|x s Px IH]; first by rewrite imfset0 eqxx; constructor.
rewrite imfsetU1 !size_fsetU1 Px add1n /=; apply/(iffP idP).
  have [hin|hnin] /= := boolP (f x \in _).
    by rewrite add0n=> /eqP him; move: (size_imfset f s); rewrite him ltnn.
  rewrite add1n eqSS
    => /IH hinj y1 y2 /fsetU1P[->{y1}|hy1] /fsetU1P[->{y2}|hy2] //=;
    last by eauto.
    by move=> hfx; rewrite hfx (mem_imfset f hy2) in hnin.
  by move=> hfx; rewrite -hfx (mem_imfset f hy1) in hnin.
move=> hinj; have /IH/eqP ->: {in s &, injective f}.
  by move=> y1 y2 hy1 hy2 /=; apply:hinj; apply/fsetU1P; auto.
suff ->: f x \notin f @: s by [].
apply: contra Px=> /imfsetP [x' Px' hfx']; suff -> : x = x' by [].
by apply: hinj _ _ hfx'; apply/fsetU1P; auto.
Qed.

End CardImage.

Section Card.

Variable T : ordType.

Implicit Type (s : {fset T}).

Lemma eqEfsubset s1 s2 : (s1 == s2) = (fsubset s1 s2) && (fsubset s2 s1).
Proof.
apply/(sameP idP)/(iffP idP)=> [|/eqP ->]; last by rewrite fsubsetxx.
case/andP=> [/fsubsetP s1s2 /fsubsetP s2s1]; apply/eqP/eq_fset=> x.
by apply/(sameP idP)/(iffP idP); eauto.
Qed.

Lemma eqEfsize s1 s2 : (s1 == s2) = (fsubset s1 s2) && (size s2 <= size s1).
Proof.
apply/(sameP idP)/(iffP idP)=> [/andP [hsub hsize]|/eqP ->]; last first.
  by rewrite fsubsetxx leqnn.
apply/eqP/fsubset_sizeP=> //; apply/eqP; rewrite eqn_leq hsize andbT.
by apply: fsubset_leq_size.
Qed.

End Card.