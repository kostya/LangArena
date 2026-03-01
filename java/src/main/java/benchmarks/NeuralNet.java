package benchmarks;

import java.util.*;

public class NeuralNet extends Benchmark {
    private static final double LEARNING_RATE = 1.0;
    private static final double MOMENTUM = 0.3;

    private static final int[] INPUT_00 = {0, 0};
    private static final int[] INPUT_01 = {0, 1};
    private static final int[] INPUT_10 = {1, 0};
    private static final int[] INPUT_11 = {1, 1};
    private static final int[] TARGET_0 = {0};
    private static final int[] TARGET_1 = {1};

    static class Synapse {
        double weight;
        double prevWeight;
        Neuron sourceNeuron;
        Neuron destNeuron;

        Synapse(Neuron sourceNeuron, Neuron destNeuron) {
            this.sourceNeuron = sourceNeuron;
            this.destNeuron = destNeuron;
            this.prevWeight = this.weight = Helper.nextFloat() * 2 - 1;
        }
    }

    static class Neuron {
        double threshold;
        double prevThreshold;
        List<Synapse> synapsesIn = new ArrayList<>();
        List<Synapse> synapsesOut = new ArrayList<>();
        double output;
        double error;

        Neuron() {
            this.prevThreshold = this.threshold = Helper.nextFloat() * 2 - 1;
        }

        void calculateOutput() {
            double activation = 0.0;
            for (Synapse synapse : synapsesIn) {
                activation += synapse.weight * synapse.sourceNeuron.output;
            }
            activation -= threshold;
            output = 1.0 / (1.0 + Math.exp(-activation));
        }

        double derivative() {
            return output * (1 - output);
        }

        void outputTrain(double rate, double target) {
            error = (target - output) * derivative();
            updateWeights(rate);
        }

        void hiddenTrain(double rate) {
            error = 0.0;
            for (Synapse synapse : synapsesOut) {
                error += synapse.prevWeight * synapse.destNeuron.error;
            }
            error *= derivative();
            updateWeights(rate);
        }

        void updateWeights(double rate) {
            for (Synapse synapse : synapsesIn) {
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
    }

    static class NeuralNetwork {
        List<Neuron> inputLayer;
        List<Neuron> hiddenLayer;
        List<Neuron> outputLayer;

        NeuralNetwork(int inputs, int hidden, int outputs) {
            inputLayer = new ArrayList<>();
            hiddenLayer = new ArrayList<>();
            outputLayer = new ArrayList<>();

            for (int i = 0; i < inputs; i++) {
                inputLayer.add(new Neuron());
            }

            for (int i = 0; i < hidden; i++) {
                hiddenLayer.add(new Neuron());
            }

            for (int i = 0; i < outputs; i++) {
                outputLayer.add(new Neuron());
            }

            for (Neuron inputNeuron : inputLayer) {
                for (Neuron hiddenNeuron : hiddenLayer) {
                    Synapse synapse = new Synapse(inputNeuron, hiddenNeuron);
                    inputNeuron.synapsesOut.add(synapse);
                    hiddenNeuron.synapsesIn.add(synapse);
                }
            }

            for (Neuron hiddenNeuron : hiddenLayer) {
                for (Neuron outputNeuron : outputLayer) {
                    Synapse synapse = new Synapse(hiddenNeuron, outputNeuron);
                    hiddenNeuron.synapsesOut.add(synapse);
                    outputNeuron.synapsesIn.add(synapse);
                }
            }
        }

        void train(int[] inputs, int[] targets) {
            feedForward(inputs);

            for (int i = 0; i < outputLayer.size(); i++) {
                outputLayer.get(i).outputTrain(0.3, targets[i]);
            }

            for (Neuron neuron : hiddenLayer) {
                neuron.hiddenTrain(0.3);
            }
        }

        void feedForward(int[] inputs) {
            for (int i = 0; i < inputLayer.size(); i++) {
                inputLayer.get(i).output = inputs[i];
            }

            for (Neuron neuron : hiddenLayer) {
                neuron.calculateOutput();
            }

            for (Neuron neuron : outputLayer) {
                neuron.calculateOutput();
            }
        }

        List<Double> currentOutputs() {
            List<Double> outputs = new ArrayList<>();
            for (Neuron neuron : outputLayer) {
                outputs.add(neuron.output);
            }
            return outputs;
        }
    }

    private List<Double> allOutputs = new ArrayList<>();
    private NeuralNetwork xorNet;

    public NeuralNet() {
        xorNet = new NeuralNetwork(0, 0, 0);
    }

    @Override
    public String name() {
        return "Etc::NeuralNet";
    }

    @Override
    public void prepare() {
        xorNet = new NeuralNetwork(2, 10, 1);
    }

    @Override
    public void run(int iterationId) {
        for (int iter = 0; iter < 1000; iter++) {
            xorNet.train(INPUT_00, TARGET_0);
            xorNet.train(INPUT_10, TARGET_1);
            xorNet.train(INPUT_01, TARGET_1);
            xorNet.train(INPUT_11, TARGET_0);
        }
    }

    @Override
    public long checksum() {
        allOutputs.clear();

        xorNet.feedForward(INPUT_00);
        allOutputs.addAll(xorNet.currentOutputs());

        xorNet.feedForward(INPUT_01);
        allOutputs.addAll(xorNet.currentOutputs());

        xorNet.feedForward(INPUT_10);
        allOutputs.addAll(xorNet.currentOutputs());

        xorNet.feedForward(INPUT_11);
        allOutputs.addAll(xorNet.currentOutputs());

        double sum = 0.0;
        for (Double val : allOutputs) {
            sum += val;
        }

        return Helper.checksumF64(sum);
    }
}