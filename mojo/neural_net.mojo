from std.math import exp
from helper import Helper
from benchmark import Benchmark, Config


comptime NN_LEARNING_RATE: Float64 = 1.0
comptime NN_MOMENTUM: Float64 = 0.3
comptime NN_TRAIN_RATE: Float64 = 0.3


struct _Synapse(Copyable, ImplicitlyCopyable):
    var weight: Float64
    var prev_weight: Float64
    var source_idx: Int
    var dest_idx: Int

    def __init__(out self, source_idx: Int, dest_idx: Int, mut helper: Helper):
        var r = helper.next_float(1.0)
        self.weight = r * 2.0 - 1.0
        self.prev_weight = self.weight
        self.source_idx = source_idx
        self.dest_idx = dest_idx


struct _Neuron(Copyable):
    var threshold: Float64
    var prev_threshold: Float64
    var output: Float64
    var error: Float64
    var synapses_in: List[Int]
    var synapses_out: List[Int]

    def __init__(out self, mut helper: Helper):
        var r = helper.next_float(1.0)
        self.threshold = r * 2.0 - 1.0
        self.prev_threshold = self.threshold
        self.output = 0.0
        self.error = 0.0
        self.synapses_in = List[Int]()
        self.synapses_out = List[Int]()

    def derivative(self) -> Float64:
        return self.output * (1.0 - self.output)


struct _NN(Movable):
    var neurons: List[_Neuron]
    var input_indices: List[Int]
    var hidden_indices: List[Int]
    var output_indices: List[Int]
    var synapses: List[_Synapse]

    def __init__(
        out self, inputs: Int, hidden: Int, outputs: Int, mut helper: Helper
    ):
        var total = inputs + hidden + outputs

        self.neurons = List[_Neuron]()
        for _ in range(total):
            self.neurons.append(_Neuron(helper))

        self.input_indices = List[Int]()
        for i in range(inputs):
            self.input_indices.append(i)

        self.hidden_indices = List[Int]()
        for i in range(hidden):
            self.hidden_indices.append(inputs + i)

        self.output_indices = List[Int]()
        for i in range(outputs):
            self.output_indices.append(inputs + hidden + i)

        self.synapses = List[_Synapse]()
        for i in range(inputs):
            var src_idx = self.input_indices[i]
            for j in range(hidden):
                var dst_idx = self.hidden_indices[j]
                var syn_idx = len(self.synapses)
                self.synapses.append(_Synapse(src_idx, dst_idx, helper))
                self.neurons[src_idx].synapses_out.append(syn_idx)
                self.neurons[dst_idx].synapses_in.append(syn_idx)

        for i in range(hidden):
            var src_idx = self.hidden_indices[i]
            for j in range(outputs):
                var dst_idx = self.output_indices[j]
                var syn_idx = len(self.synapses)
                self.synapses.append(_Synapse(src_idx, dst_idx, helper))
                self.neurons[src_idx].synapses_out.append(syn_idx)
                self.neurons[dst_idx].synapses_in.append(syn_idx)

    def feed_forward(mut self, inputs: List[Float64]):
        for i in range(len(inputs)):
            self.neurons[self.input_indices[i]].output = inputs[i]

        for i in range(len(self.hidden_indices)):
            var neuron_idx = self.hidden_indices[i]
            var activation: Float64 = 0.0
            for syn_idx in self.neurons[neuron_idx].synapses_in:
                var syn = self.synapses[syn_idx]
                activation += syn.weight * self.neurons[syn.source_idx].output
            activation -= self.neurons[neuron_idx].threshold
            self.neurons[neuron_idx].output = 1.0 / (1.0 + exp(-activation))

        for i in range(len(self.output_indices)):
            var neuron_idx = self.output_indices[i]
            var activation: Float64 = 0.0
            for syn_idx in self.neurons[neuron_idx].synapses_in:
                var syn = self.synapses[syn_idx]
                activation += syn.weight * self.neurons[syn.source_idx].output
            activation -= self.neurons[neuron_idx].threshold
            self.neurons[neuron_idx].output = 1.0 / (1.0 + exp(-activation))

    def train(mut self, inputs: List[Float64], targets: List[Float64]):
        self.feed_forward(inputs)

        for i in range(len(self.output_indices)):
            var neuron_idx = self.output_indices[i]
            ref neuron = self.neurons[neuron_idx]
            neuron.error = (targets[i] - neuron.output) * neuron.derivative()
            self._update_weights(neuron_idx)

        for i in range(len(self.hidden_indices)):
            var neuron_idx = self.hidden_indices[i]
            ref neuron = self.neurons[neuron_idx]
            var sum: Float64 = 0.0
            for syn_idx in neuron.synapses_out:
                var syn = self.synapses[syn_idx]
                sum += syn.prev_weight * self.neurons[syn.dest_idx].error
            neuron.error = sum * neuron.derivative()
            self._update_weights(neuron_idx)

    def _update_weights(mut self, neuron_idx: Int):
        ref neuron = self.neurons[neuron_idx]

        for syn_idx in neuron.synapses_in:
            var syn = self.synapses[syn_idx]
            var temp_weight = syn.weight
            var weight_delta = (
                NN_TRAIN_RATE
                * NN_LEARNING_RATE
                * neuron.error
                * self.neurons[syn.source_idx].output
            )
            var momentum_delta = NN_MOMENTUM * (syn.weight - syn.prev_weight)
            syn.weight += weight_delta + momentum_delta
            syn.prev_weight = temp_weight
            self.synapses[syn_idx] = syn

        var temp_threshold = neuron.threshold
        var threshold_delta = (
            NN_TRAIN_RATE * NN_LEARNING_RATE * neuron.error * (-1.0)
        )
        var threshold_momentum_delta = NN_MOMENTUM * (
            neuron.threshold - neuron.prev_threshold
        )
        neuron.threshold += threshold_delta + threshold_momentum_delta
        neuron.prev_threshold = temp_threshold


