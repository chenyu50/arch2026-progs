# Coordinate prefix search with an exact five-move suffix table.
#
# a0 = permutation rank, a1 = orientation rank, a2 = 11-byte path.
# Return a0 = optimal move count, or -1 on an internal inconsistency.
#
# Packed entry: (p << 14) | (o << 4) | next_move.
# s0/s1 = root; s2 = path base; s3 = prefix limit or emitted length.
# s4 = depth; s5 = frame; s6 = transition bases; s7/s8 = distance bases.
# s9/s10 = current coordinates; s11 = optional leading move count.
# Frames: 0..95(sp); saves: 96..147(sp); root previous face: 148(sp).

.include "src/rubik/tail_tables.inc"

.section .text,"ax",@progbits
.balign 4
.globl ida_search_asm
.type ida_search_asm,@function
ida_search_asm:
    addi sp, sp, -160
    sw s0, 96(sp)
    sw s1, 100(sp)
    sw s2, 104(sp)
    sw s3, 108(sp)
    sw s4, 112(sp)
    sw s5, 116(sp)
    sw s6, 120(sp)
    sw s7, 124(sp)
    sw s8, 128(sp)
    sw s9, 132(sp)
    sw s10, 136(sp)
    sw s11, 140(sp)
    sw ra, 144(sp)

    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s9, a0
    mv s10, a1
    li s11, 0
    li t0, 3
    sw t0, 148(sp)

    la s6, search_table_bases
    la s7, perm_distance
    la s8, ori_distance

    or t0, s0, s1
    beqz t0, .Lexact_zero

    # Finish shallow states without a prefix search.
    call .Lexact_lookup_tail
    li s4, 0
    bgez a0, .Lexact_tail_begin

    # A distance-eleven entry supplies one move to distance ten.
    mv a0, s0
    mv a1, s1
    call .Lexact_lookup_far
    bltz a0, .Lexact_initial_bound

    sb a0, 0(s2)
    addi s2, s2, 1
    li s11, 1

    mv a2, a0
    mv a0, s0
    mv a1, s1
    call .Lexact_apply_coordinates
    mv s0, a0
    mv s1, a1
    sw a3, 148(sp)

.Lexact_initial_bound:
    add t0, s7, s0
    lbu s3, 0(t0)
    add t0, s8, s1
    lbu t1, 0(t0)
    bgeu s3, t1, .Lexact_initial_max
    mv s3, t1

.Lexact_initial_max:
    li t0, 6
    bgeu s3, t0, .Lexact_initial_ready
    mv s3, t0

.Lexact_initial_ready:
    # Total bound = prefix limit + five-move suffix.
    addi s3, s3, -5

.Lexact_round:
    li s4, 0
    mv s5, sp
    mv s9, s0
    mv s10, s1
    mv a3, s0
    mv a4, s1
    li a5, 0
    li a6, 0
    lw a7, 148(sp)
    li t6, 3

.Lexact_search_loop:
    beq s4, s3, .Lexact_leaf

    sltiu t0, a5, 3
    beqz t0, .Lexact_backtrack
    beq a5, a7, .Lexact_next_face

    # Cache transition bases while the face remains unchanged.
    beq a5, t6, .Lexact_bases_ready
    slli t0, a5, 3
    add t0, s6, t0
    lw t4, 0(t0)
    lw t5, 4(t0)
    mv t6, a5

.Lexact_bases_ready:
    slli t3, a3, 1
    add t1, t4, t3
    lhu a0, 0(t1)

    slli t3, a4, 1
    add t2, t5, t3
    lhu a1, 0(t2)

    mv a3, a0
    mv a4, a1

    # Preserve this move before advancing the parent cursor.
    mv t3, a5
    mv a2, a6
    addi a6, a6, 1
    li t0, 3
    bne a6, t0, .Lexact_heuristic

    addi a5, a5, 1
    li a6, 0
    mv a3, s9
    mv a4, s10

.Lexact_heuristic:
    add t0, s7, a0
    lbu t1, 0(t0)
    add t0, s8, a1
    lbu t2, 0(t0)
    bgeu t1, t2, .Lexact_max_ready
    mv t1, t2

.Lexact_max_ready:
    add t1, t1, s4
    addi t1, t1, 1
    addi t0, s3, 5
    bltu t0, t1, .Lexact_search_loop

    # Move ID = 3*face + turn.
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
    j .Lexact_search_loop

.Lexact_leaf:
    mv a0, s9
    mv a1, s10
    call .Lexact_lookup_tail
    bgez a0, .Lexact_tail_begin

    # Restore the parent's caller-saved cursor through backtracking.
    li t6, 3
    j .Lexact_backtrack

