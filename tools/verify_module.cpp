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

static const uint8_t k_pubkey_namazso_2023[] = {
    0x52, 0x53, 0x41, 0x31, 0x00, 0x10, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
    0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x01, 0xB5, 0x45, 0xB8, 0x15, 0xF0, 0x2A, 0xEB, 0xCA, 0xC9,
    0x35, 0x8F, 0x54, 0x15, 0x83, 0x12, 0x2C, 0xC3, 0xF3, 0x5E, 0x1E, 0xE7,
    0xFB, 0xD3, 0xE1, 0x68, 0x73, 0x3B, 0x36, 0xC0, 0x5C, 0x6F, 0xD3, 0xBA,
    0xF4, 0xD0, 0xA9, 0x9B, 0x6E, 0x9C, 0x66, 0x43, 0x2F, 0xC9, 0xB2, 0x82,
    0xDF, 0x24, 0x6D, 0x8F, 0x5F, 0x45, 0xAF, 0x02, 0xDD, 0x6A, 0xEF, 0x04,
    0x01, 0x74, 0x69, 0xC3, 0x20, 0x70, 0xDB, 0x3F, 0x05, 0x97, 0x9E, 0xE6,
    0x01, 0x6B, 0x9E, 0x28, 0x53, 0x03, 0x59, 0x02, 0x98, 0x4C, 0x41, 0xAB,
    0xB2, 0x56, 0x5F, 0xD6, 0x24, 0x98, 0xD1, 0xB3, 0xF9, 0xF8, 0x46, 0xC7,
    0x21, 0x4B, 0xDF, 0xFD, 0xF2, 0x88, 0x2A, 0xCE, 0xDC, 0x75, 0x36, 0x40,
    0xC2, 0x5E, 0x0B, 0x26, 0x17, 0x7A, 0x3D, 0xD6, 0x34, 0xD7, 0x47, 0xD6,
    0x61, 0xE1, 0x33, 0xD7, 0x7A, 0x00, 0x7E, 0x9F, 0xEB, 0x92, 0x33, 0x52,
    0x65, 0x8E, 0xF8, 0x7C, 0x49, 0xD4, 0x22, 0xB8, 0x22, 0xBD, 0x59, 0x56,
    0xBC, 0xD5, 0x1B, 0x64, 0x4C, 0x91, 0x50, 0xAB, 0x1F, 0x67, 0x9F, 0x84,
    0xDD, 0x8B, 0x4F, 0xFC, 0x28, 0x26, 0x52, 0x36, 0x49, 0x67, 0x0D, 0x6C,
    0xA4, 0xA1, 0xAA, 0xEC, 0x2B, 0xB0, 0x05, 0x09, 0x08, 0x20, 0x38, 0x82,
    0xAE, 0x47, 0xB9, 0x3C, 0xAE, 0x50, 0xBF, 0x93, 0x69, 0x94, 0xB5, 0x98,
    0x7C, 0xA8, 0x2E, 0xA9, 0x8E, 0x7B, 0xC2, 0xB2, 0x12, 0xB9, 0xB1, 0x62,
    0x46, 0x3C, 0xED, 0x24, 0x9C, 0x89, 0xE0, 0xB8, 0x46, 0x26, 0x1A, 0x5A,
    0x08, 0xD6, 0xF0, 0x2A, 0xA3, 0x28, 0xB6, 0x73, 0x60, 0xAE, 0xC3, 0x2D,
    0x4C, 0x5A, 0x24, 0xF1, 0x58, 0x4C, 0x51, 0xD2, 0x66, 0xE9, 0xD9, 0x61,
    0x98, 0x4D, 0xDE, 0x94, 0xD8, 0x44, 0x1F, 0x62, 0xF6, 0x4E, 0xF9, 0x73,
    0x44, 0xA4, 0x7A, 0x2C, 0x2D, 0xC1, 0xDB, 0x4F, 0x58, 0xD6, 0x70, 0xB2,
    0x6E, 0xE8, 0xD9, 0x50, 0x01, 0x35, 0x4F, 0x39, 0x49, 0x2E, 0x09, 0x76,
    0x47, 0x9C, 0x3C, 0x7E, 0x72, 0x33, 0xCA, 0x13, 0xD7, 0x29, 0x82, 0xFB,
    0x14, 0xAD, 0x4E, 0xC3, 0xA6, 0xC6, 0x4C, 0x18, 0x84, 0xB5, 0x83, 0x7A,
    0xF0, 0x99, 0xBA, 0x1D, 0x56, 0xD2, 0xA2, 0xDF, 0x14, 0x34, 0x01, 0x6F,
    0x83, 0x8D, 0xB8, 0xA0, 0x16, 0x2C, 0x36, 0x90, 0x0F, 0x96, 0x2D, 0x3B,
    0x80, 0x58, 0x5C, 0xE7, 0x9D, 0x0D, 0x73, 0x38, 0xCA, 0xEE, 0x43, 0xF7,
    0xC0, 0x37, 0xA4, 0xEA, 0xDD, 0x76, 0xCC, 0xA2, 0xF3, 0x54, 0xC8, 0x45,
    0xC9, 0xBE, 0x3F, 0xCE, 0xAA, 0x98, 0x2F, 0x4C, 0x97, 0x87, 0x56, 0x00,
    0x81, 0x6A, 0x7A, 0x41, 0x52, 0xF7, 0xF9, 0x0D, 0xEE, 0x5D, 0xB6, 0x05,
    0x1F, 0x40, 0x9F, 0xDE, 0x75, 0x97, 0xD5, 0x8F, 0x28, 0x04, 0xDA, 0x57,
    0xA2, 0x76, 0x52, 0x49, 0x35, 0xAC, 0x54, 0xF3, 0x09, 0xA6, 0x68, 0xEC,
    0x84, 0xB8, 0x87, 0xD9, 0xBE, 0x26, 0xED, 0xFD, 0x75, 0x7D, 0x2A, 0x1B,
    0x55, 0x18, 0x31, 0xA7, 0xA0, 0x44, 0xC5, 0x4A, 0x05, 0xD2, 0x55, 0x44,
    0x70, 0x1D, 0x35, 0xE4, 0x61, 0x03, 0x5D, 0x82, 0x3C, 0x48, 0x40, 0x5F,
    0x58, 0x64, 0x4E, 0xFF, 0xA6, 0xA1, 0x24, 0x7A, 0xAC, 0xF0, 0xF8, 0x3F,
    0x9E, 0x9B, 0xE0, 0x53, 0x04, 0x55, 0xB1, 0xED, 0xDC, 0xC0, 0xC9, 0x9E,
    0x5E, 0x31, 0x46, 0x09, 0x83, 0x51, 0x41, 0xBD, 0x41, 0x73, 0xC0, 0xD8,
    0x36, 0x23, 0xAE, 0x0B, 0xDF, 0x89, 0x67, 0x2A, 0xC7, 0x56, 0x36, 0xA8,
    0xE2, 0x76, 0xB8, 0xCB, 0x75, 0xA1, 0xF0, 0x7C, 0xAC, 0x4D, 0xCD, 0x56,
    0xBB, 0x6A, 0x03, 0xCA, 0x7A, 0x89, 0xD2, 0x06, 0xE9, 0x02, 0x48, 0x17,
    0x2F, 0xCF, 0xBC, 0xC1, 0xB6, 0xF7, 0xBF, 0x8A, 0xC1, 0xA7, 0x9B,
};

