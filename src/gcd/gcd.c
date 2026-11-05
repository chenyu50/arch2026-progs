#include "gcd.h"

uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (a == 0)
        return b;
    if (b == 0)
        return a;

    /* Save the common power of two. */
    unsigned common_shift = 0;
    while (((a | b) & 1u) == 0u) {
        a >>= 1;
        b >>= 1;
        ++common_shift;
    }

    /* Keep a odd throughout the main loop. */
    while ((a & 1u) == 0u)
        a >>= 1;

    do {
        while ((b & 1u) == 0u)
            b >>= 1;

        /* Order the operands before subtraction. */
        if (a > b) {
            uint32_t temporary = a;
            a = b;
            b = temporary;
        }

        b -= a;
    } while (b != 0);

    return a << common_shift;
}
