#include <stdio.h>
#include <stdint.h>
#include "../include/utils.cuh"
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>

#define NUM_THREADS 512
#define NUM_BLOCKS 65000
#define TOTAL_THREADS NUM_THREADS * NUM_BLOCKS

__device__ bool found = false;

__global__ void findNonce(BYTE *block_content, BYTE *block_hash, uint64_t *nonce, size_t current_length, BYTE *difficulty) {
    uint64_t index = threadIdx.x + blockIdx.x * blockDim.x;

    char nonce_string[NONCE_SIZE];
    BYTE hash[SHA256_HASH_SIZE];

    uint64_t start = index * (MAX_NONCE / TOTAL_THREADS);
    uint64_t end = (index + 1) * (MAX_NONCE / TOTAL_THREADS) - 1;

    while (start < end) {
        if (found) {
            return;
        } 

        intToString(start, nonce_string);
        d_strcpy((char*) block_content + current_length, nonce_string); // Overwrite previous nonce
        apply_sha256(block_content, d_strlen((const char*)block_content), hash, 1);


        if (compare_hashes(hash, difficulty) <= 0 && !found) {
            printf("Block hash found by thread %d\n", index);
            found = true;
            *nonce = start;
            d_strcpy((char*)block_hash, (const char*)hash);
            return;
        }

        start++;
    }
}

int main(int argc, char **argv) {
    BYTE hashed_tx1[SHA256_HASH_SIZE], hashed_tx2[SHA256_HASH_SIZE], hashed_tx3[SHA256_HASH_SIZE], hashed_tx4[SHA256_HASH_SIZE],
            tx12[SHA256_HASH_SIZE * 2], tx34[SHA256_HASH_SIZE * 2], hashed_tx12[SHA256_HASH_SIZE], hashed_tx34[SHA256_HASH_SIZE],
            tx1234[SHA256_HASH_SIZE * 2], top_hash[SHA256_HASH_SIZE], block_content[BLOCK_SIZE];
    BYTE block_hash[SHA256_HASH_SIZE] = "0000000000000000000000000000000000000000000000000000000000000000";
    uint64_t nonce = 0;
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

    cudaEvent_t start, stop;
    startTiming(&start, &stop);

    BYTE *d_block_content, *d_block_hash, *d_difficulty;
    uint64_t *d_nonce;

    cudaMalloc((void**)&d_block_content, BLOCK_SIZE);
    cudaMalloc((void**)&d_block_hash, SHA256_HASH_SIZE);
    cudaMalloc((void**)&d_difficulty, SHA256_HASH_SIZE);
    cudaMalloc((void**)&d_nonce, sizeof(uint64_t));

    cudaMemcpy(d_block_hash, block_hash, SHA256_HASH_SIZE, cudaMemcpyHostToDevice);
    cudaMemcpy(d_block_content, block_content, BLOCK_SIZE, cudaMemcpyHostToDevice);
    cudaMemcpy(d_difficulty, DIFFICULTY, SHA256_HASH_SIZE, cudaMemcpyHostToDevice);
    cudaMemcpy(d_nonce, &nonce, sizeof(uint64_t), cudaMemcpyHostToDevice);

    findNonce<<<655000, NUM_THREADS>>>(d_block_content, d_block_hash, d_nonce, current_length, d_difficulty);

    cudaMemcpy(block_hash, d_block_hash, SHA256_HASH_SIZE, cudaMemcpyDeviceToHost);
    cudaMemcpy(&nonce, d_nonce, sizeof(uint64_t), cudaMemcpyDeviceToHost);

    cudaFree(d_block_content);
    cudaFree(d_block_hash);
    cudaFree(d_nonce);

    float seconds = stopTiming(&start, &stop);
    printResult(block_hash, nonce, seconds);

    return 0;
}
