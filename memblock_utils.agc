// MemblockUtils.agc
// Complete Util Lib for Memblock (Tier 1)
// Includes: Resize / EnsureCapacity, Add/Insert/Remove/Replace for pimitive data types,
// Safe getters, Find, Slice, Append, MoveRange, SwapRange
// UTF-8

// Constants (size in bytes)
#constant SIZE_BYTE 1
#constant SIZE_SHORT 2
#constant SIZE_INT 4
#constant SIZE_FLOAT 4

// -----------------------------
// Helpers
// -----------------------------
function EnsureMemblockCapacity(memblock as integer, minCapacity as integer)
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if oldSize >= minCapacity then exitfunction

    // Grow strategy: double or minCapacity
    local newSize as integer : newSize = oldSize * 2
    if newSize < minCapacity then newSize = minCapacity
    if newSize = 0 then newSize = minCapacity

    ResizeMemblock(memblock, newSize)
endfunction

function ResizeMemblock(memblock as integer, newSize as integer)
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if newSize = oldSize then exitfunction

    local copySize as integer
    if newSize < oldSize
        copySize = newSize
    else
        copySize = oldSize
    endif

    local temp as integer : temp = CreateMemblock(newSize)

    if copySize > 0
        CopyMemblock(memblock, temp, 0, 0, copySize)
    endif

    // Recreate memblock: delete old, create new
    DeleteMemblock(memblock)
    CreateMemblock(memblock, newSize)

    if copySize > 0
        CopyMemblock(temp, memblock, 0, 0, copySize)
    endif

    DeleteMemblock(temp)
endfunction

// Raw add/insert/remove/replace
function AddMemblockRawValue(memblock as integer, addSize as integer)
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if addSize <= 0 then exitfunction
    ResizeMemblock(memblock, oldSize + addSize)
endfunction

function InsertMemblockRawValue(memblock as integer, offset as integer, size as integer)
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if size <= 0 then exitfunction
    if offset < 0 then offset = 0
    if offset > oldSize then offset = oldSize

    local newSize as integer : newSize = oldSize + size

    // Fast path: insert at end == append
    if offset = oldSize
        ResizeMemblock(memblock, newSize)
        exitfunction
    endif

    local temp as integer : temp = CreateMemblock(newSize)

    if offset > 0
        CopyMemblock(memblock, temp, 0, 0, offset)
    endif

    local afterSize as integer : afterSize = oldSize - offset
    if afterSize > 0
        CopyMemblock(memblock, temp, offset, offset + size, afterSize)
    endif

    DeleteMemblock(memblock)
    CreateMemblock(memblock, newSize)
    if newSize > 0
        CopyMemblock(temp, memblock, 0, 0, newSize)
    endif

    DeleteMemblock(temp)
endfunction

function RemoveMemblockRawValue(memblock as integer, offset as integer, size as integer)
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if size <= 0 then exitfunction
    if offset < 0 then offset = 0
    if offset >= oldSize then exitfunction

    if offset + size > oldSize then size = oldSize - offset

    local newSize as integer : newSize = oldSize - size
    local temp as integer : temp = CreateMemblock(newSize)

    // Copy before removed
    if offset > 0
        CopyMemblock(memblock, temp, 0, 0, offset)
    endif

    // Copy after removed
    local afterSize as integer : afterSize = oldSize - (offset + size)
    if afterSize > 0
        CopyMemblock(memblock, temp, offset + size, offset, afterSize)
    endif

    DeleteMemblock(memblock)
    CreateMemblock(memblock, newSize)
    if newSize > 0
        CopyMemblock(temp, memblock, 0, 0, newSize)
    endif

    DeleteMemblock(temp)
endfunction

function ReplaceMemblockRawValue(memblock as integer, offset as integer, oldRangeSize as integer, newRangeSize as integer)
    // Replace = Remove + Insert (preserves offset semantics)
    RemoveMemblockRawValue(memblock, offset, oldRangeSize)
    InsertMemblockRawValue(memblock, offset, newRangeSize)
endfunction

// Slice: returns new memblock with copy of range
function SliceMemblock(memblock as integer, offset as integer, size as integer)
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if size <= 0 then exitfunction -1
    if offset < 0 then offset = 0
    if offset + size > oldSize then size = oldSize - offset

    local result as integer : result = CreateMemblock(size)
    if size > 0
        CopyMemblock(memblock, result, offset, 0, size)
    endif
    exitfunction result
endfunction 0