.Lexact_next_face:
    addi a5, a5, 1
    li a6, 0
    mv a3, s9
    mv a4, s10
    j .Lexact_search_loop

.Lexact_backtrack:
    beqz s4, .Lexact_next_bound
    addi s4, s4, -1
    addi s5, s5, -16
    lhu s9, 0(s5)
    lhu s10, 2(s5)
    lhu a3, 4(s5)
    lhu a4, 6(s5)
    lbu a5, 8(s5)
    lbu a6, 9(s5)
    lbu a7, 10(s5)
    j .Lexact_search_loop

.Lexact_next_bound:
    addi s3, s3, 1
    li t0, 5
    bgeu t0, s3, .Lexact_round
    j .Lexact_failed

.Lexact_tail_begin:
    mv s3, s4

.Lexact_tail_step:
    add t0, s2, s3
    sb a0, 0(t0)

    mv a2, a0
    mv a0, s9
    mv a1, s10
    call .Lexact_apply_coordinates
    mv s9, a0
    mv s10, a1
    addi s3, s3, 1

    or t0, s9, s10
    beqz t0, .Lexact_found

    mv a0, s9
    mv a1, s10
    call .Lexact_lookup_tail
    bltz a0, .Lexact_failed
    j .Lexact_tail_step

.Lexact_found:
    add a0, s3, s11
    j .Lexact_return

.Lexact_zero:
    li a0, 0
    j .Lexact_return

.Lexact_failed:
    li a0, -1

.Lexact_return:
    lw s0, 96(sp)
    lw s1, 100(sp)
    lw s2, 104(sp)
    lw s3, 108(sp)
    lw s4, 112(sp)
    lw s5, 116(sp)
    lw s6, 120(sp)
    lw s7, 124(sp)
    lw s8, 128(sp)
    lw s9, 132(sp)
    lw s10, 136(sp)
    lw s11, 140(sp)
    lw ra, 144(sp)
    addi sp, sp, 160
    ret
.size ida_search_asm, .-ida_search_asm

# Coordinate lookup: return the next move, or -1 when absent.
.Lexact_lookup_tail:
    la a2, rubik_tail_entries
    li a3, RUBIK_TAIL_COUNT
    j .Lexact_lookup

.Lexact_lookup_far:
    la a2, rubik_far_entries
    li a3, RUBIK_FAR_COUNT

.Lexact_lookup:
    # Compare entries against a key whose move bits are zero.
    slli t0, a0, 14
    slli t1, a1, 4
    or t0, t0, t1
    li a1, 0
    mv t3, a3

.Lexact_lower_bound:
    bgeu a1, a3, .Lexact_lookup_end
    add a4, a1, a3
    srli a4, a4, 1
    slli a6, a4, 2
    add a6, a2, a6
    lw a5, 0(a6)
    bltu a5, t0, .Lexact_lookup_right
    mv a3, a4
    j .Lexact_lower_bound

.Lexact_lookup_right:
    addi a1, a4, 1
    j .Lexact_lower_bound

.Lexact_lookup_end:
    bgeu a1, t3, .Lexact_lookup_missing
    slli a6, a1, 2
    add a6, a2, a6
    lw a5, 0(a6)
    andi a6, a5, -16
    bne a6, t0, .Lexact_lookup_missing
    andi a0, a5, 15
    ret

.Lexact_lookup_missing:
    li a0, -1
    ret

# Apply move a2 to coordinates a0/a1; return coordinates and face in a3.
.Lexact_apply_coordinates:
    li a3, 0
    li t0, 6
    bltu a2, t0, .Lexact_apply_check_b
    li a3, 2
    addi a2, a2, -6
    j .Lexact_apply_decoded

.Lexact_apply_check_b:
    li t0, 3
    bltu a2, t0, .Lexact_apply_decoded
    li a3, 1
    addi a2, a2, -3

.Lexact_apply_decoded:
    addi a2, a2, 1
    slli t0, a3, 3
    add t0, s6, t0
    lw t4, 0(t0)
    lw t5, 4(t0)

.Lexact_apply_turn:
    slli t0, a0, 1
    add t0, t4, t0
    lhu a0, 0(t0)
    slli t0, a1, 1
    add t0, t5, t0
    lhu a1, 0(t0)
    addi a2, a2, -1
    bnez a2, .Lexact_apply_turn
    ret

.section .rodata.search,"a",@progbits
.balign 4
search_table_bases:
    .word permutation, orientation
    .word permutation + 10080, orientation + 1458
    .word permutation + 20160, orientation + 2916

.include "src/rubik/hw1_tables.inc"
