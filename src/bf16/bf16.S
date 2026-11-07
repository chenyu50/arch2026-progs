# Software BF16 operations using only RV32I integer instructions.
#
# bf16_from_f32_asm:
#   a0: input and result; t0/t1: exponent mask and rounding temporaries.
#
# bf16_mul_asm:
#   a0/a1: inputs and normalized significands; a0 also holds the result.
#   a2: product sign; a3/a4: operand magnitudes; a5/a6: adjusted exponents.
#   t0/t1: normalization, product, and packing temporaries.
#
# bf16_sqrt_asm:
#   a0: input and result; a1: encoded result exponent.
#   t0: magnitude, significand, then remainder; t1: partial root.
#   t2: sign or trial bit; t3: trial subtraction.
#
# All routines are leaf functions and use only caller-saved registers.

    .text
    .option norvc

    .globl bf16_from_f32_asm
    .type bf16_from_f32_asm, @function
    .align 2
bf16_from_f32_asm:
    li t0, 0x7f800000
    and t1, a0, t0
    beq t1, t0, .Lbf16_f32_high
    srli t0, a0, 16
    andi t0, t0, 1
    li t1, 0x7fff
    add a0, a0, t1
    add a0, a0, t0
.Lbf16_f32_high:
    srli a0, a0, 16
    ret
    .size bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl bf16_mul_asm
    .type bf16_mul_asm, @function
    .align 2
bf16_mul_asm:
    xor a2, a0, a1
    li t0, 0x8000
    and a2, a2, t0
    li t0, 0x7fff
    and a3, a0, t0
    and a4, a1, t0
    srli a5, a3, 7
    srli a6, a4, 7
    li t0, 255
    beq a5, t0, .Lbf16_mul_special_a
    beq a6, t0, .Lbf16_mul_special_b
    beqz a3, .Lbf16_mul_zero
    beqz a4, .Lbf16_mul_zero

    andi a0, a0, 127
    andi a1, a1, 127
    beqz a5, .Lbf16_mul_normalize_a
    ori a0, a0, 128
.Lbf16_mul_a_ready:
    beqz a6, .Lbf16_mul_normalize_b
    ori a1, a1, 128
.Lbf16_mul_b_ready:
    add a5, a5, a6
    addi a5, a5, -127

    # Both significands have bit 7 set. Multiply the remaining seven bits.
    slli t0, a0, 7
    andi a1, a1, 127
    beqz a1, .Lbf16_mul_product_ready
    .rept 6
    andi t1, a1, 1
    beqz t1, 1f
    add t0, t0, a0
1:
    srli a1, a1, 1
    beqz a1, .Lbf16_mul_product_ready
    slli a0, a0, 1
    .endr
    # A remaining bit 6 is necessarily one.
    add t0, t0, a0

.Lbf16_mul_product_ready:
    li t1, 0x8000
    bltu t0, t1, .Lbf16_mul_fraction
    srli t0, t0, 1
    addi a5, a5, 1
.Lbf16_mul_fraction:
    srli t0, t0, 7
    andi t0, t0, 127
    li t1, 255
    bge a5, t1, .Lbf16_mul_inf
    blez a5, .Lbf16_mul_underflow
    slli a5, a5, 7
    or a0, a5, t0
    or a0, a0, a2
    ret

.Lbf16_mul_underflow:
    li t1, -6
    blt a5, t1, .Lbf16_mul_zero
    li t1, 1
    sub t1, t1, a5
    srl t0, t0, t1
    or a0, a2, t0
    ret

.Lbf16_mul_normalize_a:
    li a5, 1
.Lbf16_mul_shift_a:
    slli a0, a0, 1
    addi a5, a5, -1
    andi t0, a0, 128
    beqz t0, .Lbf16_mul_shift_a
    j .Lbf16_mul_a_ready

.Lbf16_mul_normalize_b:
    li a6, 1
.Lbf16_mul_shift_b:
    slli a1, a1, 1
    addi a6, a6, -1
    andi t0, a1, 128
    beqz t0, .Lbf16_mul_shift_b
    j .Lbf16_mul_b_ready

.Lbf16_mul_special_a:
    andi t0, a0, 127
    bnez t0, .Lbf16_mul_return
    beqz a4, .Lbf16_mul_nan
.Lbf16_mul_inf:
    li a0, 0x7f80
    or a0, a0, a2
    ret

.Lbf16_mul_special_b:
    andi t0, a1, 127
    beqz t0, .Lbf16_mul_b_inf
    mv a0, a1
    ret
.Lbf16_mul_b_inf:
    beqz a3, .Lbf16_mul_nan
    j .Lbf16_mul_inf

.Lbf16_mul_zero:
    mv a0, a2
    ret
.Lbf16_mul_nan:
    li a0, 0x7fc0
.Lbf16_mul_return:
    ret
    .size bf16_mul_asm, .-bf16_mul_asm

    .globl bf16_sqrt_asm
    .type bf16_sqrt_asm, @function
    .align 2
bf16_sqrt_asm:
    li t0, 0x7fff
    and t1, a0, t0
    li t0, 0x7f80
    bltu t0, t1, .Lbf16_sqrt_return
    beqz t1, .Lbf16_sqrt_zero
    srli t2, a0, 15
    bnez t2, .Lbf16_sqrt_nan
    beq t1, t0, .Lbf16_sqrt_return
    srli a1, t1, 7
    beqz a1, .Lbf16_sqrt_zero

    andi t0, a0, 127
    ori t0, t0, 128
    andi t1, a1, 1
    bnez t1, .Lbf16_sqrt_even
    slli t0, t0, 1
.Lbf16_sqrt_even:
    addi a1, a1, 127
    srli a1, a1, 1
    slli a1, a1, 7

    # The contract is isqrt(128 * (mantissa + 1) - 1).
    addi t0, t0, 1
    slli t0, t0, 7
    addi t0, t0, -1

    # The radicand is in [16511, 65407], so root bit 7 is always set.
    li t1, 0x4000
    sub t0, t0, t1
    li t2, 0x1000

    # Seven remaining digit-by-digit square-root steps.
    .rept 7
    add t3, t1, t2
    srli t1, t1, 1
    bltu t0, t3, 1f
    sub t0, t0, t3
    add t1, t1, t2
1:
    srli t2, t2, 2
    .endr

    andi t1, t1, 127
    or a0, a1, t1
    ret

.Lbf16_sqrt_zero:
    li a0, 0
    ret
.Lbf16_sqrt_nan:
    li a0, 0x7fc0
.Lbf16_sqrt_return:
    ret
    .size bf16_sqrt_asm, .-bf16_sqrt_asm

    .section .note.GNU-stack,"",@progbits