// Append entire memB to memA
function AppendMemblock(memA as integer, memB as integer)
    local sizeB as integer : sizeB = GetMemblockSize(memB)
    if sizeB <= 0 then exitfunction

    local oldASize as integer : oldASize = GetMemblockSize(memA)
    ResizeMemblock(memA, oldASize + sizeB)
    CopyMemblock(memB, memA, 0, oldASize, sizeB)
endfunction

// MoveByteRange inside same memblock (overwrites destination)
function MoveMemblockRange(memblock as integer, fromOffset as integer, toOffset as integer, size as integer)
    if size <= 0 then exitfunction
    // out of bounds checks
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if fromOffset < 0 or toOffset < 0 then exitfunction
    if fromOffset + size > oldSize or toOffset + size > oldSize then exitfunction

    // Use temp buffer
    local temp as integer : temp = CreateMemblock(size)
    CopyMemblock(memblock, temp, fromOffset, 0, size)
    CopyMemblock(temp, memblock, 0, toOffset, size)
    DeleteMemblock(temp)
endfunction

// Swap two ranges of equal size
function SwapMemblockRange(memblock as integer, a as integer, b as integer, size as integer)
    if size <= 0 then exitfunction
    local oldSize as integer : oldSize = GetMemblockSize(memblock)
    if a < 0 or b < 0 then exitfunction
    if a + size > oldSize or b + size > oldSize then exitfunction

    local temp as integer : temp = CreateMemblock(size)
    CopyMemblock(memblock, temp, a, 0, size)
    CopyMemblock(memblock, memblock, b, a, size)
    CopyMemblock(temp, memblock, 0, b, size)
    DeleteMemblock(temp)
endfunction

// Find a single byte from start offset; returns index or -1
function FindMemblockByte(memblock as integer, value as integer, startOffset as integer)
    local size as integer : size = GetMemblockSize(memblock)
    if startOffset < 0 then startOffset = 0
    for i = startOffset to size - 1
        if GetMemblockByte(memblock, i) = value then exitfunction i
    next i
    exitfunction -1
endfunction 0

// Find sequence (simple naive algorithm), returns index or -1
function FindMemblockSequence(memblock as integer, seqMem as integer, startOffset as integer)
    local size as integer : size = GetMemblockSize(memblock)
    local seqSize as integer : seqSize = GetMemblockSize(seqMem)
    if seqSize <= 0 then exitfunction -1
    if startOffset < 0 then startOffset = 0

    for i = startOffset to size - seqSize
        local match as integer : match = 1
        for j = 0 to seqSize - 1
            if GetMemblockByte(memblock, i + j) <> GetMemblockByte(seqMem, j)
                match = 0
                exit
            endif
        next j
        if match = 1 then exitfunction i
    next i
    exitfunction -1
endfunction 0

// -----------------------------
// Safe getters (bounds-checked)
// -----------------------------
function GetMemblockByteSafe(memblock as integer, offset as integer)
    if offset < 0 then exitfunction 0
    if offset + 1 > GetMemblockSize(memblock) then exitfunction 0
    exitfunction GetMemblockByte(memblock, offset)
endfunction 0

function GetMemblockByteSignedSafe(memblock as integer, offset as integer)
    if offset < 0 then exitfunction 0
    if offset + 1 > GetMemblockSize(memblock) then exitfunction 0
    exitfunction GetMemblockByteSigned(memblock, offset)
endfunction 0

function GetMemblockShortSafe(memblock as integer, offset as integer)
    if offset < 0 then exitfunction 0
    if offset + 2 > GetMemblockSize(memblock) then exitfunction 0
    exitfunction GetMemblockShort(memblock, offset)
endfunction 0

function GetMemblockIntSafe(memblock as integer, offset as integer)
    if offset < 0 then exitfunction 0
    if offset + 4 > GetMemblockSize(memblock) then exitfunction 0
    exitfunction GetMemblockInt(memblock, offset)
endfunction 0

function GetMemblockFloatSafe(memblock as integer, offset as integer)
    if offset < 0 then exitfunction 0.0
    if offset + 4 > GetMemblockSize(memblock) then exitfunction 0.0
    exitfunction GetMemblockFloat(memblock, offset)
endfunction 0

function GetMemblockStringSafe(memblock as integer, offset as integer, length as integer)
    if length <= 0 then exitfunction ""
    if offset < 0 then exitfunction ""
    if offset + length > GetMemblockSize(memblock) then exitfunction ""
    exitfunction GetMemblockString(memblock, offset, length)
