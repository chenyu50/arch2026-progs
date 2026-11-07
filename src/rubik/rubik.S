# Buffer-oriented wrapper for the HW1 coordinate IDA* solver.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap);
# a0 = input, a1 = output, a2 = capacity; result in a0.
# s0 = output, s1 = capacity, s2 = length; t0..t5 = scratch.
# Stack: state at 0..13, path at 16..26, saved registers at 48..60.

    .text
    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
    addi    sp, sp, -64
    sw      ra, 60(sp)
    sw      s0, 56(sp)
    sw      s1, 52(sp)
    sw      s2, 48(sp)

    mv      s0, a1
    mv      s1, a2

    # Validate before touching the caller's output buffer.
    mv      a1, sp
    call    parse_state_asm
    beqz    a0, .Lrubik_invalid
    beqz    s1, .Lrubik_small

    mv      a0, sp
    call    rank_coordinates_asm
    or      t0, a0, a1
    beqz    t0, .Lrubik_solved

    addi    a2, sp, 16
    call    ida_search_asm
    bltz    a0, .Lrubik_invalid
    mv      s2, a0

    # Required bytes for n > 0 are 2*n plus the suffix count.
    slli    t0, s2, 1
    addi    t1, sp, 16
    mv      t2, s2
    la      t3, .Lrubik_tokens
.Lrubik_count:
    lbu     t4, 0(t1)
    slli    t4, t4, 1
    add     t4, t3, t4
    lbu     t4, 1(t4)
    snez    t4, t4
    add     t0, t0, t4
    addi    t1, t1, 1
    addi    t2, t2, -1
    bnez    t2, .Lrubik_count

    bltu    s1, t0, .Lrubik_small

    mv      t0, s0
    addi    t1, sp, 16
    mv      t2, s2
    la      t3, .Lrubik_tokens
.Lrubik_format:
    lbu     t4, 0(t1)
    slli    t4, t4, 1
    add     t4, t3, t4

    lbu     t5, 0(t4)
    sb      t5, 0(t0)
    addi    t0, t0, 1

    lbu     t5, 1(t4)
    beqz    t5, .Lrubik_separator
    sb      t5, 0(t0)
    addi    t0, t0, 1

.Lrubik_separator:
    addi    t1, t1, 1
    addi    t2, t2, -1
    beqz    t2, .Lrubik_terminate

    li      t5, 32
    sb      t5, 0(t0)
    addi    t0, t0, 1
    j       .Lrubik_format

.Lrubik_terminate:
    sb      zero, 0(t0)
    mv      a0, s2
    j       .Lrubik_return

.Lrubik_solved:
    sb      zero, 0(s0)
    li      a0, 0
    j       .Lrubik_return

.Lrubik_small:
    beqz    s1, .Lrubik_small_return
    sb      zero, 0(s0)
.Lrubik_small_return:
    li      a0, -2
    j       .Lrubik_return

.Lrubik_invalid:
    li      a0, -1

.Lrubik_return:
    lw      s2, 48(sp)
    lw      s1, 52(sp)
    lw      s0, 56(sp)
    lw      ra, 60(sp)
    addi    sp, sp, 64
    ret
    .size   rubik_solve_asm, .-rubik_solve_asm

    .section .rodata.rubik_wrapper,"a",@progbits
.Lrubik_tokens:
    # Two bytes per move: face letter and optional suffix.
    .byte   82, 0, 82, 50, 82, 39
    .byte   66, 0, 66, 50, 66, 39
    .byte   68, 0, 68, 50, 68, 39
