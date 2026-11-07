.section .text,"ax",@progbits
.globl parse_state_asm
.type parse_state_asm,@function

# a0: input string, a1: 14-byte state buffer.
# Return a0 = 1 for valid input, or 0 for invalid input.
parse_state_asm:
    li t0, 7
    li t1, 0
.Lparse_permutation:
    lbu t2, 0(a0)
    addi t2, t2, -49
    sltiu t3, t2, 7
    beqz t3, .Lparse_invalid

    li t3, 1
    sll t3, t3, t2
    and t4, t1, t3
    bnez t4, .Lparse_invalid
    or t1, t1, t3
    sb t2, 0(a1)

    addi a0, a0, 1
    addi a1, a1, 1
    addi t0, t0, -1
    bnez t0, .Lparse_permutation

    li t0, 7
    li t5, 0
.Lparse_orientation:
    lbu t2, 0(a0)
    addi t2, t2, -49
    sltiu t3, t2, 3
    beqz t3, .Lparse_invalid
    sb t2, 0(a1)
    add t5, t5, t2

    addi a0, a0, 1
    addi a1, a1, 1
    addi t0, t0, -1
    bnez t0, .Lparse_orientation

    lbu t2, 0(a0)
    bnez t2, .Lparse_invalid

    li t3, 3
.Lparse_sum:
    bltu t5, t3, .Lparse_sum_done
    addi t5, t5, -3
    j .Lparse_sum
.Lparse_sum_done:
    bnez t5, .Lparse_invalid
    li a0, 1
    ret

.Lparse_invalid:
    li a0, 0
    ret
.size parse_state_asm, .-parse_state_asm

.globl rank_coordinates_asm
.type rank_coordinates_asm,@function
# a0: valid state buffer.
# Return a0 = permutation rank, a1 = orientation rank.
rank_coordinates_asm:
    li a1, 0
    li t0, 0
.Lrank_permutation:
    add t5, a0, t0
    lbu t3, 0(t5)
    li t2, 0
    addi t1, t0, 1
.Lrank_smaller:
    add t5, a0, t1
    lbu t4, 0(t5)
    sltu t4, t4, t3
    add t2, t2, t4
    addi t1, t1, 1
    li t5, 7
    bltu t1, t5, .Lrank_smaller

    li t5, 7
    sub t5, t5, t0
    li t6, 0
.Lrank_multiply:
    add t6, t6, a1
    addi t5, t5, -1
    bnez t5, .Lrank_multiply
    add a1, t6, t2

    addi t0, t0, 1
    li t5, 6
    bltu t0, t5, .Lrank_permutation

    mv a2, a1
    addi t0, a0, 7
    li a1, 0
    li t1, 6
.Lrank_orientation:
    lbu t2, 0(t0)
    slli t3, a1, 1
    add a1, t3, a1
    add a1, a1, t2
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, .Lrank_orientation

    mv a0, a2
    ret
.size rank_coordinates_asm, .-rank_coordinates_asm
