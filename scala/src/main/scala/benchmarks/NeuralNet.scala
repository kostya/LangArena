package benchmarks

import scala.collection.mutable.ArrayBuffer

class NeuralNet extends Benchmark:
  private val LEARNING_RATE = 1.0
  private val MOMENTUM = 0.3

  private var xorNet: NeuralNetwork = _
  private val allOutputs = ArrayBuffer.empty[Double]

  override def name(): String = "NeuralNet"

  override def prepare(): Unit =
    xorNet = NeuralNetwork(2, 10, 1)

  private class Synapse(
      var weight: Double,
      var prevWeight: Double,
      val sourceNeuron: Neuron,
      val destNeuron: Neuron
  )

  private object Synapse:
    def apply(sourceNeuron: Neuron, destNeuron: Neuron): Synapse =
      val w = Helper.nextFloat() * 2 - 1
      new Synapse(w, w, sourceNeuron, destNeuron)

  private class Neuron:
    var threshold: Double = Helper.nextFloat() * 2 - 1
    var prevThreshold: Double = threshold
    val synapsesIn = ArrayBuffer.empty[Synapse]
    val synapsesOut = ArrayBuffer.empty[Synapse]
    var output: Double = 0.0
    var error: Double = 0.0

    def calculateOutput(): Unit =
      var activation = 0.0
      var i = 0
      while i < synapsesIn.length do
        val synapse = synapsesIn(i)
        activation += synapse.weight * synapse.sourceNeuron.output
        i += 1
      activation -= threshold
      output = 1.0 / (1.0 + math.exp(-activation))

    def derivative(): Double = output * (1 - output)

    def outputTrain(rate: Double, target: Double): Unit =
      error = (target - output) * derivative()
      updateWeights(rate)

    def hiddenTrain(rate: Double): Unit =
      error = 0.0
      var i = 0
      while i < synapsesOut.length do
        val synapse = synapsesOut(i)
        error += synapse.prevWeight * synapse.destNeuron.error
        i += 1
      error *= derivative()
      updateWeights(rate)

    def updateWeights(rate: Double): Unit =
      var i = 0
      while i < synapsesIn.length do
        val synapse = synapsesIn(i)
        val tempWeight = synapse.weight
        synapse.weight += (rate * LEARNING_RATE * error * synapse.sourceNeuron.output) +
          (MOMENTUM * (synapse.weight - synapse.prevWeight))
        synapse.prevWeight = tempWeight
        i += 1

      val tempThreshold = threshold
      threshold += (rate * LEARNING_RATE * error * -1) +
        (MOMENTUM * (threshold - prevThreshold))
      prevThreshold = tempThreshold

  private class NeuralNetwork(inputs: Int, hidden: Int, outputs: Int):
    val inputLayer = ArrayBuffer.fill(inputs)(Neuron())
    val hiddenLayer = ArrayBuffer.fill(hidden)(Neuron())
    val outputLayer = ArrayBuffer.fill(outputs)(Neuron())

    var i = 0
    while i < inputLayer.length do
      var j = 0
      while j < hiddenLayer.length do
        val synapse = Synapse(inputLayer(i), hiddenLayer(j))
        inputLayer(i).synapsesOut += synapse
        hiddenLayer(j).synapsesIn += synapse
        j += 1
      i += 1

    i = 0
    while i < hiddenLayer.length do
      var j = 0
      while j < outputLayer.length do
        val synapse = Synapse(hiddenLayer(i), outputLayer(j))
        hiddenLayer(i).synapsesOut += synapse
        outputLayer(j).synapsesIn += synapse
        j += 1
      i += 1

    def train(inputs: Array[Int], targets: Array[Int]): Unit =
      feedForward(inputs)

      var i = 0
      while i < outputLayer.length do
        outputLayer(i).outputTrain(0.3, targets(i))
        i += 1

      i = 0
      while i < hiddenLayer.length do
        hiddenLayer(i).hiddenTrain(0.3)
        i += 1

    def feedForward(inputs: Array[Int]): Unit =
      var i = 0
      while i < inputLayer.length do
        inputLayer(i).output = inputs(i).toDouble
        i += 1

      i = 0
      while i < hiddenLayer.length do
        hiddenLayer(i).calculateOutput()
        i += 1

      i = 0
      while i < outputLayer.length do
        outputLayer(i).calculateOutput()
        i += 1

    def currentOutputs(): ArrayBuffer[Double] =
      val outputs = ArrayBuffer.empty[Double]
      var i = 0
      while i < outputLayer.length do
        outputs += outputLayer(i).output
        i += 1
      outputs

  override def run(iterationId: Int): Unit =
    xorNet.train(Array(0, 0), Array(0))
    xorNet.train(Array(1, 0), Array(1))
    xorNet.train(Array(0, 1), Array(1))
    xorNet.train(Array(1, 1), Array(0))

  override def checksum(): Long =
    allOutputs.clear()

    xorNet.feedForward(Array(0, 0))
    allOutputs ++= xorNet.currentOutputs()

    xorNet.feedForward(Array(0, 1))
    allOutputs ++= xorNet.currentOutputs()

    xorNet.feedForward(Array(1, 0))
    allOutputs ++= xorNet.currentOutputs()

    xorNet.feedForward(Array(1, 1))
    allOutputs ++= xorNet.currentOutputs()

    var sum = 0.0
    var i = 0
    while i < allOutputs.length do
      sum += allOutputs(i)
      i += 1

    Helper.checksumF64(sum)
