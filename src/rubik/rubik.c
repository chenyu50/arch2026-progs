#include "rubik.h"
#include "hw1_tables.h"

/*
 * Coordinate ranking and IDA* search adapted from chenyu50/minirubik,
 * commit 6c5a7cab4c4a57de3ed6e3db860d535f4723e8fd.
 */
enum { CUBIES = 7, MOVES = 9, MAX_DEPTH = 11 };

typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

static const char move_text[MOVES][2] = {
    {'R', '\0'}, {'R', '2'},  {'R', '\''}, {'B', '\0'}, {'B', '2'},
    {'B', '\''}, {'D', '\0'}, {'D', '2'},  {'D', '\''},
};

static int valid(const state_t *state)
{
    uint8_t sum = 0;

    for (uint8_t i = 0; i < CUBIES; ++i) {
        if (state->p[i] >= CUBIES || state->o[i] >= 3)
            return 0;

        for (uint8_t j = 0; j < i; ++j) {
            if (state->p[j] == state->p[i])
                return 0;
        }

        sum = (uint8_t) (sum + state->o[i]);
    }

    return sum == 0 || sum == 3 || sum == 6 || sum == 9 || sum == 12;
}

static int parse_state(const char *input, state_t *state)
{
    /* Reject a short string at its terminator before reading later bytes. */
    for (int i = 0; i < RUBIK_STATE_LEN; ++i) {
        int limit = i < CUBIES ? CUBIES : 3;
        char digit = input[i];

        if (digit < '1' || digit > '0' + limit)
            return 0;

        if (i < CUBIES)
            state->p[i] = (uint8_t) (digit - '1');
        else
            state->o[i - CUBIES] = (uint8_t) (digit - '1');
    }

    return input[RUBIK_STATE_LEN] == '\0' && valid(state);
}

static void rank_coordinates(const state_t *state,
                             uint16_t *permutation_rank,
                             uint16_t *orientation_rank)
{
    uint8_t smaller[6];

    for (uint8_t i = 0; i < 6; ++i) {
        smaller[i] = 0;
        for (uint8_t j = (uint8_t) (i + 1U); j < CUBIES; ++j)
            smaller[i] += (uint8_t) (state->p[j] < state->p[i]);
    }

    uint32_t p = smaller[0];
    p = (p << 2) + (p << 1) + smaller[1];
    p = (p << 2) + p + smaller[2];
    p = (p << 2) + smaller[3];
    p = (p << 1) + p + smaller[4];
    p = (p << 1) + smaller[5];

    uint32_t o = 0;
    for (uint8_t i = 0; i < 6; ++i)
        o = (o << 1) + o + state->o[i];

    *permutation_rank = (uint16_t) p;
    *orientation_rank = (uint16_t) o;
}

static uint8_t heuristic(uint16_t p, uint16_t o)
{
    uint8_t hp = perm_distance[p], ho = ori_distance[o];
    return hp > ho ? hp : ho;
}

typedef struct {
    uint16_t p, o, next_p, next_o;
    uint8_t face, turn, previous_face;
} search_frame_t;

static int ida_search(uint16_t root_p,
                      uint16_t root_o,
                      uint8_t solution[MAX_DEPTH])
{
    search_frame_t frames[MAX_DEPTH + 1];

    for (unsigned bound = heuristic(root_p, root_o); bound <= MAX_DEPTH;
         ++bound) {
        unsigned depth = 0;
        frames[0] = (search_frame_t) {root_p, root_o, root_p, root_o, 0, 0, 3};

        for (;;) {
            search_frame_t *frame = &frames[depth];

            if (frame->p == 0 && frame->o == 0)
                return (int) depth;

            if (depth == bound || frame->face >= 3) {
                if (depth == 0)
                    break;
                --depth;
                continue;
            }

            if (frame->face == frame->previous_face) {
                ++frame->face;
                frame->turn = 0;
                frame->next_p = frame->p;
                frame->next_o = frame->o;
                continue;
            }

            uint8_t face = frame->face, turn = frame->turn;
            uint16_t child_p = permutation[face][frame->next_p];
            uint16_t child_o = orientation[face][frame->next_o];

            frame->next_p = child_p;
            frame->next_o = child_o;
            ++frame->turn;

            if (frame->turn == 3) {
                ++frame->face;
                frame->turn = 0;
                frame->next_p = frame->p;
                frame->next_o = frame->o;
            }

            if (depth + 1U + heuristic(child_p, child_o) > bound)
                continue;

            solution[depth] = (uint8_t) ((face << 1) + face + turn);
            ++depth;
            frames[depth] = (search_frame_t) {
                child_p, child_o, child_p, child_o, 0, 0, face};
        }
    }

    return -1;
}

int rubik_solve(const char *state, char *out, size_t cap)
{
    state_t cube;

    /* Validate before touching the output buffer. */
    if (!parse_state(state, &cube))
        return -1;

    if (cap == 0)
        return -2;

    uint16_t p, o;
    rank_coordinates(&cube, &p, &o);

    if (p == 0 && o == 0) {
        out[0] = '\0';
        return 0;
    }

    uint8_t path[MAX_DEPTH];
    int length = ida_search(p, o, path);

    /* Unreachable for a valid state with correct tables and search. */
    if (length < 0)
        return -1;

    size_t needed = 1;
    for (int i = 0; i < length; ++i) {
        needed += 1U + (move_text[path[i]][1] != '\0');
        if (i != 0)
            ++needed;
    }

    if (needed > cap) {
        out[0] = '\0';
        return -2;
    }

    size_t at = 0;
    for (int i = 0; i < length; ++i) {
        if (i != 0)
            out[at++] = ' ';

        out[at++] = move_text[path[i]][0];
        if (move_text[path[i]][1] != '\0')
            out[at++] = move_text[path[i]][1];
    }
    out[at] = '\0';

    return length;
}