endfunction ""

function GetMemblockStringSmartSafe(memblock as integer, offset as integer)
    // [int length][bytes][00] or [int length][bytes]
    local memSize as integer : memSize = GetMemblockSize(memblock)
    if offset < 0 then exitfunction ""
    if offset + 4 > memSize then exitfunction ""

    local strLen as integer : strLen = GetMemblockInt(memblock, offset)
    if strLen < 0 then exitfunction ""
    if offset + 4 + strLen > memSize then exitfunction ""

    exitfunction GetMemblockString(memblock, offset + 4, strLen)
endfunction ""

// -----------------------------
// Typed Add / Insert / Remove / Replace / Read helpers
// -----------------------------
// BYTE
function AddMemblockByte(memblock as integer, value as integer)
    local off as integer : off = GetMemblockSize(memblock)
    AddMemblockRawValue(memblock, SIZE_BYTE)
    SetMemblockByte(memblock, off, value)
endfunction

function InsertMemblockByte(memblock as integer, offset as integer, value as integer)
    InsertMemblockRawValue(memblock, offset, SIZE_BYTE)
    SetMemblockByte(memblock, offset, value)
endfunction

function RemoveMemblockByte(memblock as integer, offset as integer)
    RemoveMemblockRawValue(memblock, offset, SIZE_BYTE)
endfunction

function ReplaceMemblockByte(memblock as integer, offset as integer, value as integer)
    // overwrite existing byte
    if offset < 0 then exitfunction
    if offset + SIZE_BYTE > GetMemblockSize(memblock) then exitfunction
    SetMemblockByte(memblock, offset, value)
endfunction

// BYTE SIGNED
function AddMemblockByteSigned(memblock as integer, value as integer)
    local off as integer : off = GetMemblockSize(memblock)
    AddMemblockRawValue(memblock, SIZE_BYTE)
    SetMemblockByteSigned(memblock, off, value)
endfunction

function InsertMemblockByteSigned(memblock as integer, offset as integer, value as integer)
    InsertMemblockRawValue(memblock, offset, SIZE_BYTE)
    SetMemblockByteSigned(memblock, offset, value)
endfunction

function RemoveMemblockByteSigned(memblock as integer, offset as integer)
    RemoveMemblockRawValue(memblock, offset, SIZE_BYTE)
endfunction

function ReplaceMemblockByteSigned(memblock as integer, offset as integer, value as integer)
    if offset < 0 then exitfunction
    if offset + SIZE_BYTE > GetMemblockSize(memblock) then exitfunction
    SetMemblockByteSigned(memblock, offset, value)
endfunction

// SHORT
function AddMemblockShort(memblock as integer, value as integer)
    local off as integer : off = GetMemblockSize(memblock)
    AddMemblockRawValue(memblock, SIZE_SHORT)
    SetMemblockShort(memblock, off, value)
endfunction

function InsertMemblockShort(memblock as integer, offset as integer, value as integer)
    InsertMemblockRawValue(memblock, offset, SIZE_SHORT)
    SetMemblockShort(memblock, offset, value)
endfunction

function RemoveMemblockShort(memblock as integer, offset as integer)
    RemoveMemblockRawValue(memblock, offset, SIZE_SHORT)
endfunction

function ReplaceMemblockShort(memblock as integer, offset as integer, value as integer)
    if offset < 0 then exitfunction
    if offset + SIZE_SHORT > GetMemblockSize(memblock) then exitfunction
    SetMemblockShort(memblock, offset, value)
endfunction

// INT
function AddMemblockInt(memblock as integer, value as integer)
    local off as integer : off = GetMemblockSize(memblock)
    AddMemblockRawValue(memblock, SIZE_INT)
    SetMemblockInt(memblock, off, value)
endfunction

function InsertMemblockInt(memblock as integer, offset as integer, value as integer)
    InsertMemblockRawValue(memblock, offset, SIZE_INT)
    SetMemblockInt(memblock, offset, value)
endfunction

function RemoveMemblockInt(memblock as integer, offset as integer)
    RemoveMemblockRawValue(memblock, offset, SIZE_INT)
endfunction

function ReplaceMemblockInt(memblock as integer, offset as integer, value as integer)
    if offset < 0 then exitfunction
    if offset + SIZE_INT > GetMemblockSize(memblock) then exitfunction
    SetMemblockInt(memblock, offset, value)
endfunction

