Require Import bbv.WordScope.
Require Import bbv.DepEqNat.
Require Import riscv.RiscvBitWidths.
Require Import riscv.Monad.
Require Import riscv.Decode.
Require Import riscv.Program.
Require Import Coq.Structures.OrderedTypeEx.

(* Comments between ``double quotes'' are from quotes from
   The RISC-V Instruction Set Manual
   Volume I: User-Level ISA
   Document Version 2.2
*)

Section Riscv.

  Context {B: RiscvBitWidths}.

  Notation Reg := PositiveOrderedTypeBits.t.

  Definition signed_imm_to_word(v: word wimm): word wXLEN.
    refine (nat_cast word _ (sext v (wXLEN - wimm))). bitwidth_omega.
  Defined.

  Definition signed_jimm_to_word(v: word wupper): word wXLEN.
    refine (nat_cast word _ (sext (extz v 1) (wXLEN - wupper - 1))). bitwidth_omega.
  Defined.

  Definition signed_bimm_to_word(v: word wimm): word wXLEN.
    refine (nat_cast word _ (sext (extz v 1) (wXLEN - wimm - 1))). bitwidth_omega.
  Defined.

  Definition upper_imm_to_word(v: word wupper): word wXLEN.
    refine (nat_cast word _ (sext (extz v wimm) (wXLEN - wInstr))). bitwidth_omega.
  Defined.

  Definition execute{M: Type -> Type}{MM: Monad M}{RVS: RiscvState M}(i: Instruction): M unit :=
    match i with

    (* ``ADDI adds the sign-extended 12-bit immediate to register rs1. Arithmetic overflow is
       ignored and the result is simply the low XLEN bits of the result.'' *)
    | Addi rd rs1 imm12 =>
        x <- getRegister rs1;
        setRegister rd (x ^+ (signed_imm_to_word imm12))

    (* ``SLTI (set less than immediate) places the value 1 in register rd if register rs1 is
       less than the sign-extended immediate when both are treated as signed numbers, else 0 is
       written to rd.'' *)
    | Slti rd rs1 imm12 =>
        x <- getRegister rs1;
        setRegister rd (if wslt_dec x (signed_imm_to_word imm12) then $1 else $0)

    (* ``SLTIU is similar but compares the values as unsigned numbers (i.e., the immediate is
       first sign-extended to XLEN bits then treated as an unsigned number).'' *)
    | Sltiu rd rs1 imm12 =>
        x <- getRegister rs1;
        setRegister rd (if wlt_dec x (signed_imm_to_word imm12) then $1 else $0)

    (* ``ANDI, ORI, XORI are logical operations that perform bitwise AND, OR, and XOR on register
       rs1 and the sign-extended 12-bit immediate and place the result in rd.'' *)
    | Andi rd rs1 imm12 =>
        x <- getRegister rs1;
        setRegister rd (wand x (signed_imm_to_word imm12))
    | Ori rd rs1 imm12 =>
        x <- getRegister rs1;
        setRegister rd (wor x (signed_imm_to_word imm12))
    | Xori rd rs1 imm12 =>
        x <- getRegister rs1;
        setRegister rd (wxor x (signed_imm_to_word imm12))

    (* ``SLLI is a logical left shift (zeros are shifted into the lower bits);
       SRLI is a logical right shift (zeros are shifted into the upper bits); and SRAI is an
       arithmetic right shift (the original sign bit is copied into the vacated upper bits).'' *)
    | Slli rd rs1 shamt =>
        x <- getRegister rs1;
        setRegister rd (wlshift x (wordToNat shamt))
    | Srli rd rs1 shamt =>
        x <- getRegister rs1;
        setRegister rd (wrshift x (wordToNat shamt))
 (* | Srai rd rs1 shamt => *)

    (* RV32I: ``LUI (load upper immediate) is used to build 32-bit constants and uses the U-type
       format. LUI places the U-immediate value in the top 20 bits of the destination register rd,
       filling in the lowest 12 bits with zeros.''
       RV64I: ``LUI (load upper immediate) uses the same opcode as RV32I. LUI places the 20-bit
       U-immediate into bits 31-12 of register rd and places zero in the lowest 12 bits. The 32-bit
       result is sign-extended to 64 bits. *)
    | Lui rd imm20 =>
        setRegister rd (upper_imm_to_word imm20)

    (* ``ADD and SUB perform addition and subtraction respectively. Overflows are ignored and
       the low XLEN bits of results are written to the destination. *)
    | Add rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (x ^+ y)
    | Sub rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (x ^- y)

    (* ``SLT and SLTU perform signed and unsigned compares respectively, writing 1 to rd
       if rs1 < rs2, 0 otherwise.'' *)
    | Slt rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (if wslt_dec x y then $1 else $0)
    | Sltu rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (if wlt_dec x y then $1 else $0)

    (* ``AND, OR, and XOR perform bitwise logical operations.'' *)
    | And rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (wand x y)
    | Or rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (wor x y)
    | Xor rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (wxor x y)

    (* ``The jump and link (JAL) instruction uses the J-type format, where the J-immediate encodes
       a signed offset in multiples of 2 bytes. The offset is sign-extended and added to the pc to
       form the jump target address. Jumps can therefore target a +/- 1 MiB range. JAL stores the
       address of the instruction following the jump (pc+4) into register rd.'' *)
    | Jal rd jimm20 =>
        pc <- getPC;
        setRegister rd (pc ^+ $4);;
        setPC (pc ^+ (signed_jimm_to_word jimm20))
    (* Note: The following is not yet implemented:
       ``The JAL and JALR instructions will generate a misaligned instruction fetch exception
       if the target address is not aligned to a four-byte boundary.''
       Also applies to the branch instructions. *)

    (* ``All branch instructions use the B-type instruction format. The 12-bit B-immediate encodes
       signed offsets in multiples of 2, and is added to the current pc to give the target address.
       The conditional branch range is +/- 4 KiB.'' *)

    (* ``BEQ and BNE take the branch if registers rs1 and rs2 are equal or unequal respectively.'' *)
    | Beq rs1 rs2 sbimm12 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        pc <- getPC;
        if weq x y then (setPC (pc ^+ (signed_bimm_to_word sbimm12))) else Return tt
    | Bne rs1 rs2 sbimm12 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        pc <- getPC;
        if weq x y then Return tt else (setPC (pc ^+ (signed_bimm_to_word sbimm12)))

    (* ``BLT and BLTU take the branch if rs1 is less than rs2, using signed and unsigned comparison
       respectively.'' *)
    | Blt rs1 rs2 sbimm12 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        pc <- getPC;
        if wslt_dec x y then (setPC (pc ^+ (signed_bimm_to_word sbimm12))) else Return tt
    | Bltu rs1 rs2 sbimm12 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        pc <- getPC;
        if wlt_dec x y then (setPC (pc ^+ (signed_bimm_to_word sbimm12))) else Return tt

    (* ``BGE and BGEU take the branch if rs1 is greater than or equal to rs2, using signed and
       unsigned comparison respectively.'' *)
    | Bge rs1 rs2 sbimm12 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        pc <- getPC;
        if wslt_dec x y then Return tt else (setPC (pc ^+ (signed_bimm_to_word sbimm12)))
    | Bgeu rs1 rs2 sbimm12 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        pc <- getPC;
        if wlt_dec x y then Return tt else (setPC (pc ^+ (signed_bimm_to_word sbimm12)))

    (* ``MUL performs an XLEN-bit x XLEN-bit multiplication and places the lower XLEN bits in the
       destination register.'' *)
    | Mul rd rs1 rs2 =>
        x <- getRegister rs1;
        y <- getRegister rs2;
        setRegister rd (x ^* y)
    end.

End Riscv.
