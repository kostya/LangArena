namespace Benchmarks

open System
open System.Text
open System.Collections.Generic

[<AbstractClass>]
type Node() = class end

type Number(value: int64) =
    inherit Node()
    member _.Value = value

type Variable(name: string) =
    inherit Node()
    member _.Name = name

type BinaryOp(op: char, left: Node, right: Node) =
    inherit Node()
    member _.Op = op
    member _.Left = left
    member _.Right = right

type Assignment(varName: string, expr: Node) =
    inherit Node()
    member _.Var = varName
    member _.Expr = expr

[<AllowNullLiteral>]
type Parser(input: string) =
    let chars = input.ToCharArray()
    let mutable pos = 0
    let mutable currentChar = if chars.Length > 0 then chars.[0] else '\000'
    let expressions = List<Node>()

    let advance() = 
        if pos < chars.Length then
            pos <- pos + 1
            if pos < chars.Length then 
                currentChar <- chars.[pos]
            else
                currentChar <- '\000'

    let skipWhitespace() =
        while pos < chars.Length && Char.IsWhiteSpace(currentChar) do
            advance()

    let rec parseNumber() =
        let mutable value = 0L
        while pos < chars.Length && Char.IsDigit(currentChar) do
            value <- value * 10L + int64(currentChar - '0')
            advance()
        Number(value) :> Node

    let rec parseVariable() =
        let start = pos
        while pos < chars.Length && 
              (Char.IsLetterOrDigit(currentChar) || currentChar = '_') do
            advance()

        let varName = input.Substring(start, pos - start)

        skipWhitespace()
        if pos < chars.Length && currentChar = '=' then
            advance()
            let expr = parseExpression()
            Assignment(varName, expr) :> Node
        else
            Variable(varName) :> Node

    and parseExpression() =
        let mutable node = parseTerm()
        let mutable continueLoop = true

        while pos < chars.Length && continueLoop do
            skipWhitespace()
            if pos >= chars.Length then 
                continueLoop <- false
            else
                let ch = currentChar
                if ch = '+' || ch = '-' then
                    let op = ch
                    advance()
                    let right = parseTerm()
                    node <- BinaryOp(op, node, right) :> Node
                else
                    continueLoop <- false

        node

    and parseTerm() =
        let mutable node = parseFactor()
        let mutable continueLoop = true

        while pos < chars.Length && continueLoop do
            skipWhitespace()
            if pos >= chars.Length then 
                continueLoop <- false
            else
                let ch = currentChar
                if ch = '*' || ch = '/' || ch = '%' then
                    let op = ch
                    advance()
                    let right = parseFactor()
                    node <- BinaryOp(op, node, right) :> Node
                else
                    continueLoop <- false

        node

    and parseFactor() =
        skipWhitespace()
        if pos >= chars.Length then Number(0L) :> Node
        else
            match currentChar with
            | ch when Char.IsDigit(ch) -> parseNumber()
            | ch when Char.IsLetter(ch) -> parseVariable()
            | '(' ->
                advance()
                let node = parseExpression()
                skipWhitespace()
                if pos < chars.Length && currentChar = ')' then advance()
                node
            | _ -> Number(0L) :> Node

    member _.Parse() =
        while pos < chars.Length do
            skipWhitespace()
            if pos >= chars.Length then ()
            else
                let expr = parseExpression()
                expressions.Add(expr)

                skipWhitespace()

        List.ofSeq expressions

type Interpreter() =
    let variables = Dictionary<string, int64>()

    let safeAbs (x: int64) =
        if x >= 0L then x
        elif x = Int64.MinValue then Int64.MaxValue
        else -x

    let simpleDiv (a: int64) (b: int64) =
        if b = 0L then 0L
        elif (a >= 0L && b > 0L) || (a < 0L && b < 0L) then a / b
        else
            let absA = safeAbs a
            let absB = safeAbs b
            -(absA / absB)

    let simpleMod (a: int64) (b: int64) =
        if b = 0L then 0L
        else a - simpleDiv a b * b

    let rec evaluate (node: Node) =
        match node with
        | :? Number as num -> num.Value
        | :? Variable as var ->
            match variables.TryGetValue(var.Name) with
            | true, value -> value
            | false, _ -> 0L
        | :? BinaryOp as bin ->
            let left = evaluate bin.Left
            let right = evaluate bin.Right

            match bin.Op with
            | '+' -> left + right
            | '-' -> left - right
            | '*' -> left * right
            | '/' -> simpleDiv left right
            | '%' -> simpleMod left right
            | _ -> 0L
        | :? Assignment as assign ->
            let value = evaluate assign.Expr
            variables.[assign.Var] <- value
            value
        | _ -> 0L

    member _.Run(expressions: Node list) =
        let mutable result = 0L
        for expr in expressions do
            result <- evaluate expr
        result

