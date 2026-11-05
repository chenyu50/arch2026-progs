# Binary GCD using shifts and subtraction.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)
# Inputs: a0 = a, a1 = b
# Output: a0 = greatest common divisor
# Registers: t0 = common shift, t1 = parity test, t2 = swap temporary
# Leaf function; no stack storage is required.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    # Handle zero before entering any factor-of-two loop.
    beqz    a0, .Lgcd_return_b
    beqz    a1, .Lgcd_return

    li      t0, 0

.Lgcd_common:
    # Remove powers of two shared by both operands.
    or      t1, a0, a1
    andi    t1, t1, 1
    bnez    t1, .Lgcd_strip_a

    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    t0, t0, 1
    j       .Lgcd_common

.Lgcd_strip_a:
    # Keep a0 odd throughout the main loop.
    andi    t1, a0, 1
    bnez    t1, .Lgcd_strip_b

    srli    a0, a0, 1
    j       .Lgcd_strip_a

.Lgcd_strip_b:
    # a1 is nonzero whenever this loop is entered.
    andi    t1, a1, 1
    bnez    t1, .Lgcd_order

    srli    a1, a1, 1
    j       .Lgcd_strip_b

.Lgcd_order:
    # Order unsigned operands before subtraction.
    bgeu    a1, a0, .Lgcd_subtract
    mv      t2, a0
    mv      a0, a1
    mv      a1, t2

.Lgcd_subtract:
    sub     a1, a1, a0
    bnez    a1, .Lgcd_strip_b

    # Restore the common power of two.
    sll     a0, a0, t0

.Lgcd_return:
    ret

.Lgcd_return_b:
    mv      a0, a1
    ret

    .size   gcd_u32_asm, .-gcd_u32_asm
