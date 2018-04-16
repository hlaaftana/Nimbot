template test*(body: untyped): untyped =
  block:
    proc testProc(arg: string) =
      let arg {.inject, used.} = arg
      body
    testProc

let x = test:
  echo "hi"

x("arg")