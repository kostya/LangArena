namespace Benchmarks

open System
open System.Collections.Generic

[<Struct>]
type ArrayTape =
    val mutable tape: byte[]
    val mutable pos: int

    new(tape: byte[], pos: int) = 
        { tape = tape
          pos = pos }

    static member Default() : ArrayTape =
        ArrayTape(Array.zeroCreate<byte> 30000, 0)

    member this.Get() : byte = this.tape.[this.pos]

    member this.Inc() : unit = 
        this.tape.[this.pos] <- this.tape.[this.pos] + 1uy

    member this.Dec() : unit = 
        this.tape.[this.pos] <- this.tape.[this.pos] - 1uy

    member this.Advance() : unit =
        this.pos <- this.pos + 1
        if this.pos >= this.tape.Length then
            Array.Resize(&this.tape, this.tape.Length + 1)

    member this.Devance() : unit =
        if this.pos > 0 then this.pos <- this.pos - 1

type BrainfuckArrayProgram(text: string) =
    let commands = ResizeArray<byte>()
    let mutable jumps: int[] = Array.zeroCreate 0

    do

        for c in text do
            if "[]<>+-,.".Contains(c) then
                commands.Add(byte c)

        let jumpsArray = Array.zeroCreate commands.Count
        let stack = Stack<int>()

        for i in 0 .. commands.Count - 1 do
            let cmd = commands.[i]
            if cmd = byte '[' then
                stack.Push(i)
            elif cmd = byte ']' && stack.Count > 0 then
                let start = stack.Pop()
                jumpsArray.[start] <- i
                jumpsArray.[i] <- start

        jumps <- jumpsArray

    member _.RunInternal(commands: ResizeArray<byte>, jumps: int[]) : uint32 =
        let mutable tape = ArrayTape.Default()
        let mutable pc = 0
        let mutable result = 0u

        while pc < commands.Count do
            let cmd = commands.[pc]

            if cmd = byte '[' && tape.Get() = 0uy then
                pc <- jumps.[pc]
            elif cmd = byte ']' && tape.Get() <> 0uy then
                pc <- jumps.[pc]
            else
                match cmd with
                | b when b = byte '+' -> tape.Inc()
                | b when b = byte '-' -> tape.Dec()
                | b when b = byte '>' -> tape.Advance()
                | b when b = byte '<' -> tape.Devance()
                | b when b = byte '.' ->

                    let r64 = int64 result
                    let v64 = int64 (tape.Get())
                    result <- uint32 ((r64 <<< 2) + v64)
                | _ -> ()

            pc <- pc + 1

        result

    member this.Run() : uint32 = this.RunInternal(commands, jumps)

type BrainfuckArray() =
    inherit Benchmark()

    let mutable programText = ""
    let mutable warmupText = ""
    let mutable result = 0u

    override this.Checksum = result

    override this.Prepare() =
        programText <- Helper.Config_s("BrainfuckArray", "program")
        warmupText <- Helper.Config_s("BrainfuckArray", "warmup_program")
        result <- 0u

    override this.Warmup() =
        let prepareIters = base.WarmupIterations
        for i in 0L .. prepareIters - 1L do
            let program = BrainfuckArrayProgram(warmupText)
            program.Run() |> ignore

    override this.Run(_: int64) =
        let program = BrainfuckArrayProgram(programText)
        result <- result + program.Run()

type BfOp =
    | OpInc      
    | OpDec      
    | OpNext     
    | OpPrev     
    | OpPrint    
    | OpLoop of BfOp list  

type RecTape() =
    let mutable tape = Array.zeroCreate<byte> 30000
    let mutable pos = 0

    member _.Get() = tape.[pos]
    member _.Inc() = tape.[pos] <- tape.[pos] + 1uy
    member _.Dec() = tape.[pos] <- tape.[pos] - 1uy

    member _.Next() =
        pos <- pos + 1
        if pos >= tape.Length then
            Array.Resize(&tape, pos + 1)

    member _.Prev() =
        if pos > 0 then pos <- pos - 1

type BrainfuckRecursionProgram(code: string) =
    let mutable result = 0u
    let ops = BrainfuckRecursionProgram.Parse(code)

    static member Parse(code: string) : BfOp list =
        let rec parseLoop pos =
            if pos >= code.Length then
                ([], pos)
            else
                match code.[pos] with
                | '+' -> 
                    let (rest, nextPos) = parseLoop (pos + 1)
                    (OpInc :: rest, nextPos)
                | '-' -> 
                    let (rest, nextPos) = parseLoop (pos + 1)
                    (OpDec :: rest, nextPos)
                | '>' -> 
                    let (rest, nextPos) = parseLoop (pos + 1)
                    (OpNext :: rest, nextPos)
                | '<' -> 
                    let (rest, nextPos) = parseLoop (pos + 1)
                    (OpPrev :: rest, nextPos)
                | '.' -> 
                    let (rest, nextPos) = parseLoop (pos + 1)
                    (OpPrint :: rest, nextPos)
                | '[' ->
                    let (inner, nextPos) = parseLoop (pos + 1)
                    let (rest, finalPos) = parseLoop nextPos
                    (OpLoop(inner) :: rest, finalPos)
                | ']' -> ([], pos + 1)
                | _ -> parseLoop (pos + 1)

        let (ops, _) = parseLoop 0
        ops

    member this.Run() =
        let tape = RecTape()
        result <- 0u

        let rec runOps ops =
            for op in ops do
                match op with
                | OpInc -> tape.Inc()
                | OpDec -> tape.Dec()
                | OpNext -> tape.Next()
                | OpPrev -> tape.Prev()
                | OpPrint -> 
                    result <- (result <<< 2) + uint32(tape.Get())
                | OpLoop(inner) ->
                    while tape.Get() <> 0uy do
                        runOps inner

        runOps ops
        result

type BrainfuckRecursion() =
    inherit Benchmark()

    let mutable text = ""
    let mutable warmupText = ""
    let mutable result = 0u

    override this.Checksum = result

    override this.Prepare() =
        text <- Helper.Config_s("BrainfuckRecursion", "program")
        warmupText <- Helper.Config_s("BrainfuckRecursion", "warmup_program")
        result <- 0u

    override this.Warmup() =
        let prepareIters = base.WarmupIterations
        for i in 0L .. prepareIters - 1L do
            BrainfuckRecursionProgram(warmupText).Run() |> ignore

    override this.Run(_: int64) =
        let program = BrainfuckRecursionProgram(text)
        result <- result + program.Run()