struct NeuralNet(Benchmark, Movable):
    var nn: _NN
    var input00: List[Float64]
    var input10: List[Float64]
    var input01: List[Float64]
    var input11: List[Float64]
    var target0: List[Float64]
    var target1: List[Float64]

    def __init__(out self, config: Config) raises:
        var dummy_helper = Helper()
        self.nn = _NN(0, 0, 0, dummy_helper)

        self.input00 = List[Float64]()
        self.input00.append(0.0)
        self.input00.append(0.0)

        self.input10 = List[Float64]()
        self.input10.append(1.0)
        self.input10.append(0.0)

        self.input01 = List[Float64]()
        self.input01.append(0.0)
        self.input01.append(1.0)

        self.input11 = List[Float64]()
        self.input11.append(1.0)
        self.input11.append(1.0)

        self.target0 = List[Float64]()
        self.target0.append(0.0)

        self.target1 = List[Float64]()
        self.target1.append(1.0)

    def class_name(self) -> String:
        return "Etc::NeuralNet"

    def prepare(mut self, mut helper: Helper) raises:
        helper.reset()
        self.nn = _NN(2, 10, 1, helper)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        for _ in range(1000):
            self.nn.train(self.input00, self.target0)
            self.nn.train(self.input10, self.target1)
            self.nn.train(self.input01, self.target1)
            self.nn.train(self.input11, self.target0)

    def checksum(mut self) -> UInt32:
        var sum: Float64 = 0.0

        self.nn.feed_forward(self.input00)
        sum += self.nn.neurons[self.nn.output_indices[0]].output

        self.nn.feed_forward(self.input01)
        sum += self.nn.neurons[self.nn.output_indices[0]].output

        self.nn.feed_forward(self.input10)
        sum += self.nn.neurons[self.nn.output_indices[0]].output

        self.nn.feed_forward(self.input11)
        sum += self.nn.neurons[self.nn.output_indices[0]].output

        return Helper.checksum_f64(sum)
