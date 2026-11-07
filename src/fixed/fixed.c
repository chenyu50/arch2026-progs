#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;
    while (b != 0) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        passes++;
    }
    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t ua = (uint32_t) a;
    uint32_t ub = (uint32_t) b;
    uint32_t multiplier = ub;
    uint32_t term_lo = ua, term_hi = 0;
    uint32_t lo = 0, hi = 0;

    /* Form the product as two words without a 64-bit multiply helper. */
    while (multiplier != 0) {
        if ((multiplier & 1u) != 0) {
            uint32_t old_lo = lo;
            lo += term_lo;
            hi += term_hi + (uint32_t) (lo < old_lo);
        }
        term_hi = (term_hi << 1) | (term_lo >> 31);
        term_lo <<= 1;
        multiplier >>= 1;
    }

    /* Signedness corrections affect only the high word. */
    if (a < 0)
        hi -= ub;
    if (b < 0)
        hi -= ua;

    uint32_t rounded_lo = lo + (UINT32_C(1) << (Q - 1));
    hi += (uint32_t) (rounded_lo < lo);

    /* These bits are identical for logical and arithmetic 64-bit shifts. */
    uint32_t bits = (rounded_lo >> Q) | (hi << (32 - Q));
    if (bits <= INT32_MAX)
        return (int32_t) bits;
    return -1 - (int32_t) (UINT32_MAX - bits);
}
