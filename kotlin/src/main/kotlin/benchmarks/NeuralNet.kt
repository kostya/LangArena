package benchmarks

import Benchmark
import kotlin.math.exp

class NeuralNet : Benchmark() {
    companion object {
        private const val LEARNING_RATE = 1.0
        private const val MOMENTUM = 0.3

        private val INPUT_00 = listOf(0, 0)
        private val INPUT_01 = listOf(0, 1)
        private val INPUT_10 = listOf(1, 0)
        private val INPUT_11 = listOf(1, 1)
        private val TARGET_0 = listOf(0)
        private val TARGET_1 = listOf(1)
    }

    private class Synapse(
        val sourceNeuron: Neuron,
        val destNeuron: Neuron,
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

        fun outputTrain(
            rate: Double,
            target: Double,
        ) {
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

    private class NeuralNetwork(
        inputs: Int,
        hidden: Int,
        outputs: Int,
    ) {
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

        fun train(
            inputs: List<Int>,
            targets: List<Int>,
        ) {
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

        fun currentOutputs(): List<Double> = outputLayer.map { it.output }
    }

    private lateinit var xorNet: NeuralNetwork

    override fun prepare() {
        xorNet = NeuralNetwork(2, 10, 1)
    }

    override fun run(iterationId: Int) {
        for (i in 0 until 1000) {
            xorNet.train(INPUT_00, TARGET_0)
            xorNet.train(INPUT_10, TARGET_1)
            xorNet.train(INPUT_01, TARGET_1)
            xorNet.train(INPUT_11, TARGET_0)
        }
    }

    override fun checksum(): UInt {
        val allOutputs = mutableListOf<Double>()

        xorNet.feedForward(INPUT_00)
        allOutputs.addAll(xorNet.currentOutputs())

        xorNet.feedForward(INPUT_01)
        allOutputs.addAll(xorNet.currentOutputs())

        xorNet.feedForward(INPUT_10)
        allOutputs.addAll(xorNet.currentOutputs())

        xorNet.feedForward(INPUT_11)
        allOutputs.addAll(xorNet.currentOutputs())

        val sum = allOutputs.sum()
        return Helper.checksumF64(sum)
    }

    override fun name(): String = "Etc::NeuralNet"
}
