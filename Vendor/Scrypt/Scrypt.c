//
//  Scrypt.c
//  Threema
//
//  Copyright © 2018 Threema GmbH. All rights reserved.
//

#include "Scrypt.h"
#include "include/scrypt.h"
#include "string.h"
#include "limits.h"

// see on https://github.com/derivepass/scrypt
int getDerivedKey(char password[], char salt[], uint8_t out[64]) {
    int err;
    scrypt_state_t state;
    
    if(!password || !salt || !out) {
        return 1;
    }

    state.n = 65536;
    state.r = 8;
    state.p = 1;
    err = scrypt_state_init(&state);
    //assert(err == 0);
    if(err != 0) {
        return err;
    }
    
    scrypt(&state,
           (const uint8_t*) password,
           strlen(password),
           (const uint8_t*) salt,
           strlen(salt),
           out,
           64);
    scrypt_state_destroy(&state);
    
    return 0;
}
