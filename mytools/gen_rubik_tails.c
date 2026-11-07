#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../src/rubik/hw1_tables.h"

enum {
    P_COUNT = 5040,
    O_COUNT = 729,
    STATE_COUNT = P_COUNT * O_COUNT,
    MAX_DEPTH = 11,
    TAIL_RADIUS = 5,
    TAIL_COUNT = 12224,
    FAR_COUNT = 2644
};

/* High nibble: exact distance. Low nibble: move toward solved. */
static uint8_t *info;
static uint32_t tail_entries[TAIL_COUNT];
static uint32_t far_entries[FAR_COUNT];

static void fail(const char *message)
{
    fprintf(stderr, "error: %s\n", message);
    exit(EXIT_FAILURE);
}

static uint32_t packed_entry(uint32_t id, unsigned move)
{
    uint32_t p = id / O_COUNT;
    uint32_t o = id % O_COUNT;
    return (p << 14) | (o << 4) | move;
}

static uint32_t next_state(uint32_t id, unsigned move)
{
    if (move >= 9)
        fail("move index outside 0..8");

    uint32_t p = id / O_COUNT;
    uint32_t o = id % O_COUNT;
    unsigned face = move / 3;
    unsigned turns = move % 3 + 1;

    for (unsigned i = 0; i < turns; ++i) {
        p = permutation[face][p];
        o = orientation[face][o];
    }
    return p * O_COUNT + o;
}

static void validate_transitions(void)
{
    for (unsigned face = 0; face < 3; ++face) {
        for (uint32_t p = 0; p < P_COUNT; ++p) {
            uint32_t value = p;
            for (unsigned turn = 0; turn < 4; ++turn) {
                value = permutation[face][value];
                if (value >= P_COUNT)
                    fail("permutation transition outside its domain");
            }
            if (value != p)
                fail("four permutation quarter turns are not identity");
        }

        for (uint32_t o = 0; o < O_COUNT; ++o) {
            uint32_t value = o;
            for (unsigned turn = 0; turn < 4; ++turn) {
                value = orientation[face][value];
                if (value >= O_COUNT)
                    fail("orientation transition outside its domain");
            }
            if (value != o)
                fail("four orientation quarter turns are not identity");
        }
    }
}

static void build_distances(void)
{
    uint32_t *queue = malloc((size_t) STATE_COUNT * sizeof *queue);
    info = malloc((size_t) STATE_COUNT);

    if (queue == NULL || info == NULL)
        fail("cannot allocate the BFS working arrays");

    memset(info, 0xFF, (size_t) STATE_COUNT);

    uint32_t layers[MAX_DEPTH + 1] = {0};
    uint32_t head = 0, tail = 1;
    queue[0] = 0;
    info[0] = 0;
    layers[0] = 1;

    while (head < tail) {
        uint32_t id = queue[head++];
        uint32_t p = id / O_COUNT;
        uint32_t o = id % O_COUNT;
        unsigned distance = info[id] >> 4;

        for (unsigned face = 0; face < 3; ++face) {
            uint32_t child_p = p, child_o = o;

            for (unsigned turn = 0; turn < 3; ++turn) {
                child_p = permutation[face][child_p];
                child_o = orientation[face][child_o];
                uint32_t child = child_p * O_COUNT + child_o;

                if (info[child] != 0xFF)
                    continue;

                unsigned next_distance = distance + 1;
                if (next_distance > MAX_DEPTH)
                    fail("a distance exceeds the expected diameter");
                if (tail >= STATE_COUNT)
                    fail("BFS queue overflow");

                unsigned reverse_move = face * 3 + 2 - turn;
                info[child] = (uint8_t) ((next_distance << 4) | reverse_move);
                queue[tail++] = child;
                ++layers[next_distance];
            }
        }
    }

    free(queue);

    if (tail != STATE_COUNT)
        fail("the transition graph did not reach every coordinate state");

    fprintf(stderr, "Reached %" PRIu32 " states\n", tail);
    for (unsigned d = 0; d <= MAX_DEPTH; ++d)
        fprintf(stderr, "distance %u: %" PRIu32 "\n", d, layers[d]);
}

