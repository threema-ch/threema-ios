# ThreemaBlake2b

Threema specific Swift bindings for the C reference implementation of BLAKE2b

## Update `CBlake2`

1. Get reference implementation from https://github.com/BLAKE2/BLAKE2/tree/master/ref
2. Delete `makefile`, `genkat-json.c` & `genkat-c.c`
3. Move `*.h` files (`blake2.h` & `blake2-impl.h`) into `include` subfolder
4. Replace everything in `Sources/CBlake2/` with this updated reference implementation
