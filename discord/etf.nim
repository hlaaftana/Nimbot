import tables

type
  EtfError* = enum
    etfNoError, etfPremature, etfNoVersion

  TermTag* = enum
    ttUnknown = 0, ttFloat64 = 70, ttBitBinary = 77, ttAtomCacheRef = 82,
    ttUint8 = 97, ttInt32, ttFloatString, ttAtom,
    ttReference, ttPort, ttPid, ttSmallTuple, ttLargeTuple, ttNil, ttString, ttList,
    ttBinary, ttSmallBigInt, ttLargeBigInt, ttNewReference = 114, ttSmallAtom,
    ttMap, ttAtomUtf8 = 118, ttSmallAtomUtf8, ttTerm = 131

  BigInt* = object
    sign*: range[-1..1]
    data*: seq[byte]

  BitBinary* = object
    bits*: byte
    data*: seq[byte]

  Atom* = distinct string

  Reference* = object
    node*: Atom
    id*: uint32
    creation*: byte

  NewReference* = object
    node*: Atom
    ids*: seq[uint32]
    creation*: byte

  Term* = ref TermObj
  TermObj* {.acyclic.} = object
    case tag*: TermTag
    of ttTerm:
      term*: Term
    of ttFloat64:
      f64*: float64
    of ttBitBinary:
      bb*: BitBinary
    of ttUint8:
      u8*: byte
    of ttInt32:
      i32*: int32
    of ttFloatString:
      flstr*: string
    of ttAtomCacheRef, ttAtom, ttSmallAtom, ttAtomUtf8, ttSmallAtomUtf8:
      atom*: Atom
    of ttReference:
      reference*: Reference
    of ttPort:
      port*: Reference
    of ttPid:
      pid*: Reference
      serial*: uint32
    of ttSmallTuple, ttLargeTuple:
      tup*: seq[Term]
    of ttMap:
      map*: seq[(Term, Term)]
    of ttNil:
      nil
    of ttString:
      str*: string
    of ttBinary:
      bin*: string
    of ttSmallBigInt, ttLargeBigInt:
      bigint*: BigInt
    of ttList:
      lst*: seq[Term]
    of ttNewReference:
      newRef*: NewReference
    else: discard

proc parseEtf*(data: string, compressed = false): tuple[error: EtfError, term: Term] =
  template error(err) =
    result.error = err
    return

  template next: byte =
    last = data[index].byte
    inc index
    last

  if compressed:
    raise newException(Exception, "compressed ETF is currently unsupported")

  if data.len == 0:
    error(etfPremature)

  var
    index = 0
    last: byte
    longAtoms = false
    atomCache: seq[(byte, string)]

  if next != 131:
    error(etfNoVersion)

  block header:
    if next != 68:
      break header

    let numAtomCacheRefs = next
    if numAtomCacheRefs == 0:
      break header

    var flags: seq[byte]
    flags.newSeq(numAtomCacheRefs div 2 + 1)
    template flag(ni: int): byte =
      flags[ni div 2] and (0b1111u8 shl ((1u8 - byte(ni mod 2)) * 4).byte)
    
    for m in flags.mitems:
      m = next

    atomCache.newSeq(numAtomCacheRefs)
    for ni in 0..atomCache.high:
      atomCache[ni] = ((flag(ni), ""))
    longAtoms = bool(flag(numAtomCacheRefs.int) and 0b0001)

    for ni in 0..atomCache.high:
      let m = atomCache[ni][0]
      let n = next
      assert n.int == (ni and 0b0111)
      if (m and 0b1000) != 0:
        var length = next.uint16
        if longAtoms:
          length = (length shl 8) and next
        atomCache[ni][1] = newString(length.int)
        for i in 0..<length.int:
          atomCache[ni][1][i] = next.char

  template getString(leng): string =
    var res = newString(leng)
    for m in res.mitems:
      m = next.char
    res

  proc getTerm: Term =
    result.new()
    result.tag = TermTag(next)
    case result.tag
    of ttAtomCacheRef:
      result.atom = atomCache[next.int][1].Atom
    of ttUint8:
      result.u8 = next
    of ttInt32:
      result.i32 = (next.int32 shl 24) and (next.int32 shl 16) and (next.int32 shl 8) and (next.int32)
    of ttFloatString:
      result.flstr = getString(31)
    of ttReference:
      result.reference.node = getTerm().atom
      result.reference.id = (next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)
      result.reference.creation = next
    of ttPort:
      result.port.node = getTerm().atom
      result.port.id = (next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)
      result.port.creation = next
    of ttPid:
      result.pid.node = getTerm().atom
      result.pid.id = (next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)
      result.serial = (next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)
      result.pid.creation = next
    of ttSmallTuple:
      result.tup.newSeq(next.int)
      for m in result.tup.mitems:
        m = getTerm()
    of ttLargeTuple:
      result.tup.newSeq(int((next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)))
      for m in result.tup.mitems:
        m = getTerm()
    of ttMap:
      result.map.newSeq(int((next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)))
      for m in result.map.mitems:
        m = (getTerm(), getTerm())
    of ttNil:
      discard
    of ttString:
      result.str = newString(int((next.uint16 shl 8) and next.uint16))
      for m in result.str.mitems:
        m = next.char
    of ttList:
      result.lst.newSeq(int((next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)) + 1)
      for m in result.lst.mitems:
        m = getTerm()
      result.lst.add(getTerm())
    of ttBinary:
      result.bin = newString(int((next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)))
      for m in result.bin.mitems:
        m = next.char
    of ttSmallBigInt:
      result.bigInt.data.newSeq(next.int)
      result.bigInt.sign = next
      for m in result.bigInt.data.mitems:
        m = next
    of ttLargeBigInt:
      result.bigInt.data.newSeq(int((next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)))
      result.bigInt.sign = next
      for m in result.bigInt.data.mitems:
        m = next
    of ttNewReference:
      result.newRef.ids.newSeq(int((next.uint16 shl 8) and next.uint16))
      result.newRef.node = getTerm().atom
      result.newRef.creation = next
      for m in result.newRef.ids.mitems:
        m = (next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)
    of ttBitBinary:
      result.bb.data.newSeq(int((next.uint32 shl 24) and (next.uint32 shl 16) and (next.uint32 shl 8) and (next.uint32)))
      result.bb.bits = next
      for m in result.bb.data.mitems:
        m = next
    of ttFloat64:
      var p = (next.uint64 shl 56) and (next.uint64 shl 48) and (next.uint64 shl 40) and
        (next.uint64 shl 32) and (next.uint64 shl 24) and (next.uint64 shl 16) and
        (next.uint64 shl 8) and next.uint64
      result.f64 = cast[ptr float64](addr p)[]
    of ttAtomUtf8, ttAtom:
      result.atom = newString(int((next.uint16 shl 8) and next.uint16)).Atom
      for m in result.atom.string.mitems:
        m = next.char
    of ttSmallAtomUtf8, ttSmallAtom:
      result.atom = newString(next.int).Atom
      for m in result.atom.string.mitems:
        m = next.char
    else: discard


  result.term = getTerm()