static void build_entries(void)
{
    size_t tail_count = 0, far_count = 0;

    for (uint32_t id = 0; id < STATE_COUNT; ++id) {
        unsigned distance = info[id] >> 4;
        unsigned move = info[id] & 15U;
        uint32_t p = id / O_COUNT;
        uint32_t o = id % O_COUNT;

        if (distance > MAX_DEPTH || move >= 9)
            fail("invalid BFS metadata");

        if (perm_distance[p] > distance || ori_distance[o] > distance)
            fail("a projection heuristic exceeds the exact distance");

        if (id != 0) {
            uint32_t next = next_state(id, move);
            if ((unsigned) (info[next] >> 4) + 1 != distance)
                fail("a recorded parent move does not reduce distance");
        }

        uint32_t entry = packed_entry(id, move);

        if (distance <= TAIL_RADIUS) {
            if (tail_count >= TAIL_COUNT)
                fail("too many states in the shallow table");
            tail_entries[tail_count++] = entry;
        }

        if (distance == MAX_DEPTH) {
            if (far_count >= FAR_COUNT)
                fail("too many states at distance 11");
            far_entries[far_count++] = entry;
        }
    }

    if (tail_count != TAIL_COUNT || far_count != FAR_COUNT)
        fail("exact-table counts do not match the expected model");

    fprintf(stderr, "Tail entries: %zu, far entries: %zu\n", tail_count,
            far_count);
}

static int lookup(const uint32_t *entries, size_t count, uint32_t id)
{
    uint32_t target = packed_entry(id, 0);
    size_t lo = 0, hi = count;

    while (lo < hi) {
        size_t mid = lo + (hi - lo) / 2;
        if (entries[mid] < target)
            lo = mid + 1;
        else
            hi = mid;
    }

    if (lo == count || (entries[lo] & UINT32_C(0xFFFFFFF0)) != target)
        return -1;

    return (int) (entries[lo] & 15U);
}

static uint32_t unpack_id(uint32_t entry)
{
    uint32_t p = entry >> 14;
    uint32_t o = (entry >> 4) & UINT32_C(0x3FF);

    if (p >= P_COUNT || o >= O_COUNT)
        fail("packed entry contains an invalid coordinate");

    return p * O_COUNT + o;
}

static void validate_entries(const uint32_t *entries,
                             size_t count,
                             int far_table)
{
    for (size_t i = 0; i < count; ++i) {
        uint32_t entry = entries[i];
        uint32_t id = unpack_id(entry);
        unsigned distance = info[id] >> 4;

        if (i != 0 && (entries[i - 1] >> 4) >= (entry >> 4))
            fail("packed keys are not strictly increasing");

        if (lookup(entries, count, id) != (int) (entry & 15U))
            fail("packed binary lookup returned the wrong move");

        if (far_table) {
            if (distance != MAX_DEPTH)
                fail("far table contains a state outside distance 11");
        } else if (distance > TAIL_RADIUS) {
            fail("tail table contains a state beyond distance 5");
        }

        if (id != 0) {
            uint32_t next = next_state(id, entry & 15U);
            if ((unsigned) (info[next] >> 4) + 1 != distance)
                fail("a packed first move does not reduce exact distance");
        }
    }
}

static void validate_tail_replay(void)
{
    for (size_t i = 0; i < TAIL_COUNT; ++i) {
        uint32_t id = unpack_id(tail_entries[i]);
        unsigned expected = info[id] >> 4;
        unsigned steps = 0;

        while (id != 0) {
            int move = lookup(tail_entries, TAIL_COUNT, id);
            if (move < 0 || ++steps > TAIL_RADIUS)
                fail("tail reconstruction failed");
            id = next_state(id, (unsigned) move);
        }

        if (steps != expected)
            fail("tail reconstruction is not shortest");
    }
}

static void emit_entries(const char *name,
                         const uint32_t *entries,
                         size_t count)
{
    printf(".balign 4\n%s:\n", name);

    for (size_t i = 0; i < count; ++i) {
        if ((i & 7U) == 0)
            fputs("    .word ", stdout);

        printf("0x%08" PRIx32, entries[i]);
        fputs((i & 7U) == 7U || i + 1 == count ? "\n" : ",", stdout);
    }
}

int main(void)
{
    validate_transitions();
    build_distances();
    build_entries();
    validate_entries(tail_entries, TAIL_COUNT, 0);
    validate_entries(far_entries, FAR_COUNT, 1);
    validate_tail_replay();

    fprintf(stderr, "All parent edges, packed lookups, and tails verified\n");
    fprintf(stderr, "Generated payload: %zu bytes\n",
            sizeof tail_entries + sizeof far_entries);

    fputs(
        "# Generated from a complete host BFS; do not edit.\n"
        "# Entry: (p << 14) | (o << 4) | move toward solved.\n"
        ".section .rodata.rubik_exact,\"a\",@progbits\n",
        stdout);
    printf(".equ RUBIK_TAIL_COUNT, %u\n", (unsigned) TAIL_COUNT);
    printf(".equ RUBIK_FAR_COUNT, %u\n", (unsigned) FAR_COUNT);

    emit_entries("rubik_tail_entries", tail_entries, TAIL_COUNT);
    emit_entries("rubik_far_entries", far_entries, FAR_COUNT);

    free(info);

    if (fflush(stdout) == EOF || ferror(stdout))
        fail("cannot write the generated assembly table");

    return EXIT_SUCCESS;
}
