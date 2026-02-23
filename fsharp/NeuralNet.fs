namespace Benchmarks

open System

type Synapse(sourceNeuron: Neuron, destNeuron: Neuron) =
    let mutable weight = Helper.NextFloat(1.0) * 2.0 - 1.0
    let mutable prevWeight = weight

    member _.SourceNeuron = sourceNeuron
    member _.DestNeuron = destNeuron

    member _.Weight 
        with get() = weight 
        and set(v) = weight <- v

    member _.PrevWeight 
        with get() = prevWeight 
        and set(v) = prevWeight <- v

and Neuron() =
    [<Literal>]
    let LEARNING_RATE = 1.0

    [<Literal>]
    let MOMENTUM = 0.3

    let synapsesIn = ResizeArray<Synapse>()
    let synapsesOut = ResizeArray<Synapse>()

    let mutable threshold = Helper.NextFloat(1.0) * 2.0 - 1.0
    let mutable prevThreshold = threshold
    let mutable error = 0.0
    let mutable output = 0.0

    member _.SynapsesIn = synapsesIn
    member _.SynapsesOut = synapsesOut

    member _.Threshold 
        with get() = threshold 
        and set(v) = threshold <- v

    member _.PrevThreshold 
        with get() = prevThreshold 
        and set(v) = prevThreshold <- v

    member _.Error 
        with get() = error 
        and set(v) = error <- v

    member _.Output 
        with get() = output 
        and set(v) = output <- v

    member this.CalculateOutput() =
        let mutable activation = 0.0
        for synapse in synapsesIn do
            activation <- activation + synapse.Weight * synapse.SourceNeuron.Output
        activation <- activation - threshold
        output <- 1.0 / (1.0 + exp(-activation))

    member private this.Derivative() = output * (1.0 - output)

    member this.OutputTrain(rate: double, target: double) =
        error <- (target - output) * this.Derivative()
        this.UpdateWeights(rate)

    member this.HiddenTrain(rate: double) =
        error <- 0.0
        for synapse in synapsesOut do
            error <- error + synapse.PrevWeight * synapse.DestNeuron.Error
        error <- error * this.Derivative()
        this.UpdateWeights(rate)

    member private this.UpdateWeights(rate: double) =
        for synapse in synapsesIn do
            let tempWeight = synapse.Weight
            synapse.Weight <- synapse.Weight + 
                (rate * LEARNING_RATE * error * synapse.SourceNeuron.Output) +
                (MOMENTUM * (synapse.Weight - synapse.PrevWeight))
            synapse.PrevWeight <- tempWeight

        let tempThreshold = threshold
        threshold <- threshold + 
            (rate * LEARNING_RATE * error * -1.0) +
            (MOMENTUM * (threshold - prevThreshold))
        prevThreshold <- tempThreshold

type NeuralNetwork(inputs: int, hidden: int, outputs: int) =
    let inputLayer = Array.init inputs (fun _ -> Neuron())
    let hiddenLayer = Array.init hidden (fun _ -> Neuron())
    let outputLayer = Array.init outputs (fun _ -> Neuron())

    do

        for source in inputLayer do
            for dest in hiddenLayer do
                let synapse = Synapse(source, dest)
                source.SynapsesOut.Add(synapse)
                dest.SynapsesIn.Add(synapse)

        for source in hiddenLayer do
            for dest in outputLayer do
                let synapse = Synapse(source, dest)
                source.SynapsesOut.Add(synapse)
                dest.SynapsesIn.Add(synapse)

    member this.Train(inputsArr: double[], targets: double[]) =
        this.FeedForward(inputsArr)

        for i = 0 to outputLayer.Length - 1 do
            outputLayer.[i].OutputTrain(0.3, targets.[i])

        for neuron in hiddenLayer do
            neuron.HiddenTrain(0.3)

    member this.FeedForward(inputsArr: double[]) =
        for i = 0 to inputLayer.Length - 1 do
            inputLayer.[i].Output <- inputsArr.[i]

        for neuron in hiddenLayer do
            neuron.CalculateOutput()

        for neuron in outputLayer do
            neuron.CalculateOutput()

    member this.CurrentOutputs() =
        outputLayer |> Array.map (fun n -> n.Output)

    member this.GetWeightSum() =
        let mutable sum = 0.0

        for neuron in inputLayer do
            sum <- sum + neuron.Threshold
            for synapse in neuron.SynapsesOut do
                sum <- sum + synapse.Weight

        for neuron in hiddenLayer do
            sum <- sum + neuron.Threshold
            for synapse in neuron.SynapsesOut do
                sum <- sum + synapse.Weight

        for neuron in outputLayer do
            sum <- sum + neuron.Threshold

        sum

type NeuralNet() =
    inherit Benchmark()

    let mutable xorNet : NeuralNetwork option = None

    override this.Checksum =
        match xorNet with
        | Some net ->
            net.FeedForward([|0.0; 0.0|])
            let outputs1 = net.CurrentOutputs()

            net.FeedForward([|0.0; 1.0|])
            let outputs2 = net.CurrentOutputs()

            net.FeedForward([|1.0; 0.0|])
            let outputs3 = net.CurrentOutputs()

            net.FeedForward([|1.0; 1.0|])
            let outputs4 = net.CurrentOutputs()

            let mutable sum = 0.0

            for v in outputs1 do sum <- sum + v
            for v in outputs2 do sum <- sum + v
            for v in outputs3 do sum <- sum + v
            for v in outputs4 do sum <- sum + v

            Helper.Checksum(sum)
        | None -> 0u
    override this.Name = "Etc::NeuralNet"

    override this.Prepare() =
        xorNet <- Some (NeuralNetwork(2, 10, 1))

    override this.Run(_: int64) =
        match xorNet with
        | Some net ->
            net.Train([|0.0; 0.0|], [|0.0|])
            net.Train([|1.0; 0.0|], [|1.0|])
            net.Train([|0.0; 1.0|], [|1.0|])
            net.Train([|1.0; 1.0|], [|0.0|])
        | None -> ()