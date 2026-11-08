# Fixed arithmetic using only RV32I integer instructions.
#
# op1_asm: a0=sum/result, a1=carry word, a2=pass-count pointer.
#          t0=carry temporary, t1=number of passes.
# op2_asm: a0/a1=inputs, a0=result.
# op3_asm: a0/a1=inputs, t0=half of XOR, a0=result.
# q_mul_asm: a0=term low word/result, a1=unsigned multiplier.
#            a2=term high word, a3=product low, a4=product high.
#            t0=sign mask, bit test, carry, or rounding temporary.
# All functions use only caller-saved registers and need no stack frame.

    .text
    .option norvc

    .globl op1_asm
    .type op1_asm, @function
    .align 2
op1_asm:
    li t1, 0
    beqz a1, .Lfixed_op1_done
.Lfixed_op1_loop:
    and t0, a0, a1
    xor a0, a0, a1
    slli a1, t0, 1
    addi t1, t1, 1
    bnez a1, .Lfixed_op1_loop
.Lfixed_op1_done:
    sw t1, 0(a2)
    ret
    .size op1_asm, .-op1_asm

    .globl op2_asm
    .type op2_asm, @function
    .align 2
op2_asm:
    sub a0, a0, a1
    ret
    .size op2_asm, .-op2_asm

    .globl op3_asm
    .type op3_asm, @function
    .align 2
op3_asm:
    xor t0, a0, a1
    and a0, a0, a1
    srli t0, t0, 1
    add a0, a0, t0
    ret
    .size op3_asm, .-op3_asm

    .globl q_mul_asm
    .type q_mul_asm, @function
    .align 2
q_mul_asm:
    beqz a1, .Lfixed_q_zero

    # Sign-extend a into the two-word term.
    srai a2, a0, 31

    # Treat b as unsigned, with its signed correction in product_hi.
    srai t0, a1, 31
    and t0, t0, a0
    sub a4, zero, t0
    li a3, 0

.Lfixed_q_loop:
    andi t0, a1, 1
    beqz t0, .Lfixed_q_shift
    add a3, a3, a0
    sltu t0, a3, a0
    add a4, a4, a2
    add a4, a4, t0

.Lfixed_q_shift:
    srli t0, a0, 31
    slli a2, a2, 1
    or a2, a2, t0
    slli a0, a0, 1
    srli a1, a1, 1
    bnez a1, .Lfixed_q_loop

    # Add 2^19 to the signed product, including the low-word carry.
    li t0, 0x80000
    add a3, a3, t0
    sltu t0, a3, t0
    add a4, a4, t0

    # Keep bits 20 through 51; higher sign-extension bits are discarded.
    srli a0, a3, 20
    slli a4, a4, 12
    or a0, a0, a4
    ret

.Lfixed_q_zero:
    li a0, 0
    ret
    .size q_mul_asm, .-q_mul_asm

    .section .note.GNU-stack,"",@progbits
