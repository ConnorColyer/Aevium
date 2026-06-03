#include <metal_stdlib>
using namespace metal;

struct BucketExtremaUniforms {
    uint pointCount;
    uint bucketSize;
    uint bucketCount;
    uint padding;
};

struct BucketExtremaResult {
    uint firstIndex;
    uint lowIndex;
    uint highIndex;
    uint lastIndex;
};

struct AnalyticsUniforms {
    uint pointCount;
    uint threadsPerGrid;
    uint padding0;
    uint padding1;
};

struct AnalyticsPartial {
    float minPrice;
    float maxPrice;
    float sumPrice;
    float sumSquares;
    float weightedPriceSum;
    float returnSum;
    float returnSquares;
    float negativeReturnSquares;
    float absoluteMovePercentSum;
    float pathLength;
    uint returnCount;
    uint negativeReturnCount;
};

kernel void aevium_bucket_extrema(
    const device float *prices [[buffer(0)]],
    constant BucketExtremaUniforms &uniforms [[buffer(1)]],
    device BucketExtremaResult *results [[buffer(2)]],
    uint bucketIndex [[thread_position_in_grid]]
) {
    if (bucketIndex >= uniforms.bucketCount || uniforms.pointCount == 0) {
        return;
    }

    const uint start = bucketIndex * uniforms.bucketSize;
    if (start >= uniforms.pointCount) {
        results[bucketIndex] = BucketExtremaResult{0, 0, 0, 0};
        return;
    }

    const uint end = min(start + uniforms.bucketSize, uniforms.pointCount);
    uint lowIndex = start;
    uint highIndex = start;
    float lowValue = prices[start];
    float highValue = prices[start];

    for (uint index = start + 1; index < end; index += 1) {
        const float value = prices[index];
        if (value < lowValue) {
            lowValue = value;
            lowIndex = index;
        }
        if (value > highValue) {
            highValue = value;
            highIndex = index;
        }
    }

    results[bucketIndex] = BucketExtremaResult{
        start,
        lowIndex,
        highIndex,
        end - 1
    };
}

kernel void aevium_series_partials(
    const device float *prices [[buffer(0)]],
    constant AnalyticsUniforms &uniforms [[buffer(1)]],
    device AnalyticsPartial *partials [[buffer(2)]],
    uint globalIndex [[thread_position_in_grid]],
    uint localIndex [[thread_position_in_threadgroup]],
    uint groupIndex [[threadgroup_position_in_grid]]
) {
    threadgroup float minPrice[256];
    threadgroup float maxPrice[256];
    threadgroup float sumPrice[256];
    threadgroup float sumSquares[256];
    threadgroup float weightedPriceSum[256];
    threadgroup float returnSum[256];
    threadgroup float returnSquares[256];
    threadgroup float negativeReturnSquares[256];
    threadgroup float absoluteMovePercentSum[256];
    threadgroup float pathLength[256];
    threadgroup uint returnCount[256];
    threadgroup uint negativeReturnCount[256];

    float localMin = FLT_MAX;
    float localMax = -FLT_MAX;
    float localSum = 0.0;
    float localSquares = 0.0;
    float localWeighted = 0.0;
    float localReturnSum = 0.0;
    float localReturnSquares = 0.0;
    float localNegativeSquares = 0.0;
    float localAbsoluteMove = 0.0;
    float localPathLength = 0.0;
    uint localReturnCount = 0;
    uint localNegativeCount = 0;

    for (uint index = globalIndex; index < uniforms.pointCount; index += uniforms.threadsPerGrid) {
        const float value = prices[index];
        localMin = min(localMin, value);
        localMax = max(localMax, value);
        localSum += value;
        localSquares += value * value;
        localWeighted += value * float(index + 1);

        if (index > 0) {
            const float previous = prices[index - 1];
            const float difference = value - previous;
            const float safePrevious = max(abs(previous), 0.0001);
            const float priceReturn = previous == 0.0 ? 0.0 : difference / previous;

            localReturnSum += priceReturn;
            localReturnSquares += priceReturn * priceReturn;
            localAbsoluteMove += abs(difference) / safePrevious;
            localPathLength += abs(difference);
            localReturnCount += 1;

            if (priceReturn < 0.0) {
                localNegativeSquares += priceReturn * priceReturn;
                localNegativeCount += 1;
            }
        }
    }

    minPrice[localIndex] = localMin;
    maxPrice[localIndex] = localMax;
    sumPrice[localIndex] = localSum;
    sumSquares[localIndex] = localSquares;
    weightedPriceSum[localIndex] = localWeighted;
    returnSum[localIndex] = localReturnSum;
    returnSquares[localIndex] = localReturnSquares;
    negativeReturnSquares[localIndex] = localNegativeSquares;
    absoluteMovePercentSum[localIndex] = localAbsoluteMove;
    pathLength[localIndex] = localPathLength;
    returnCount[localIndex] = localReturnCount;
    negativeReturnCount[localIndex] = localNegativeCount;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (localIndex < stride) {
            minPrice[localIndex] = min(minPrice[localIndex], minPrice[localIndex + stride]);
            maxPrice[localIndex] = max(maxPrice[localIndex], maxPrice[localIndex + stride]);
            sumPrice[localIndex] += sumPrice[localIndex + stride];
            sumSquares[localIndex] += sumSquares[localIndex + stride];
            weightedPriceSum[localIndex] += weightedPriceSum[localIndex + stride];
            returnSum[localIndex] += returnSum[localIndex + stride];
            returnSquares[localIndex] += returnSquares[localIndex + stride];
            negativeReturnSquares[localIndex] += negativeReturnSquares[localIndex + stride];
            absoluteMovePercentSum[localIndex] += absoluteMovePercentSum[localIndex + stride];
            pathLength[localIndex] += pathLength[localIndex + stride];
            returnCount[localIndex] += returnCount[localIndex + stride];
            negativeReturnCount[localIndex] += negativeReturnCount[localIndex + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (localIndex == 0) {
        partials[groupIndex] = AnalyticsPartial{
            minPrice[0],
            maxPrice[0],
            sumPrice[0],
            sumSquares[0],
            weightedPriceSum[0],
            returnSum[0],
            returnSquares[0],
            negativeReturnSquares[0],
            absoluteMovePercentSum[0],
            pathLength[0],
            returnCount[0],
            negativeReturnCount[0]
        };
    }
}
