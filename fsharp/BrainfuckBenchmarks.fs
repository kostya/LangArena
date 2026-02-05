namespace Benchmarks

open System
open System.Collections.Generic

type ArrayTape() =
    let mutable tape = Array.zeroCreate<byte> 30000
    let mutable pos = 0

    member _.Get() = tape.[pos]

    member _.Inc() = tape.[pos] <- tape.[pos] + 1uy

    member _.Dec() = tape.[pos] <- tape.[pos] - 1uy

    member _.Advance() =
        pos <- pos + 1
        if pos >= tape.Length then
            Array.Resize(&tape, tape.Length + 1)  

    member _.Devance() =
        if pos > 0 then pos <- pos - 1

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

    member _.Run() : uint32 =
        let tape = ArrayTape()
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
    | OpInc of int
    | OpMove of int
    | OpPrint
    | OpLoop of BfOp list

type RecTape() =
    let mutable tape = Array.zeroCreate<byte> 1024
    let mutable pos = 0

    member _.Get() = tape.[pos]

    member _.Inc(x: int) = 
        tape.[pos] <- byte (int tape.[pos] + x)

    member _.Move(x: int) =
        if x >= 0 then
            pos <- pos + x
            if pos >= tape.Length then
                let newSize = max (tape.Length * 2) (pos + 1)
                Array.Resize(&tape, newSize)
        else
            let moveLeft = -x
            if moveLeft > int pos then
                let needed = moveLeft - int pos
                let newTape = Array.zeroCreate<byte> (tape.Length + needed)
                Array.Copy(tape, 0, newTape, needed, tape.Length)
                tape <- newTape
                pos <- needed
            else
                pos <- pos - moveLeft

type BrainfuckRecursionProgram(code: string) =
    let mutable result = 0u

    static member private Parse(it: int byref, code: string) : BfOp list =
        let rec parseLoop currentPos acc =
            if currentPos >= code.Length then
                (List.rev acc, currentPos)
            else
                let c = code.[currentPos]
                match c with
                | '+' -> parseLoop (currentPos + 1) (OpInc(1) :: acc)
                | '-' -> parseLoop (currentPos + 1) (OpInc(-1) :: acc)
                | '>' -> parseLoop (currentPos + 1) (OpMove(1) :: acc)
                | '<' -> parseLoop (currentPos + 1) (OpMove(-1) :: acc)
                | '.' -> parseLoop (currentPos + 1) (OpPrint :: acc)
                | '[' ->
                    let (innerOps, newPos) = parseLoop (currentPos + 1) []
                    parseLoop newPos (OpLoop(innerOps) :: acc)
                | ']' -> (List.rev acc, currentPos + 1)
                | _ -> parseLoop (currentPos + 1) acc

        let (ops, newPos) = parseLoop it []
        it <- newPos
        ops

    member private this.RunOps(ops: BfOp list, tape: RecTape) =
        let rec execute op =
            match op with
            | OpInc(x) -> tape.Inc(x)
            | OpMove(x) -> tape.Move(x)
            | OpPrint -> 

                let r64 = int64 result
                let v64 = int64 (tape.Get())
                result <- uint32 ((r64 <<< 2) + v64)
            | OpLoop(innerOps) ->
                while tape.Get() <> 0uy do
                    for innerOp in innerOps do
                        execute innerOp

        for op in ops do
            execute op

    member this.Run() =
        let mutable index = 0
        let ops = BrainfuckRecursionProgram.Parse(&index, code)
        let tape = RecTape()
        this.RunOps(ops, tape)

    member this.Result = result

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
            let program = BrainfuckRecursionProgram(warmupText)
            program.Run() |> ignore

    override this.Run(_: int64) =
        let program = BrainfuckRecursionProgram(text)
        program.Run()
        result <- result + program.Result