module ProgramGenerator =
    let generateRandomProgram (n: int64) =
        let sb = StringBuilder()
        sb.AppendLine("v0 = 1") |> ignore

        for i = 0 to 9 do
            let v = i + 1
            sb.AppendLine($"v{v} = v{v - 1} + {v}") |> ignore

        let mutable i = 0L
        while i < n do
            let v = int(i + 10L)
            sb.Append($"v{v} = v{v - 1} + ") |> ignore

            match Helper.NextInt(10) with
            | 0 -> sb.AppendFormat("(v{0} / 3) * 4 - {1} / (3 + (18 - v{2})) % v{3} + 2 * ((9 - v{4}) * (v{5} + 7))", 
                    v - 1, i, v - 2, v - 3, v - 6, v - 5) |> ignore
            | 1 -> sb.AppendFormat("v{0} + (v{1} + v{2}) * v{3} - (v{4} / v{5})", 
                    v - 1, v - 2, v - 3, v - 4, v - 5, v - 6) |> ignore
            | 2 -> sb.AppendFormat("(3789 - (((v{0})))) + 1", v - 7) |> ignore
            | 3 -> sb.AppendFormat("4/2 * (1-3) + v{0}/v{1}", v - 9, v - 5) |> ignore
            | 4 -> sb.AppendFormat("1+2+3+4+5+6+v{0}", v - 1) |> ignore
            | 5 -> sb.AppendFormat("(99999 / v{0})", v - 3) |> ignore
            | 6 -> sb.AppendFormat("0 + 0 - v{0}", v - 8) |> ignore
            | 7 -> sb.AppendFormat("((((((((((v{0})))))))))) * 2", v - 6) |> ignore
            | 8 -> sb.AppendFormat("{0} * (v{1}%6)%7", i, v - 1) |> ignore
            | 9 -> sb.AppendFormat("(1)/(0-v{0}) + (v{1})", v - 5, v - 7) |> ignore
            | _ -> ()

            sb.AppendLine() |> ignore
            i <- i + 1L

        sb.ToString()

type CalculatorAst() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable text = ""
    let mutable result = 0u
    let mutable expressions: Node list = []

    member this.SetOperations(operations: int64) =
        n <- operations
        text <- ProgramGenerator.generateRandomProgram n

    member this.Parse() =
        let parser = Parser(text)
        expressions <- parser.Parse()

        result <- result + uint32 expressions.Length

        match expressions with
        | [] -> ()
        | _ ->
            let last = expressions |> List.last
            match last with
            | :? Assignment as assign -> result <- result + Helper.Checksum(assign.Var)
            | _ -> ()

    member this.Expressions = expressions

    override this.Checksum = result
    override this.Name = "Calculator::Ast"

    override this.Prepare() =
        n <- this.ConfigVal("operations")
        this.SetOperations(n)
        result <- 0u  

    override this.Run(_: int64) =
        this.Parse()  

type CalculatorInterpreter() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable result = 0u
    let mutable ast: Node list = []

    override this.Checksum = result
    override this.Name = "Calculator::Interpreter"

    override this.Prepare() =
        n <- this.ConfigVal("operations")

        let calculator = CalculatorAst()
        calculator.SetOperations(n)
        calculator.Parse()

        ast <- calculator.Expressions

        result <- 0u

    override this.Run(_: int64) =
        let interpreter = Interpreter()
        let calcResult = interpreter.Run(ast)
        result <- result + uint32 calcResult