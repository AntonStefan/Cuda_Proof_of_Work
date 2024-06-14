#include <stdio.h>
#include <stdint.h>
#include "../include/utils.cuh"
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>

#define MAX_NONCE 1e8
__constant__ BYTE d_difficulty_5_zeros[SHA256_HASH_SIZE] = "0000099999999999999999999999999999999999999999999999999999999999";

// TODO: Implement function to search for all nonces from 1 through MAX_NONCE (inclusive) using CUDA Threads
struct Result {
    uint32_t nonce;
    BYTE hash[SHA256_HASH_SIZE * 2 + 1];
};


__device__ bool checkDifficulty(const BYTE* hash, const BYTE* difficulty) {
    for (int i = 0; i < SHA256_HASH_SIZE * 2; i++) {
        if (hash[i] < difficulty[i])
            return true;
        else if (hash[i] > difficulty[i])
            return false;
    }
    return true;
}

__device__ int volatile found = 0; // Global device variable to indicate if a nonce has been found

__global__ void findNonce(const BYTE* baseContent, size_t baseLength, Result* result, uint32_t maxNonce) {
    if (found) return;  // Check if a valid nonce has already been found
    uint32_t idx = blockIdx.x * blockDim.x + threadIdx.x + 1;
    //printf("Testing with idx = %d\n", idx);

    BYTE buffer[BLOCK_SIZE];
    BYTE hash[SHA256_HASH_SIZE * 2 + 1];

    // Prepare the buffer with nonce
    memcpy(buffer, baseContent, baseLength);

    // Append the nonce to the end of the buffer
    char nonceStr[20];  // Ensure this is large enough to hold any 32-bit number
    int nonceLength = intToString(idx, nonceStr);
    memcpy(buffer + baseLength, nonceStr, nonceLength);

    // Calculate the total length of the buffer including the nonce
    size_t totalLength = baseLength + d_strlen((char*)buffer + baseLength);
    
    // Compute hash (single time hashing, n = 1)
    apply_sha256(buffer, totalLength, hash, 1);

    if (checkDifficulty(hash, d_difficulty_5_zeros)) {
        uint32_t old_nonce = atomicMin(&result->nonce, idx);
        if (result->nonce == idx) {
            memcpy(result->hash, hash, SHA256_HASH_SIZE * 2 + 1);
            atomicExch((int *)&found, 1);  // Set found to 1 to signal other threads
        }
    }
}


int main(int argc, char **argv) {
	BYTE hashed_tx1[SHA256_HASH_SIZE], hashed_tx2[SHA256_HASH_SIZE], hashed_tx3[SHA256_HASH_SIZE], hashed_tx4[SHA256_HASH_SIZE],
			tx12[SHA256_HASH_SIZE * 2], tx34[SHA256_HASH_SIZE * 2], hashed_tx12[SHA256_HASH_SIZE], hashed_tx34[SHA256_HASH_SIZE],
			tx1234[SHA256_HASH_SIZE * 2], top_hash[SHA256_HASH_SIZE], block_content[BLOCK_SIZE];
	BYTE block_hash[SHA256_HASH_SIZE] = "0000000000000000000000000000000000000000000000000000000000000000"; // TODO: Update
	uint64_t nonce = 0; // TODO: Update
	size_t current_length;

	// Top hash
	apply_sha256(tx1, strlen((const char*)tx1), hashed_tx1, 1);
	apply_sha256(tx2, strlen((const char*)tx2), hashed_tx2, 1);
	apply_sha256(tx3, strlen((const char*)tx3), hashed_tx3, 1);
	apply_sha256(tx4, strlen((const char*)tx4), hashed_tx4, 1);
	strcpy((char *)tx12, (const char *)hashed_tx1);
	strcat((char *)tx12, (const char *)hashed_tx2);
	apply_sha256(tx12, strlen((const char*)tx12), hashed_tx12, 1);
	strcpy((char *)tx34, (const char *)hashed_tx3);
	strcat((char *)tx34, (const char *)hashed_tx4);
	apply_sha256(tx34, strlen((const char*)tx34), hashed_tx34, 1);
	strcpy((char *)tx1234, (const char *)hashed_tx12);
	strcat((char *)tx1234, (const char *)hashed_tx34);
	apply_sha256(tx1234, strlen((const char*)tx34), top_hash, 1);

	// prev_block_hash + top_hash
	strcpy((char*)block_content, (const char*)prev_block_hash);
	strcat((char*)block_content, (const char*)top_hash);
	current_length = strlen((char*) block_content);


    Result h_result;
    Result *d_result;
    cudaMalloc(&d_result, sizeof(Result));
    Result initial = {UINT32_MAX, {0}};    
    cudaMemcpy(d_result, &initial, sizeof(Result), cudaMemcpyHostToDevice);

    BYTE* d_block_content;
    cudaMalloc((void**)&d_block_content, current_length * sizeof(BYTE));  // Allocate device memory for block_content

    // Copy data from host to device
    cudaMemcpy(d_block_content, block_content, current_length * sizeof(BYTE), cudaMemcpyHostToDevice);

    dim3 blockDim(256);
    dim3 gridDim((MAX_NONCE + blockDim.x - 1) / blockDim.x);

    cudaEvent_t start, stop;
    startTiming(&start, &stop);

    findNonce<<<gridDim, blockDim>>>(d_block_content, current_length, d_result, MAX_NONCE); // Block content is precedent hash
    cudaDeviceSynchronize();  // Ensure the kernel completes and data is ready, ensure all threads have completed their execution

    // Report timing and results
    float seconds = stopTiming(&start, &stop);

    // Copy the results back
    cudaMemcpy(&h_result, d_result, sizeof(Result), cudaMemcpyDeviceToHost);

    // Check the results
    if (h_result.nonce != UINT32_MAX) {
       printf("Nonce: %u, Hash: %s\n", h_result.nonce, h_result.hash);
    } else {
        printf("No valid nonce found.\n");
    }


    // Print results to file
    printResult(h_result.hash, h_result.nonce, seconds);
    cudaFree(d_result);
    cudaFree(d_block_content);


	return 0;
}
