import std/[math, random]
import ../benchmark
import ../helper

type
  Neuron = ref object
    synapsesIn: seq[Synapse]
    synapsesOut: seq[Synapse]
    threshold: float
    prevThreshold: float
    error: float
    output: float

  Synapse = ref object
    weight: float
    prevWeight: float
    sourceNeuron: Neuron
    destNeuron: Neuron

  NeuralNetwork = ref object
    inputLayer: seq[Neuron]
    hiddenLayer: seq[Neuron]
    outputLayer: seq[Neuron]
    synapses: seq[Synapse]

  NeuralNet* = ref object of Benchmark
    xorNet: NeuralNetwork

proc newNeuralNet(): Benchmark =
  NeuralNet()

method name(self: NeuralNet): string = "Etc::NeuralNet"

const
  LEARNING_RATE = 1.0
  MOMENTUM = 0.3

proc newNeuron(): Neuron =
  let t = nextFloat() * 2 - 1
  Neuron(
    threshold: t,
    prevThreshold: t,
    output: 0.0,
    error: 0.0
  )

proc newSynapse(source, dest: Neuron): Synapse =
  let weight = nextFloat() * 2 - 1
  Synapse(
    weight: weight,
    prevWeight: weight,
    sourceNeuron: source,
    destNeuron: dest
  )

proc calculateOutput(neuron: Neuron) =
  var activation = 0.0
  for synapse in neuron.synapsesIn:
    activation += synapse.weight * synapse.sourceNeuron.output

  activation -= neuron.threshold
  neuron.output = 1.0 / (1.0 + exp(-activation))

proc derivative(neuron: Neuron): float =
  neuron.output * (1 - neuron.output)

proc outputTrain(neuron: Neuron, rate, target: float) =
  neuron.error = (target - neuron.output) * neuron.derivative()

  for synapse in neuron.synapsesIn:
    let tempWeight = synapse.weight
    synapse.weight += (rate * LEARNING_RATE * neuron.error * synapse.sourceNeuron.output) +
                     (MOMENTUM * (synapse.weight - synapse.prevWeight))
    synapse.prevWeight = tempWeight

  let tempThreshold = neuron.threshold
  neuron.threshold += (rate * LEARNING_RATE * neuron.error * -1) +
                     (MOMENTUM * (neuron.threshold - neuron.prevThreshold))
  neuron.prevThreshold = tempThreshold

proc hiddenTrain(neuron: Neuron, rate: float) =
  var sum = 0.0
  for synapse in neuron.synapsesOut:
    sum += synapse.prevWeight * synapse.destNeuron.error

  neuron.error = sum * neuron.derivative()

  for synapse in neuron.synapsesIn:
    let tempWeight = synapse.weight
    synapse.weight += (rate * LEARNING_RATE * neuron.error * synapse.sourceNeuron.output) +
                     (MOMENTUM * (synapse.weight - synapse.prevWeight))
    synapse.prevWeight = tempWeight

  let tempThreshold = neuron.threshold
  neuron.threshold += (rate * LEARNING_RATE * neuron.error * -1) +
                     (MOMENTUM * (neuron.threshold - neuron.prevThreshold))
  neuron.prevThreshold = tempThreshold

proc newNeuralNetwork(inputs, hidden, outputs: int): NeuralNetwork =
  result = NeuralNetwork()

  result.inputLayer = newSeq[Neuron](inputs)
  for i in 0..<inputs:
    result.inputLayer[i] = newNeuron()

  result.hiddenLayer = newSeq[Neuron](hidden)
  for i in 0..<hidden:
    result.hiddenLayer[i] = newNeuron()

  result.outputLayer = newSeq[Neuron](outputs)
  for i in 0..<outputs:
    result.outputLayer[i] = newNeuron()

  for source in result.inputLayer:
    for dest in result.hiddenLayer:
      let synapse = newSynapse(source, dest)
      source.synapsesOut.add(synapse)
      dest.synapsesIn.add(synapse)
      result.synapses.add(synapse)

  for source in result.hiddenLayer:
    for dest in result.outputLayer:
      let synapse = newSynapse(source, dest)
      source.synapsesOut.add(synapse)
      dest.synapsesIn.add(synapse)
      result.synapses.add(synapse)

proc train(net: NeuralNetwork, inputs, targets: seq[float]) =

  for i in 0..<inputs.len:
    net.inputLayer[i].output = inputs[i]

  for neuron in net.hiddenLayer:
    neuron.calculateOutput()

  for neuron in net.outputLayer:
    neuron.calculateOutput()

  for i in 0..<targets.len:
    net.outputLayer[i].outputTrain(0.3, targets[i])

  for neuron in net.hiddenLayer:
    neuron.hiddenTrain(0.3)

proc currentOutputs(net: NeuralNetwork): seq[float] =
  result = newSeq[float](net.outputLayer.len)
  for i, neuron in net.outputLayer:
    result[i] = neuron.output

method prepare(self: NeuralNet) =
  reset()
  self.xorNet = newNeuralNetwork(2, 10, 1)

method run(self: NeuralNet, iteration_id: int) =
  let net = self.xorNet
  net.train(@[0.0, 0.0], @[0.0])
  net.train(@[1.0, 0.0], @[1.0])
  net.train(@[0.0, 1.0], @[1.0])
  net.train(@[1.0, 1.0], @[0.0])

method checksum(self: NeuralNet): uint32 =
  let net = self.xorNet

  var allOutputs: seq[float]

  for inputs in [@[0.0, 0.0], @[0.0, 1.0], @[1.0, 0.0], @[1.0, 1.0]]:

    for i in 0..<inputs.len:
      net.inputLayer[i].output = inputs[i]

    for neuron in net.hiddenLayer:
      neuron.calculateOutput()

    for neuron in net.outputLayer:
      neuron.calculateOutput()

    allOutputs.add(net.outputLayer[0].output)

  var sum = 0.0
  for v in allOutputs:
    sum += v

  checksumF64(sum)

registerBenchmark("Etc::NeuralNet", newNeuralNet)
