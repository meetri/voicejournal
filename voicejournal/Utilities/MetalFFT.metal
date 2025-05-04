#include <metal_stdlib>
using namespace metal;

// Butterfly operation for FFT
kernel void butterflyOperation(
    device float2* buffer [[buffer(0)]],
    device float2* output [[buffer(1)]],
    constant uint& stage [[buffer(2)]],
    constant uint& N [[buffer(3)]],
    uint id [[thread_position_in_grid]])
{
    uint butterfly_size = 1 << stage;
    uint half_butterfly = butterfly_size >> 1;
    
    uint group = id / half_butterfly;
    uint in_group_idx = id % half_butterfly;
    
    uint idx1 = group * butterfly_size + in_group_idx;
    uint idx2 = idx1 + half_butterfly;
    
    float angle = -2.0 * M_PI_F * float(in_group_idx) / float(butterfly_size);
    float2 twiddle = float2(cos(angle), sin(angle));
    
    float2 val1 = buffer[idx1];
    float2 val2 = buffer[idx2];
    
    // Multiply val2 by twiddle factor
    float2 val2_twiddle;
    val2_twiddle.x = val2.x * twiddle.x - val2.y * twiddle.y;
    val2_twiddle.y = val2.x * twiddle.y + val2.y * twiddle.x;
    
    // Butterfly computation
    output[idx1] = val1 + val2_twiddle;
    output[idx2] = val1 - val2_twiddle;
}

// Bit reversal for FFT input reordering
kernel void bitReversal(
    device float2* input [[buffer(0)]],
    device float2* output [[buffer(1)]],
    constant uint& N [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    if (id >= N) return;
    
    uint reversed = 0;
    uint temp = id;
    uint log2N = 0;
    uint tempN = N;
    
    while (tempN > 1) {
        tempN >>= 1;
        log2N++;
    }
    
    for (uint i = 0; i < log2N; i++) {
        reversed = (reversed << 1) | (temp & 1);
        temp >>= 1;
    }
    
    output[reversed] = input[id];
}

// Compute magnitudes from complex FFT result
kernel void computeMagnitudes(
    device float2* input [[buffer(0)]],
    device float* output [[buffer(1)]],
    constant uint& N [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    if (id >= N) return;
    
    // Calculate magnitude
    float real = input[id].x;
    float imag = input[id].y;
    output[id] = sqrt(real * real + imag * imag);
}