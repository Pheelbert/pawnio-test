#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#pragma comment(lib, "bcrypt.lib")

#ifndef NT_SUCCESS
#define NT_SUCCESS(Status) (((NTSTATUS)(Status)) >= 0)
#endif

static void print_hex(const uint8_t* data, size_t len) {
    for (size_t i = 0; i < len; i++)
        printf("%02x", data[i]);
}

static NTSTATUS calculate_sha256(const void* data, size_t size, uint8_t sha256[32]) {
    BCRYPT_ALG_HANDLE alg = NULL;
    NTSTATUS status = BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, NULL, 0);
    if (!NT_SUCCESS(status)) return status;

    ULONG obj_len = 0, rlen = 0;
    status = BCryptGetProperty(alg, BCRYPT_OBJECT_LENGTH, (PUCHAR)&obj_len, sizeof(obj_len), &rlen, 0);
    if (!NT_SUCCESS(status) || rlen != sizeof(obj_len)) {
        BCryptCloseAlgorithmProvider(alg, 0);
        return status ? status : (NTSTATUS)0xC0000001;
    }

    uint8_t* hash_obj = (uint8_t*)malloc(obj_len);
    BCRYPT_HASH_HANDLE hash = NULL;
    status = BCryptCreateHash(alg, &hash, hash_obj, obj_len, NULL, 0, 0);
    if (NT_SUCCESS(status)) {
        status = BCryptHashData(hash, (PUCHAR)data, (ULONG)size, 0);
        if (NT_SUCCESS(status))
            status = BCryptFinishHash(hash, sha256, 32, 0);
        BCryptDestroyHash(hash);
    }
    free(hash_obj);
    BCryptCloseAlgorithmProvider(alg, 0);
    return status;
}