static void print_hex(const uint8_t* data, size_t len) {
    for (size_t i = 0; i < len; i++)
        printf("%02x", data[i]);
}

static NTSTATUS calculate_sha256(const void* data, size_t size, uint8_t sha256[32]) {
    BCRYPT_ALG_HANDLE alg_handle = NULL;
    NTSTATUS status = BCryptOpenAlgorithmProvider(&alg_handle, BCRYPT_SHA256_ALGORITHM, NULL, 0);
    if (!NT_SUCCESS(status)) {
        printf("  [FAIL] BCryptOpenAlgorithmProvider: 0x%08X\n", (unsigned)status);
        return status;
    }

    ULONG obj_len = 0, rlen = 0;
    status = BCryptGetProperty(alg_handle, BCRYPT_OBJECT_LENGTH, (PUCHAR)&obj_len, sizeof(obj_len), &rlen, 0);
    if (!NT_SUCCESS(status) || rlen != sizeof(obj_len)) {
        printf("  [FAIL] BCryptGetProperty(OBJECT_LENGTH): 0x%08X\n", (unsigned)status);
        BCryptCloseAlgorithmProvider(alg_handle, 0);
        return status ? status : (NTSTATUS)0xC0000001;
    }

    uint8_t* hash_obj = (uint8_t*)malloc(obj_len);
    if (!hash_obj) {
        BCryptCloseAlgorithmProvider(alg_handle, 0);
        return (NTSTATUS)0xC0000017;
    }

    BCRYPT_HASH_HANDLE hash_handle = NULL;
    status = BCryptCreateHash(alg_handle, &hash_handle, hash_obj, obj_len, NULL, 0, 0);
    if (!NT_SUCCESS(status)) {
        printf("  [FAIL] BCryptCreateHash: 0x%08X\n", (unsigned)status);
        free(hash_obj);
        BCryptCloseAlgorithmProvider(alg_handle, 0);
        return status;
    }

    status = BCryptHashData(hash_handle, (PUCHAR)data, (ULONG)size, 0);
    if (!NT_SUCCESS(status)) {
        printf("  [FAIL] BCryptHashData: 0x%08X\n", (unsigned)status);
        BCryptDestroyHash(hash_handle);
        free(hash_obj);
        BCryptCloseAlgorithmProvider(alg_handle, 0);
        return status;
    }

    status = BCryptFinishHash(hash_handle, sha256, 32, 0);
    if (!NT_SUCCESS(status))
        printf("  [FAIL] BCryptFinishHash: 0x%08X\n", (unsigned)status);

    BCryptDestroyHash(hash_handle);
    free(hash_obj);
    BCryptCloseAlgorithmProvider(alg_handle, 0);
    return status;
}

