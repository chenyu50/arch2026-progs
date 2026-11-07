#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    if ((f32bits & 0x7F800000u) == 0x7F800000u)
        return (uint16_t) (f32bits >> 16);

    uint32_t bias = 0x7FFFu + ((f32bits >> 16) & 1u);
    return (uint16_t) ((f32bits + bias) >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint32_t sign = (a ^ b) & 0x8000u;
    uint32_t abs_a = a & 0x7FFFu;
    uint32_t abs_b = b & 0x7FFFu;
    uint32_t ma = a & 0x7Fu;
    uint32_t mb = b & 0x7Fu;
    int ea = (a >> 7) & 0xFF;
    int eb = (b >> 7) & 0xFF;

    /* Special values must be examined in operand order. */
    if (ea == 0xFF) {
        if (ma != 0)
            return a;
        if (abs_b == 0)
            return 0x7FC0u;
        return (uint16_t) (sign | 0x7F80u);
    }
    if (eb == 0xFF) {
        if (mb != 0)
            return b;
        if (abs_a == 0)
            return 0x7FC0u;
        return (uint16_t) (sign | 0x7F80u);
    }
    if (abs_a == 0 || abs_b == 0)
        return (uint16_t) sign;

    if (ea == 0) {
        ea = 1;
        while (ma < 0x80u) {
            ma <<= 1;
            ea--;
        }
    } else {
        ma |= 0x80u;
    }

    if (eb == 0) {
        eb = 1;
        while (mb < 0x80u) {
            mb <<= 1;
            eb--;
        }
    } else {
        mb |= 0x80u;
    }

    uint32_t product = ma * mb;
    int exponent = ea + eb - 127;
    if (product >= 0x8000u) {
        product >>= 1;
        exponent++;
    }
    uint32_t mantissa = product >> 7;

    if (exponent >= 0xFF)
        return (uint16_t) (sign | 0x7F80u);
    if (exponent <= 0) {
        if (exponent < -6)
            return (uint16_t) sign;
        /* The contract shifts the fraction without the implicit leading one. */
        return (uint16_t) (sign | ((mantissa & 0x7Fu) >> (1 - exponent)));
    }
    return (uint16_t) (sign | ((uint32_t) exponent << 7) | (mantissa & 0x7Fu));
}

uint16_t bf16_sqrt(uint16_t a)
{
    uint32_t magnitude = a & 0x7FFFu;
    if (magnitude > 0x7F80u)
        return a;
    if (magnitude == 0)
        return 0;
    if ((a & 0x8000u) != 0)
        return 0x7FC0u;
    if (magnitude == 0x7F80u)
        return a;

    uint32_t exponent = magnitude >> 7;
    if (exponent == 0)
        return 0;

    uint32_t mantissa = (a & 0x7Fu) | 0x80u;
    /* An even biased exponent means an odd unbiased exponent. */
    if ((exponent & 1u) == 0)
        mantissa <<= 1;

    /* Keep the contract's truncated comparison, rather than ideal sqrt. */
    uint32_t low = 128;
    uint32_t high = 256;
    while (high - low > 1) {
        uint32_t mid = (low + high) >> 1;
        if (((mid * mid) >> 7) <= mantissa)
            low = mid;
        else
            high = mid;
    }

    uint32_t result_exponent = (exponent + 127u) >> 1;
    return (uint16_t) ((result_exponent << 7) | (low & 0x7Fu));
}