int main(int argc, char* argv[]) {
    printf("=== PawnIO Module Signer ===\n\n");

    if (argc < 3) {
        printf("Usage: %s <input.amx> <output.bin> [pubkey_out.bin]\n\n", argv[0]);
        printf("Generates an RSA-4096 keypair, signs the module, and writes\n");
        printf("the public key blob to pubkey_out.bin (default: tools/test_pubkey.bin).\n");
        printf("Also prints the public key as a C array for verify_module.cpp.\n");
        return 1;
    }

    const char* input_path = argv[1];
    const char* output_path = argv[2];
    const char* pubkey_path = argc >= 4 ? argv[3] : "tools\\test_pubkey.bin";

    // Read payload
    HANDLE hFile = CreateFileA(input_path, GENERIC_READ, FILE_SHARE_READ, NULL,
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        printf("[FAIL] Cannot open input: %s (error %lu)\n", input_path, GetLastError());
        return 1;
    }
    DWORD payload_len = GetFileSize(hFile, NULL);
    uint8_t* payload = (uint8_t*)malloc(payload_len);
    DWORD bytes_read = 0;
    ReadFile(hFile, payload, payload_len, &bytes_read, NULL);
    CloseHandle(hFile);
    printf("[INFO] Payload: %lu bytes from %s\n", payload_len, input_path);

    // SHA-256 the payload
    uint8_t sha256[32];
    NTSTATUS status = calculate_sha256(payload, payload_len, sha256);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] SHA-256 failed: 0x%08X\n", (unsigned)status);
        free(payload);
        return 1;
    }
    printf("[INFO] SHA-256: ");
    print_hex(sha256, 32);
    printf("\n");

    // Generate RSA-4096 keypair
    printf("[INFO] Generating RSA-4096 keypair...\n");
    BCRYPT_ALG_HANDLE rsa_alg = NULL;
    status = BCryptOpenAlgorithmProvider(&rsa_alg, BCRYPT_RSA_ALGORITHM, NULL, 0);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] BCryptOpenAlgorithmProvider(RSA): 0x%08X\n", (unsigned)status);
        free(payload);
        return 1;
    }

    BCRYPT_KEY_HANDLE key = NULL;
    status = BCryptGenerateKeyPair(rsa_alg, &key, 4096, 0);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] BCryptGenerateKeyPair: 0x%08X\n", (unsigned)status);
        BCryptCloseAlgorithmProvider(rsa_alg, 0);
        free(payload);
        return 1;
    }

    status = BCryptFinalizeKeyPair(key, 0);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] BCryptFinalizeKeyPair: 0x%08X\n", (unsigned)status);
        BCryptDestroyKey(key);
        BCryptCloseAlgorithmProvider(rsa_alg, 0);
        free(payload);
        return 1;
    }
    printf("[INFO] Keypair generated\n");

    // Sign: get signature length
    BCRYPT_PKCS1_PADDING_INFO padding;
    padding.pszAlgId = BCRYPT_SHA256_ALGORITHM;

    ULONG sig_len = 0;
    status = BCryptSignHash(key, &padding, sha256, 32, NULL, 0, &sig_len, BCRYPT_PAD_PKCS1);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] BCryptSignHash (get length): 0x%08X\n", (unsigned)status);
        BCryptDestroyKey(key);
        BCryptCloseAlgorithmProvider(rsa_alg, 0);
        free(payload);
        return 1;
    }

    uint8_t* sig = (uint8_t*)malloc(sig_len);
    status = BCryptSignHash(key, &padding, sha256, 32, sig, sig_len, &sig_len, BCRYPT_PAD_PKCS1);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] BCryptSignHash: 0x%08X\n", (unsigned)status);
        free(sig);
        BCryptDestroyKey(key);
        BCryptCloseAlgorithmProvider(rsa_alg, 0);
        free(payload);
        return 1;
    }
    printf("[INFO] Signature: %lu bytes\n", sig_len);
    printf("[INFO] Sig prefix: ");
    print_hex(sig, sig_len < 32 ? sig_len : 32);
    printf("...\n");

    // Export public key blob
    ULONG pubkey_len = 0;
    status = BCryptExportKey(key, NULL, BCRYPT_RSAPUBLIC_BLOB, NULL, 0, &pubkey_len, 0);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] BCryptExportKey (get length): 0x%08X\n", (unsigned)status);
        free(sig);
        BCryptDestroyKey(key);
        BCryptCloseAlgorithmProvider(rsa_alg, 0);
        free(payload);
        return 1;
    }

    uint8_t* pubkey = (uint8_t*)malloc(pubkey_len);
    status = BCryptExportKey(key, NULL, BCRYPT_RSAPUBLIC_BLOB, pubkey, pubkey_len, &pubkey_len, 0);
    if (!NT_SUCCESS(status)) {
        printf("[FAIL] BCryptExportKey: 0x%08X\n", (unsigned)status);
        free(pubkey);
        free(sig);
        BCryptDestroyKey(key);
        BCryptCloseAlgorithmProvider(rsa_alg, 0);
        free(payload);
        return 1;
    }
    printf("[INFO] Public key blob: %lu bytes\n", pubkey_len);

    // Write pubkey blob to file
    hFile = CreateFileA(pubkey_path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile != INVALID_HANDLE_VALUE) {
        DWORD written = 0;
        WriteFile(hFile, pubkey, pubkey_len, &written, NULL);
        CloseHandle(hFile);
        printf("[INFO] Public key saved to: %s\n", pubkey_path);
    } else {
        printf("[WARN] Could not write pubkey file: %s (error %lu)\n", pubkey_path, GetLastError());
    }

    // Print pubkey as C array
    printf("\n[INFO] Public key C array (paste into verify_module.cpp):\n\n");
    printf("static const uint8_t k_test_pubkey[] = {");
    for (ULONG i = 0; i < pubkey_len; i++) {
        if (i % 12 == 0) printf("\n    ");
        printf("0x%02X", pubkey[i]);
        if (i + 1 < pubkey_len) printf(", ");
    }
    printf("\n};\n\n");

    // Write the signed module: [sig_len:4][sig:sig_len][payload]
    hFile = CreateFileA(output_path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        printf("[FAIL] Cannot create output: %s (error %lu)\n", output_path, GetLastError());
        free(pubkey);
        free(sig);
        BCryptDestroyKey(key);
        BCryptCloseAlgorithmProvider(rsa_alg, 0);
        free(payload);
        return 1;
    }

    DWORD written = 0;
    ULONG sig_len_le = sig_len;
    WriteFile(hFile, &sig_len_le, 4, &written, NULL);
    WriteFile(hFile, sig, sig_len, &written, NULL);
    WriteFile(hFile, payload, payload_len, &written, NULL);
    CloseHandle(hFile);

    DWORD total = 4 + sig_len + payload_len;
    printf("[OK] Wrote %s (%lu bytes)\n", output_path, total);
    printf("     sig_len=%lu  sig=%lu bytes  payload=%lu bytes\n", sig_len, sig_len, payload_len);

    free(pubkey);
    free(sig);
    BCryptDestroyKey(key);
    BCryptCloseAlgorithmProvider(rsa_alg, 0);
    free(payload);
    return 0;
}
