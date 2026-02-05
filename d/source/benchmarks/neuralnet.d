module benchmarks.neuralnet;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.random;
import benchmark;
import helper;

class Neuron {
    enum LEARNING_RATE = 1.0;
    enum MOMENTUM = 0.3;

    Synapse[] synapsesIn;
    Synapse[] synapsesOut;
    double threshold;
    double prevThreshold;
    double error;
    double output;

    this() {
        threshold = Helper.nextFloat() * 2 - 1;
        prevThreshold = threshold;
        output = 0.0;
        error = 0.0;
    }

    void calculateOutput() {
        double activation = 0.0;
        foreach (ref synapse; synapsesIn) {
            activation += synapse.weight * synapse.sourceNeuron.output;
        }
        activation -= threshold;
        output = 1.0 / (1.0 + exp(-activation));
    }

    double derivative() const {
        return output * (1 - output);
    }

    void outputTrain(double rate, double target) {
        error = (target - output) * derivative();
        updateWeights(rate);
    }

    void hiddenTrain(double rate) {
        double sum = 0.0;
        foreach (ref synapse; synapsesOut) {
            sum += synapse.prevWeight * synapse.destNeuron.error;
        }
        error = sum * derivative();
        updateWeights(rate);
    }

    void updateWeights(double rate) {
        foreach (ref synapse; synapsesIn) {
            double tempWeight = synapse.weight;
            synapse.weight += (rate * LEARNING_RATE * error * synapse.sourceNeuron.output) +
                            (MOMENTUM * (synapse.weight - synapse.prevWeight));
            synapse.prevWeight = tempWeight;
        }

        double tempThreshold = threshold;
        threshold += (rate * LEARNING_RATE * error * -1) +
                   (MOMENTUM * (threshold - prevThreshold));
        prevThreshold = tempThreshold;
    }

    void addSynapseIn(ref Synapse synapse) { synapsesIn ~= synapse; }
    void addSynapseOut(ref Synapse synapse) { synapsesOut ~= synapse; }
    void setOutput(double val) { output = val; }
    double getOutput() const { return output; }
}

class Synapse {
    double weight;
    double prevWeight;
    Neuron sourceNeuron;
    Neuron destNeuron;

    this(Neuron source, Neuron dest) {
        sourceNeuron = source;
        destNeuron = dest;
        weight = Helper.nextFloat() * 2 - 1;
        prevWeight = weight;
    }
}

class NeuralNet : Benchmark {
    class NeuralNetwork {
        Neuron[] inputLayer;
        Neuron[] hiddenLayer;
        Neuron[] outputLayer;
        Synapse[] synapses;

        this(int inputs, int hidden, int outputs) {
            inputLayer.length = inputs;
            hiddenLayer.length = hidden;
            outputLayer.length = outputs;

            foreach (i; 0 .. inputs) {
                inputLayer[i] = new Neuron();
            }

            foreach (i; 0 .. hidden) {
                hiddenLayer[i] = new Neuron();
            }

            foreach (i; 0 .. outputs) {
                outputLayer[i] = new Neuron();
            }

            foreach (i; 0 .. inputs) {
                foreach (j; 0 .. hidden) {
                    auto synapse = new Synapse(inputLayer[i], hiddenLayer[j]);
                    inputLayer[i].addSynapseOut(synapse);
                    hiddenLayer[j].addSynapseIn(synapse);
                    synapses ~= synapse;
                }
            }

            foreach (i; 0 .. hidden) {
                foreach (j; 0 .. outputs) {
                    auto synapse = new Synapse(hiddenLayer[i], outputLayer[j]);
                    hiddenLayer[i].addSynapseOut(synapse);
                    outputLayer[j].addSynapseIn(synapse);
                    synapses ~= synapse;
                }
            }
        }

        void train(double[] inputs, double[] targets) {
            feedForward(inputs);

            foreach (i, ref neuron; outputLayer) {
                neuron.outputTrain(0.3, targets[i]);
            }

            foreach (ref neuron; hiddenLayer) {
                neuron.hiddenTrain(0.3);
            }
        }

        void feedForward(double[] inputs) {
            foreach (i, ref neuron; inputLayer) {
                neuron.setOutput(inputs[i]);
            }

            foreach (ref neuron; hiddenLayer) {
                neuron.calculateOutput();
            }

            foreach (ref neuron; outputLayer) {
                neuron.calculateOutput();
            }
        }

        double[] currentOutputs() {
            double[] outputs = new double[outputLayer.length];
            foreach (i, ref neuron; outputLayer) {
                outputs[i] = neuron.getOutput();
            }
            return outputs;
        }
    }

protected:
    NeuralNetwork xorNet;
    override string className() const { return "NeuralNet"; }

public:
    this() {
        xorNet = new NeuralNetwork(0, 0, 0);
    }

    override void prepare() {
        xorNet = new NeuralNetwork(2, 10, 1);
    }

    override void run(int iterationId) {
        xorNet.train([0.0, 0.0], [0.0]);
        xorNet.train([1.0, 0.0], [1.0]);
        xorNet.train([0.0, 1.0], [1.0]);
        xorNet.train([1.0, 1.0], [0.0]);
    }

    override uint checksum() {
        xorNet.feedForward([0.0, 0.0]);
        auto outputs1 = xorNet.currentOutputs();

        xorNet.feedForward([0.0, 1.0]);
        auto outputs2 = xorNet.currentOutputs();

        xorNet.feedForward([1.0, 0.0]);
        auto outputs3 = xorNet.currentOutputs();

        xorNet.feedForward([1.0, 1.0]);
        auto outputs4 = xorNet.currentOutputs();

        double sum = 0.0;
        foreach (v; outputs1) sum += v;
        foreach (v; outputs2) sum += v;
        foreach (v; outputs3) sum += v;
        foreach (v; outputs4) sum += v;

        return Helper.checksumF64(sum);
    }
}