static NTSTATUS verify_sig(const uint8_t sha256[32], const uint8_t* sig, size_t sig_len,
                           const uint8_t* pubkey, size_t pubkey_len) {
    if (pubkey_len < sizeof(BCRYPT_KEY_BLOB)) {
        printf("  [FAIL] pubkey too short (%zu < %zu)\n", pubkey_len, sizeof(BCRYPT_KEY_BLOB));
        return (NTSTATUS)0xC000000D;
    }

    BCRYPT_KEY_BLOB key_blob;
    memcpy(&key_blob, pubkey, sizeof(key_blob));

    LPCWSTR alg_id = NULL;
    LPCWSTR blob_type = NULL;

    switch (key_blob.Magic) {
    case BCRYPT_RSAPUBLIC_MAGIC:
        printf("  [INFO] Key type: RSA Public (magic=0x%08X)\n", key_blob.Magic);
        alg_id = BCRYPT_RSA_ALGORITHM;
        blob_type = BCRYPT_RSAPUBLIC_BLOB;
        break;
    default:
        printf("  [FAIL] Unknown key magic: 0x%08X\n", key_blob.Magic);
        return (NTSTATUS)0xC000000D;
    }

    BCRYPT_ALG_HANDLE alg_handle = NULL;
    NTSTATUS status = BCryptOpenAlgorithmProvider(&alg_handle, alg_id, NULL, 0);
    if (!NT_SUCCESS(status)) {
        printf("  [FAIL] BCryptOpenAlgorithmProvider(RSA): 0x%08X\n", (unsigned)status);
        return status;
    }

    BCRYPT_KEY_HANDLE pubkey_handle = NULL;
    status = BCryptImportKeyPair(alg_handle, NULL, blob_type, &pubkey_handle,
                                 (PUCHAR)pubkey, (ULONG)pubkey_len, 0);
    if (!NT_SUCCESS(status)) {
        printf("  [FAIL] BCryptImportKeyPair: 0x%08X\n", (unsigned)status);
        BCryptCloseAlgorithmProvider(alg_handle, 0);
        return status;
    }

    printf("  [INFO] Key imported, verifying PKCS1-SHA256 signature...\n");

    BCRYPT_PKCS1_PADDING_INFO padding;
    padding.pszAlgId = BCRYPT_SHA256_ALGORITHM;

    status = BCryptVerifySignature(pubkey_handle, &padding,
                                   (PUCHAR)sha256, 32,
                                   (PUCHAR)sig, (ULONG)sig_len,
                                   BCRYPT_PAD_PKCS1);

    BCryptDestroyKey(pubkey_handle);
    BCryptCloseAlgorithmProvider(alg_handle, 0);
    return status;
}

struct key_entry {
    const char* name;
    const uint8_t* data;
    size_t len;
    int allocated;
};

static uint8_t* load_key_file(const char* path, size_t* out_len) {
    HANDLE hf = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL,
                            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hf == INVALID_HANDLE_VALUE) return NULL;
    DWORD sz = GetFileSize(hf, NULL);
    uint8_t* buf = (uint8_t*)malloc(sz);
    DWORD rd = 0;
    if (!buf || !ReadFile(hf, buf, sz, &rd, NULL) || rd != sz) {
        free(buf);
        CloseHandle(hf);
        return NULL;
    }
    CloseHandle(hf);
    *out_len = sz;
    return buf;
}