// FLOAT
function AddMemblockFloat(memblock as integer, value as float)
    local off as integer : off = GetMemblockSize(memblock)
    AddMemblockRawValue(memblock, SIZE_FLOAT)
    SetMemblockFloat(memblock, off, value)
endfunction

function InsertMemblockFloat(memblock as integer, offset as integer, value as float)
    InsertMemblockRawValue(memblock, offset, SIZE_FLOAT)
    SetMemblockFloat(memblock, offset, value)
endfunction

function RemoveMemblockFloat(memblock as integer, offset as integer)
    RemoveMemblockRawValue(memblock, offset, SIZE_FLOAT)
endfunction

function ReplaceMemblockFloat(memblock as integer, offset as integer, value as float)
    if offset < 0 then exitfunction
    if offset + SIZE_FLOAT > GetMemblockSize(memblock) then exitfunction
    SetMemblockFloat(memblock, offset, value)
endfunction

// STRING (raw, zero-terminated)
function AddMemblockString(memblock as integer, value as string)
    local strLen as integer : strLen = ByteLen(value)
    local off as integer : off = GetMemblockSize(memblock)
    AddMemblockRawValue(memblock, strLen + 1)
    SetMemblockString(memblock, off, value)
    SetMemblockByte(memblock, off + strLen, 0) // null terminator
endfunction

function InsertMemblockString(memblock as integer, offset as integer, value as string)
    local strLen as integer : strLen = ByteLen(value)
    InsertMemblockRawValue(memblock, offset, strLen + 1)
    SetMemblockString(memblock, offset, value)
    SetMemblockByte(memblock, offset + strLen, 0)
endfunction

function RemoveMemblockString(memblock as integer, offset as integer, length as integer)
    if length < 0 then exitfunction
    RemoveMemblockRawValue(memblock, offset, length + 1)
endfunction

function ReplaceMemblockString(memblock as integer, offset as integer, oldLength as integer, newValue as string)
    local newLen as integer : newLen = ByteLen(newValue)
    ReplaceMemblockRawValue(memblock, offset, oldLength + 1, newLen + 1)
    SetMemblockString(memblock, offset, newValue)
    SetMemblockByte(memblock, offset + newLen, 0)
endfunction

// STRING SMART: [int length][bytes][optional 0]
function AddMemblockStringSmart(memblock as integer, value as string)
    local strLen as integer : strLen = ByteLen(value)
    local off as integer : off = GetMemblockSize(memblock)
    AddMemblockRawValue(memblock, SIZE_INT + strLen + 1)
    SetMemblockInt(memblock, off, strLen)
    SetMemblockString(memblock, off + SIZE_INT, value)
    SetMemblockByte(memblock, off + SIZE_INT + strLen, 0)
endfunction

function InsertMemblockStringSmart(memblock as integer, offset as integer, value as string)
    local strLen as integer : strLen = ByteLen(value)
    InsertMemblockRawValue(memblock, offset, SIZE_INT + strLen + 1)
    SetMemblockInt(memblock, offset, strLen)
    SetMemblockString(memblock, offset + SIZE_INT, value)
    SetMemblockByte(memblock, offset + SIZE_INT + strLen, 0)
endfunction

function RemoveMemblockStringSmart(memblock as integer, offset as integer)
    local strLen as integer : strLen = GetMemblockInt(memblock, offset)
    if strLen < 0 then exitfunction
    local total as integer : total = SIZE_INT + strLen + 1
    RemoveMemblockRawValue(memblock, offset, total)
endfunction

function ReplaceMemblockStringSmart(memblock as integer, offset as integer, newValue as string)
    local oldLen as integer : oldLen = GetMemblockInt(memblock, offset)
    if oldLen < 0 then exitfunction
    local newLen as integer : newLen = ByteLen(newValue)
    ReplaceMemblockRawValue(memblock, offset, SIZE_INT + oldLen + 1, SIZE_INT + newLen + 1)
    SetMemblockInt(memblock, offset, newLen)
    SetMemblockString(memblock, offset + SIZE_INT, newValue)
    SetMemblockByte(memblock, offset + SIZE_INT + newLen, 0)
endfunction

// -----------------------------
// End of library
// -----------------------------
// Example usage (quick):
// mem = CreateMemblock(0)
// AddMemblockInt(mem, 123)
// AddMemblockStringSmart(mem, "hello")
// s = GetMemblockStringSmartSafe(mem, 4)
// DeleteMemblock(mem)
