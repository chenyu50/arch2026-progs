.section .text,"ax",@progbits
.globl ida_search_asm
.type ida_search_asm,@function
# a0: permutation rank, a1: orientation rank, a2: 11-byte path.
# Return a0 = optimal length, or -1 if no solution is found.
ida_search_asm:
    # 12 frames of 16 bytes, followed by a 48-byte save area.
    addi sp, sp, -240
    sw s0, 192(sp)
    sw s1, 196(sp)
    sw s2, 200(sp)
    sw s3, 204(sp)
    sw s4, 208(sp)
    sw s5, 212(sp)
    sw s6, 216(sp)
    sw s7, 220(sp)
    sw s8, 224(sp)
    sw s9, 228(sp)
    sw s10, 232(sp)

    mv s0, a0
    mv s1, a1
    mv s2, a2
    la s6, search_table_bases
    la s7, perm_distance
    la s8, ori_distance
    li t6, 3
    add t0, s7, s0
    lbu s3, 0(t0)
    add t0, s8, s1
    lbu t1, 0(t0)
    bgeu s3, t1, .Lsearch_bound_ready
    mv s3, t1
.Lsearch_bound_ready:
    li t0, 11
    bltu t0, s3, .Lsearch_failed

.Lsearch_round:
    li s4, 0
    mv s5, sp
    mv s9, s0
    mv s10, s1
    mv a3, s0
    mv a4, s1
    li a5, 0
    li a6, 0
    li a7, 3

.Lsearch_loop:
    or t0, s9, s10
    beqz t0, .Lsearch_found
    beq s4, s3, .Lsearch_backtrack
    sltiu t0, a5, 3
    beqz t0, .Lsearch_backtrack
    beq a5, a7, .Lsearch_next_face

    # Reuse the transition-table bases while the face is unchanged.
    beq a5, t6, .Lsearch_bases_ready
    slli t0, a5, 3
    add t0, s6, t0
    lw t4, 0(t0)
    lw t5, 4(t0)
    mv t6, a5
.Lsearch_bases_ready:
    slli t3, a3, 1
    add t1, t4, t3
    lhu a0, 0(t1)
    slli t3, a4, 1
    add t2, t5, t3
    lhu a1, 0(t2)
    mv a3, a0
    mv a4, a1

    # Retain the move being tried before advancing the parent cursor.
    mv t3, a5
    mv a2, a6
    addi a6, a6, 1
    li t0, 3
    bne a6, t0, .Lsearch_heuristic
    addi a5, a5, 1
    li a6, 0
    mv a3, s9
    mv a4, s10

.Lsearch_heuristic:
    add t0, s7, a0
    lbu t1, 0(t0)
    add t0, s8, a1
    lbu t2, 0(t0)
    bgeu t1, t2, .Lsearch_max_ready
    mv t1, t2
.Lsearch_max_ready:
    add t1, t1, s4
    addi t1, t1, 1
    bltu s3, t1, .Lsearch_loop

    # Record this move and save the parent only when descending.
    slli t0, t3, 1
    add t0, t0, t3
    add t0, t0, a2
    add t1, s2, s4
    sb t0, 0(t1)

    sh s9, 0(s5)
    sh s10, 2(s5)
    sh a3, 4(s5)
    sh a4, 6(s5)
    sb a5, 8(s5)
    sb a6, 9(s5)
    sb a7, 10(s5)

    addi s4, s4, 1
    addi s5, s5, 16
    mv s9, a0
    mv s10, a1
    mv a3, a0
    mv a4, a1
    li a5, 0
    li a6, 0
    mv a7, t3
    j .Lsearch_loop

.Lsearch_next_face:
    addi a5, a5, 1
    li a6, 0
    mv a3, s9
    mv a4, s10
    j .Lsearch_loop

.Lsearch_backtrack:
    beqz s4, .Lsearch_next_bound
    addi s4, s4, -1
    addi s5, s5, -16
    lhu s9, 0(s5)
    lhu s10, 2(s5)
    lhu a3, 4(s5)
    lhu a4, 6(s5)
    lbu a5, 8(s5)
    lbu a6, 9(s5)
    lbu a7, 10(s5)
    j .Lsearch_loop

.Lsearch_next_bound:
    addi s3, s3, 1
    li t0, 11
    bgeu t0, s3, .Lsearch_round
.Lsearch_failed:
    li a0, -1
    j .Lsearch_return

.Lsearch_found:
    mv a0, s4
.Lsearch_return:
    lw s0, 192(sp)
    lw s1, 196(sp)
    lw s2, 200(sp)
    lw s3, 204(sp)
    lw s4, 208(sp)
    lw s5, 212(sp)
    lw s6, 216(sp)
    lw s7, 220(sp)
    lw s8, 224(sp)
    lw s9, 228(sp)
    lw s10, 232(sp)
    addi sp, sp, 240
    ret
.size ida_search_asm, .-ida_search_asm

.section .rodata.search,"a",@progbits
.align 2
search_table_bases:
    .word permutation, orientation
    .word permutation + 10080, orientation + 1458
    .word permutation + 20160, orientation + 2916

.include "src/rubik/hw1_tables.inc"