int main(int argc, char* argv[]) {
    printf("=== PawnIO Module Signature Verifier ===\n\n");

    if (argc < 2) {
        printf("Usage: %s [--key <pubkey.bin>] <module.bin> [module2.bin ...]\n\n", argv[0]);
        printf("Without --key, verifies against the built-in namazso_2023 key.\n");
        printf("With --key, verifies against BOTH the built-in key and the provided key.\n");
        return 1;
    }

    key_entry keys[2];
    int key_count = 0;

    keys[key_count].name = "namazso_2023";
    keys[key_count].data = k_pubkey_namazso_2023;
    keys[key_count].len = sizeof(k_pubkey_namazso_2023);
    keys[key_count].allocated = 0;
    key_count++;

    int first_file = 1;
    if (argc >= 3 && strcmp(argv[1], "--key") == 0) {
        size_t klen = 0;
        uint8_t* kdata = load_key_file(argv[2], &klen);
        if (!kdata) {
            printf("[FAIL] Cannot load key file: %s\n", argv[2]);
            return 1;
        }
        keys[key_count].name = argv[2];
        keys[key_count].data = kdata;
        keys[key_count].len = klen;
        keys[key_count].allocated = 1;
        key_count++;
        first_file = 3;
        printf("[INFO] Loaded extra key: %s (%zu bytes)\n\n", argv[2], klen);
    }

    if (first_file >= argc) {
        printf("No module files specified.\n");
        return 1;
    }

    int total_pass = 0, total_fail = 0;

    for (int fi = first_file; fi < argc; fi++) {
        const char* path = argv[fi];
        printf("--- Verifying: %s ---\n", path);

        HANDLE hFile = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL,
                                   OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
        if (hFile == INVALID_HANDLE_VALUE) {
            printf("  [FAIL] Cannot open file (error %lu)\n\n", GetLastError());
            total_fail++;
            continue;
        }

        DWORD file_size = GetFileSize(hFile, NULL);
        printf("  [INFO] File size: %lu bytes\n", file_size);

        if (file_size < 4) {
            printf("  [FAIL] File too small (need at least 4 bytes for sig_len)\n\n");
            CloseHandle(hFile);
            total_fail++;
            continue;
        }

        uint8_t* buffer = (uint8_t*)malloc(file_size);
        if (!buffer) {
            printf("  [FAIL] malloc failed\n\n");
            CloseHandle(hFile);
            total_fail++;
            continue;
        }

        DWORD bytes_read = 0;
        if (!ReadFile(hFile, buffer, file_size, &bytes_read, NULL) || bytes_read != file_size) {
            printf("  [FAIL] ReadFile failed (error %lu)\n\n", GetLastError());
            free(buffer);
            CloseHandle(hFile);
            total_fail++;
            continue;
        }
        CloseHandle(hFile);

        ULONG sig_len = *(ULONG*)buffer;
        printf("  [INFO] sig_len field: %lu bytes\n", sig_len);

        if (sig_len > (file_size - 4)) {
            printf("  [FAIL] sig_len (%lu) exceeds available data (%lu)\n\n", sig_len, file_size - 4);
            free(buffer);
            total_fail++;
            continue;
        }

        const uint8_t* sig = buffer + 4;
        const uint8_t* payload = buffer + 4 + sig_len;
        size_t payload_len = file_size - 4 - sig_len;

        printf("  [INFO] Signature: %lu bytes at offset 4\n", sig_len);
        printf("  [INFO] Payload:   %zu bytes at offset %lu\n", payload_len, 4 + sig_len);

        if (sig_len > 0) {
            printf("  [INFO] Sig prefix: ");
            size_t preview = sig_len < 32 ? sig_len : 32;
            print_hex(sig, preview);
            if (sig_len > 32) printf("...");
            printf("\n");
        } else {
            printf("  [WARN] Signature is empty (unsigned module)\n");
        }

        printf("  [INFO] Computing SHA-256 of payload (%zu bytes)...\n", payload_len);
        uint8_t sha256[32];
        NTSTATUS status = calculate_sha256(payload, payload_len, sha256);
        if (!NT_SUCCESS(status)) {
            printf("  [FAIL] SHA-256 computation failed: 0x%08X\n\n", (unsigned)status);
            free(buffer);
            total_fail++;
            continue;
        }
        printf("  [INFO] SHA-256: ");
        print_hex(sha256, 32);
        printf("\n");

        int matched = 0;
        for (int ki = 0; ki < key_count; ki++) {
            printf("  [INFO] Verifying against key \"%s\" (%zu bytes)...\n",
                   keys[ki].name, keys[ki].len);
            status = verify_sig(sha256, sig, sig_len, keys[ki].data, keys[ki].len);

            if (NT_SUCCESS(status)) {
                printf("  [MATCH] Signature VALID with key \"%s\" (status=0x%08X)\n",
                       keys[ki].name, (unsigned)status);
                matched = 1;
                break;
            } else {
                printf("  [MISMATCH] No match with key \"%s\" (status=0x%08X)\n",
                       keys[ki].name, (unsigned)status);
            }
        }

        if (matched)
            total_pass++;
        else
            total_fail++;

        printf("\n");
        free(buffer);
    }

    for (int ki = 0; ki < key_count; ki++)
        if (keys[ki].allocated) free((void*)keys[ki].data);

    printf("=== Summary: %d passed, %d failed ===\n", total_pass, total_fail);
    return total_fail > 0 ? 1 : 0;
}
