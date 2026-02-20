import Foundation

final class NeuralNet: BenchmarkProtocol {
  private static let LEARNING_RATE = 1.0
  private static let MOMENTUM = 0.3

  final class Synapse {
    let sourceNeuron: Neuron
    let destNeuron: Neuron
    var weight: Double
    var prevWeight: Double

    init(sourceNeuron: Neuron, destNeuron: Neuron) {
      self.sourceNeuron = sourceNeuron
      self.destNeuron = destNeuron
      self.weight = Helper.nextFloat() * 2 - 1
      self.prevWeight = weight
    }
  }

  final class Neuron {
    var threshold: Double
    var prevThreshold: Double
    var synapsesIn: [Synapse] = []
    var synapsesOut: [Synapse] = []
    var output: Double = 0.0
    var error: Double = 0.0

    init() {
      threshold = Helper.nextFloat() * 2 - 1
      prevThreshold = threshold
      synapsesIn.reserveCapacity(10)
      synapsesOut.reserveCapacity(10)
    }

    func calculateOutput() {
      var activation = 0.0
      for synapse in synapsesIn {
        activation += synapse.weight * synapse.sourceNeuron.output
      }
      activation -= threshold
      output = 1.0 / (1.0 + exp(-activation))
    }

    func derivative() -> Double {
      return output * (1 - output)
    }

    func outputTrain(rate: Double, target: Double) {
      error = (target - output) * derivative()
      updateWeights(rate: rate)
    }

    func hiddenTrain(rate: Double) {
      error = 0.0
      for synapse in synapsesOut {
        error += synapse.prevWeight * synapse.destNeuron.error
      }
      error *= derivative()
      updateWeights(rate: rate)
    }

    func updateWeights(rate: Double) {
      for synapse in synapsesIn {
        let tempWeight = synapse.weight
        synapse.weight +=
          (rate * NeuralNet.LEARNING_RATE * error * synapse.sourceNeuron.output)
          + (NeuralNet.MOMENTUM * (synapse.weight - synapse.prevWeight))
        synapse.prevWeight = tempWeight
      }
      let tempThreshold = threshold
      threshold +=
        (rate * NeuralNet.LEARNING_RATE * error * -1)
        + (NeuralNet.MOMENTUM * (threshold - prevThreshold))
      prevThreshold = tempThreshold
    }
  }

  final class NeuralNetwork {
    private let inputLayer: [Neuron]
    private let hiddenLayer: [Neuron]
    private let outputLayer: [Neuron]

    init(inputs: Int, hidden: Int, outputs: Int) {
      inputLayer = (0..<inputs).map { _ in Neuron() }
      hiddenLayer = (0..<hidden).map { _ in Neuron() }
      outputLayer = (0..<outputs).map { _ in Neuron() }

      for input in inputLayer {
        for hidden in hiddenLayer {
          let synapse = Synapse(sourceNeuron: input, destNeuron: hidden)
          input.synapsesOut.append(synapse)
          hidden.synapsesIn.append(synapse)
        }
      }

      for hidden in hiddenLayer {
        for output in outputLayer {
          let synapse = Synapse(sourceNeuron: hidden, destNeuron: output)
          hidden.synapsesOut.append(synapse)
          output.synapsesIn.append(synapse)
        }
      }
    }

    func train(inputs: [Int], targets: [Int]) {
      feedForward(inputs: inputs)
      for (neuron, target) in zip(outputLayer, targets) {
        neuron.outputTrain(rate: 0.3, target: Double(target))
      }
      for neuron in hiddenLayer {
        neuron.hiddenTrain(rate: 0.3)
      }
    }

    func feedForward(inputs: [Int]) {
      for (neuron, input) in zip(inputLayer, inputs) {
        neuron.output = Double(input)
      }
      for neuron in hiddenLayer {
        neuron.calculateOutput()
      }
      for neuron in outputLayer {
        neuron.calculateOutput()
      }
    }

    func currentOutputs() -> [Double] {
      return outputLayer.map { $0.output }
    }
  }

  private var outputs: [Double] = []
  private var xorNet: NeuralNetwork!
  private var resultVal: UInt32 = 0

  init() {
    xorNet = NeuralNetwork(inputs: 0, hidden: 0, outputs: 0)
    outputs.reserveCapacity(4)
  }

  func prepare() {
    xorNet = NeuralNetwork(inputs: 2, hidden: 10, outputs: 1)
  }

  func run(iterationId: Int) {
    xorNet.train(inputs: [0, 0], targets: [0])
    xorNet.train(inputs: [1, 0], targets: [1])
    xorNet.train(inputs: [0, 1], targets: [1])
    xorNet.train(inputs: [1, 1], targets: [0])
  }

  var checksum: UInt32 {
    xorNet.feedForward(inputs: [0, 0])
    let outputs1 = xorNet.currentOutputs()

    xorNet.feedForward(inputs: [0, 1])
    let outputs2 = xorNet.currentOutputs()

    xorNet.feedForward(inputs: [1, 0])
    let outputs3 = xorNet.currentOutputs()

    xorNet.feedForward(inputs: [1, 1])
    let outputs4 = xorNet.currentOutputs()

    var allOutputs: [Double] = []
    allOutputs.append(contentsOf: outputs1)
    allOutputs.append(contentsOf: outputs2)
    allOutputs.append(contentsOf: outputs3)
    allOutputs.append(contentsOf: outputs4)

    let sum = allOutputs.reduce(0.0, +)
    return Helper.checksumF64(sum)
  }
}
