# [https://forum.nim-lang.org/t/1793]
# [https://forum.nim-lang.org/t/1793#11369]
# [https://gist.github.com/Varriount/fd56b757c6de57ab9712]

import typeinfo
import macros

proc c_memcpy(a, b: pointer, n: int) {.importc: "memcpy", header: "<string.h>".}


type
  ImmutableStringDesc {.compilerproc, pure, inheritable.} = object
    length, reserved: int
    isShared: bool
    when defined(gogc):
      elemSize: int
    data*: UncheckedCharArray

  UncheckedCharArray {.unchecked.} = array[0..100, char]

  UnsafeImmutableString = ref ImmutableStringDesc
  ImmutableString* = UnsafeImmutableString not nil

  nnstring = string not nil


# Utility Procedures
proc len*(str: ImmutableString): int {.inline, gcsafe.}
proc high*(str: ImmutableString): int {.inline, gcsafe.}

proc checkImmStr[T](a: T) =
  ## Check basic immutable string integrity
  assert(len(a) >= 0)
  if len(a) != 0:
    assert(cast[ptr char](getContentAddress(a, len(a)))[] == '\0')

template getContentAddress(str: string, position): expr =
  pointer(unsafeAddr(str[position]))

template getContentAddress(str: ImmutableString, position: int): expr =
  pointer(unsafeAddr(str.data[position]))

proc copyStringContent[A, B](source: A, dest: var B,
                       length = -1, srcStart, dstStart = Natural(0)) =
    let bytesToCopy = (
      if length != -1:
        length else:
        (len(source) - srcStart)
    )

    assert(bytesToCopy >= 0)
    assert(srcStart >= 0)
    assert(dstStart >= 0)
    assert(srcStart <= high(source))
    assert(dstStart <= high(dstStart))
    assert(bytesToCopy+srcStart-1 <= len(source))
    assert(bytesToCopy+dstStart-1 <= len(dest))


    c_memcpy(
      getContentAddress(dest, dstStart),
      getContentAddress(source, srcStart),
      bytesToCopy
    )
    checkImmStr(dest)


# Allocation and creation procedures.

proc allocImmutableString(length: int): ImmutableString =
  # Allocate an extra byte for the null, so that cstring conversion is
  # O(1)
  unsafeNew[ImmutableStringDesc](
    result,
    sizeof(ImmutableStringDesc) + (length + 1)*sizeof(char)
  )
  result.length = length
  result.reserved = length
  checkImmStr(result)


proc newImmutableStringImpl[T](src: T, bytesToCopy: Natural): ImmutableString =
  result = allocImmutableString(bytesToCopy)
  copyStringContent(src, result, bytesToCopy)
  checkImmStr(result)

proc newImmutableString*(src: string not nil): ImmutableString =
  newImmutableStringImpl(src, len(src))

proc newImmutableString*(src: ImmutableString): ImmutableString =
  result = src

proc im*(s: static[string]): ImmutableString =
  result = newImmutableString(s)


# Read procedures

proc len*(str: ImmutableString not nil): int =
  result = str.length

proc high*(str: ImmutableString): int =
  result = len(str) - 1

proc low*(str: ImmutableString): int {.inline.} =
  result = 0

proc substr*(str: ImmutableString, start, last: int): ImmutableString =
  result = cast[ImmutableString](substr(cast[string](str), start, last))

proc substr*(str:ImmutableString, slice: Slice[int]): ImmutableString =
  substr(str, slice.a, slice.b)

proc substr*(s: ImmutableString, first = 0): ImmutableString =
  result = substr(s, first, len(s)-1)


proc `[]`*(str: ImmutableString, i: int): char =
  result = cast[string](str)[i]

proc `[]`*(str: ImmutableString, slice: Slice[int]): ImmutableString =
  result = str.substr(slice.a, slice.b)


iterator items*(str: ImmutableString): char =
  for i in 0..(str.length - 1):
    yield str.data[i]


# Helper
template genOperatorDoubleProc(name, returnType, code) {.dirty.} =
  # Generates a comparison procedure for an immutable string.
  proc `name`*(a: ImmutableString, b: ImmutableString): returnType =
    code
  proc `name`*(a: ImmutableString, b: string not nil): returnType =
    code

template genOperatorTripleProc(name, returnType, code) {.dirty.} =
  # Generates a comparison procedure for an immutable string.
  proc `name`*(a: ImmutableString, b: ImmutableString): returnType =
    code
  proc `name`*(a: ImmutableString, b: string not nil): returnType =
    code
  proc `name`*(a: string not nil, b: ImmutableString): returnType =
    code


# Comparison Procedures
genOperatorTripleProc(`==`, bool) do:
  result = cast[string](a) == cast[string](b)

genOperatorTripleProc(`<=`, bool) do:
  result = cast[string](a) <= cast[string](b)

genOperatorTripleProc(`<`, bool) do:
  result = cast[string](a) < cast[string](b)

genOperatorTripleProc(cmp, int) do:
  result = cmp(cast[string](a), cast[string](b))


# Write procedures
proc `$`*(str: ImmutableString): string =
  result = newString(len(str))
  copyStringContent(str, result, len(str))

proc unsafeStringify*(str: ImmutableString): string =
  echo(repr(unsafeAddr str.data))
  result = cast[string](str)
  echo(repr(unsafeAddr result[0]))


genOperatorDoubleProc(`&`, ImmutableString) do:
  result = allocImmutableString(len(a) + len(b))
  copyStringContent(a, result, len(a))
  copyStringContent(b, result, len(b), 0, len(a))
  checkImmStr(result)

proc `&`*(x: string, y: ImmutableString): string =
  result = x & cast[string](y)

proc `&`*(x: ImmutableString, y: char): ImmutableString =
  result = allocImmutableString(len(x) + sizeof(y))
  copyStringContent(x, result, len(x))
  result.data[len(x)] = y
  checkImmStr(result)

proc `&`*(x: char; y: ImmutableString): ImmutableString =
  result = y & x


proc add*(x: var ImmutableString; y: ImmutableString) =
  x = x & y

proc add*(x: var ImmutableString; y: string not nil) =
  x = x & y

proc add*(x: var ImmutableString, y: char) =
  x = x & y

proc add*(a: var string, b: ImmutableString) =
  a.add(cast[string](b))


proc `&=`*(x: var ImmutableString; y: ImmutableString) =
  x.add(y)

proc `&=`*(x: var ImmutableString; y: string not nil) =
  x.add(y)

proc `&=`*(x: var ImmutableString; y: char) =
  x.add(y)

proc `&=`*(x: var string; y: ImmutableString) =
  x &= cast[string](y)


proc `[]=`*(s: var ImmutableString; x: int; b: char) =
  var res = allocImmutableString(len(s))
  copyStringContent(s, res, len(s))
  res.data[x] = b
  checkImmStr(res)
  s = res

proc `[]=`*(str: var ImmutableString; slice: Slice[int]; part: string) =
  let resultLength = len(str) - (slice.b - slice.a + 1) + len(part)
  var res = allocImmutableString(resultLength)
  copyStringContent(str, res, slice.a)
  copyStringContent(part, res, len(part), 0, slice.a)
  copyStringContent(str, res, len(str) - slice.b, slice.b+1, slice.a+len(part))
  str = res

# proc insert*(x: var ImmutableString; item: SomeString; i = 0.Natural) =
#   let res = allocImmutableString(len(x)+len(item))
#   copyStringContent(x, res, i)
#   copyStringContent(x, res, len(x)-i-2, i, i+len(item)-2)
#   copyStringContent(item, res, len(item), 0, i)
#   x = res
#   checkImmStr(res)
