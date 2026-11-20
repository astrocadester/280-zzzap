#!/usr/bin/env bash
# 280-ZZZAP original Intel 8080 ROM build — project zmac v1.3; no Python.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
fail() { echo "ERROR: $*" >&2; exit 1; }

for cmd in dd sha1sum zip stat; do command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"; done
if [[ -n "${ZMAC:-}" ]]; then
    zmac_bin="$ZMAC"
elif [[ -x tools/zmac ]]; then
    zmac_bin=tools/zmac
else
    fail 'Project assembler tools/zmac is missing (or set ZMAC explicitly)'
fi
[[ -x "$zmac_bin" ]] || command -v "$zmac_bin" >/dev/null 2>&1 || fail "Assembler unavailable: $zmac_bin"
[[ -f src/280zzzap.asm ]] || fail 'Missing RE source: src/280zzzap.asm'
[[ -f roms/original/280zzzap.zip ]] || fail 'Missing original ROM archive: roms/original/280zzzap.zip'

names=(zzzaph zzzapg zzzapf zzzape zzzapd zzzapc)
sha1=(
    b9cf16eb037ada73631ed24297e9e3b3bf6ab3cd
    b2e2497e421e79a411d07ebf2eed2bb8dc227003
    206bf2575696c4b14437f3db37a215ba33211943
    ae5cf4481ee4b78ca0d2f4d560d295e922aa04a7
    972475f80253bb0d24773a10aec26a12f28e7c23
    ffa6bb84ef1f7c2d72fd26c24bd33aa014aeab7e
)

echo '280-ZZZAP parent-set native ROM build'
mkdir -p build roms
rm -f build/280zzzap.bin build/280zzzap.lst roms/280zzzap.zip
for name in "${names[@]}"; do rm -f "build/$name"; done

echo '[1/3] Assemble src/280zzzap.asm with zmac v1.3'
"$zmac_bin" -c -o build/280zzzap.bin -x build/280zzzap.lst src/280zzzap.asm || fail 'Assembly failed'
[[ -s build/280zzzap.bin ]] || fail 'Assembler produced no ROM image'
size=$(stat -c %s build/280zzzap.bin)
(( size == 6144 )) || fail "Expected 6144-byte binary; got $size"

echo '[2/3] Split and verify six 1 KB devices'
for i in 0 1 2 3 4 5; do
    name=${names[i]}
    dd if=build/280zzzap.bin of="build/$name" bs=1024 skip="$i" count=1 status=none
    size=$(stat -c %s "build/$name")
    (( size == 1024 )) || fail "$name size $size, expected 1024"
    actual=$(sha1sum "build/$name"); actual=${actual%% *}
    [[ "$actual" == "${sha1[i]}" ]] || fail "$name SHA-1 mismatch: expected ${sha1[i]}, got $actual"
    echo "  PASS $name  $actual"
done
echo '[3/3] Package original MAME device filenames'
(cd build && zip -q -X ../roms/280zzzap.zip "${names[@]}") || fail 'ZIP packaging failed'
[[ -s roms/280zzzap.zip ]] || fail 'ZIP output missing'
echo 'PASS: roms/280zzzap.zip'
