; "Elite" C64 disassembly / "Elite DX", cc0 2018, see LICENSE.txt
; "Elite" is copyright / trademark David Braben & Ian Bell, All Rights Reserved
; <github.com/Kroc/EliteDX>
;===============================================================================

.include        "loader/gma4_data1.s"
.incbin         "loader/gma4_junk1.bin"
.incbin         "loader/gma4_code.bin"
.include        "loader/gma4_data2.s"
.incbin         "loader/gma4_junk2.bin"