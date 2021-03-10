# [https://forum.nim-lang.org/t/1730#18658]

import strutils, os
import nimbench

proc editDistance2*(a, b: string): int = #{.noSideEffect.} =
  ## Returns the edit distance between `a` and `b`.
  ##
  ## This uses the `Levenshtein`:idx: distance algorithm with only a linear
  ## memory overhead.  This implementation is highly optimized!
  var len1 = a.len
  var len2 = b.len
  if len1 > len2:
    # make `b` the longer string
    return editDistance2(b, a)

  # strip common prefix:
  var s = 0
  while a[s] == b[s] and a[s] != '\0':
    inc(s)
    dec(len1)
    dec(len2)

  # strip common suffix:
  while len1 > 0 and len2 > 0 and a[s+len1-1] == b[s+len2-1]:
    dec(len1)
    dec(len2)

  # trivial cases:
  if len1 == 0: return len2
  if len2 == 0: return len1

  # another special case:
  if len1 == 1:
    for j in s..s+len2-1:
      if a[s] == b[j]: return len2 - 1

    return len2

  inc(len1)
  inc(len2)
  var row: seq[int]
  newSeq(row, len2)

  for i in 0..len2 - 1: row[i] = i

  for i in 1 .. len1- 1:
    var char1 = a[s + i - 1]
    var prevCost = i - 1;
    var newCost = i;

    for j in 1 .. len2 - 1:
      var char2 = b[s + j - 1]

      if char1 == char2:
        newCost = prevCost
      else:
        newCost = min(newCost, min(prevCost, row[j])) + 1

      prevCost = row[j]
      row[j] = newCost

  result = row[len2 - 1]

var s1: string = "0123456789"
var s2: string = "0123455779"

if paramCount() > 1:
  if fileExists(paramStr(1)):
    s1 = readFile(paramStr(1))
  else:
    s1 = paramStr(1)

  if fileExists(paramStr(2)):
    s2 = readFile(paramStr(2))
  else:
    s2 = paramStr(2)

echo "editDistance:  ", editDistance(s1, s2)
echo "editDistance2: ", editDistance2(s1, s2)

bench(editDistance, m):
  var d = 0
  for i in 1..m:
    d = editDistance(s1, s2)

  doNotOptimizeAway(d)

benchRelative(editDistance2, m):
  var d = 0

  for i in 1..m:
    d = editDistance2(s1, s2)

  doNotOptimizeAway(d)


runBenchmarks()
