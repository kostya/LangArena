package benchmarks

import Benchmark
import kotlin.math.exp

class NeuralNet : Benchmark() {
    companion object {
        private const val LEARNING_RATE = 1.0
        private const val MOMENTUM = 0.3
    }

    private class Synapse(
        val sourceNeuron: Neuron,
        val destNeuron: Neuron
    ) {
        var weight: Double = Helper.nextFloat() * 2 - 1
        var prevWeight: Double = weight
    }

    private class Neuron {
        var threshold: Double = Helper.nextFloat() * 2 - 1
        var prevThreshold: Double = threshold
        val synapsesIn = mutableListOf<Synapse>()
        val synapsesOut = mutableListOf<Synapse>()
        var output: Double = 0.0
        var error: Double = 0.0

        fun calculateOutput() {
            var activation = 0.0
            for (synapse in synapsesIn) {
                activation += synapse.weight * synapse.sourceNeuron.output
            }
            activation -= threshold
            output = 1.0 / (1.0 + exp(-activation))
        }

        fun derivative(): Double = output * (1 - output)

        fun outputTrain(rate: Double, target: Double) {
            error = (target - output) * derivative()
            updateWeights(rate)
        }

        fun hiddenTrain(rate: Double) {
            error = synapsesOut.sumOf { synapse ->
                synapse.prevWeight * synapse.destNeuron.error
            } * derivative()
            updateWeights(rate)
        }

        fun updateWeights(rate: Double) {
            for (synapse in synapsesIn) {
                val tempWeight = synapse.weight
                synapse.weight += (rate * LEARNING_RATE * error * synapse.sourceNeuron.output) +
                                 (MOMENTUM * (synapse.weight - synapse.prevWeight))
                synapse.prevWeight = tempWeight
            }

            val tempThreshold = threshold
            threshold += (rate * LEARNING_RATE * error * -1) +
                        (MOMENTUM * (threshold - prevThreshold))
            prevThreshold = tempThreshold
        }
    }

    private class NeuralNetwork(inputs: Int, hidden: Int, outputs: Int) {
        private val inputLayer = List(inputs) { Neuron() }
        private val hiddenLayer = List(hidden) { Neuron() }
        private val outputLayer = List(outputs) { Neuron() }

        init {

            for (input in inputLayer) {
                for (hidden in hiddenLayer) {
                    val synapse = Synapse(input, hidden)
                    input.synapsesOut.add(synapse)
                    hidden.synapsesIn.add(synapse)
                }
            }

            for (hidden in hiddenLayer) {
                for (output in outputLayer) {
                    val synapse = Synapse(hidden, output)
                    hidden.synapsesOut.add(synapse)
                    output.synapsesIn.add(synapse)
                }
            }
        }

        fun train(inputs: List<Int>, targets: List<Int>) {
            feedForward(inputs)

            for ((neuron, target) in outputLayer.zip(targets)) {
                neuron.outputTrain(0.3, target.toDouble())
            }

            for (neuron in hiddenLayer) {
                neuron.hiddenTrain(0.3)
            }
        }

        fun feedForward(inputs: List<Int>) {
            for ((neuron, input) in inputLayer.zip(inputs)) {
                neuron.output = input.toDouble()
            }

            for (neuron in hiddenLayer) {
                neuron.calculateOutput()
            }

            for (neuron in outputLayer) {
                neuron.calculateOutput()
            }
        }

        fun currentOutputs(): List<Double> {
            return outputLayer.map { it.output }
        }
    }

    private lateinit var xorNet: NeuralNetwork
    private val res = mutableListOf<Double>()

    init {
        xorNet = NeuralNetwork(0, 0, 0)
    }

    override fun prepare() {
        xorNet = NeuralNetwork(2, 10, 1)
    }

    override fun run(iterationId: Int) {
        xorNet.train(listOf(0, 0), listOf(0))
        xorNet.train(listOf(1, 0), listOf(1))
        xorNet.train(listOf(0, 1), listOf(1))
        xorNet.train(listOf(1, 1), listOf(0))
    }

    override fun checksum(): UInt {
        xorNet.feedForward(listOf(0, 0))
        val outputs1 = xorNet.currentOutputs()

        xorNet.feedForward(listOf(0, 1))
        val outputs2 = xorNet.currentOutputs()

        xorNet.feedForward(listOf(1, 0))
        val outputs3 = xorNet.currentOutputs()

        xorNet.feedForward(listOf(1, 1))
        val outputs4 = xorNet.currentOutputs()

        val allOutputs = mutableListOf<Double>()
        allOutputs.addAll(outputs1)
        allOutputs.addAll(outputs2)
        allOutputs.addAll(outputs3)
        allOutputs.addAll(outputs4)

        val sum = allOutputs.sum()
        return Helper.checksumF64(sum)
    }

    override fun name(): String = "NeuralNet"
}