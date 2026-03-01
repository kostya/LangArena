module neuralnet

import benchmark
import helper
import math

pub struct NeuralNet {
	benchmark.BaseBenchmark
mut:
	xor_net &NeuralNetwork
}

pub fn new_neuralnet() &benchmark.IBenchmark {
	mut bench := &NeuralNet{
		BaseBenchmark: benchmark.new_base_benchmark('Etc::NeuralNet')
		xor_net:       unsafe { nil }
	}
	return bench
}

pub fn (b NeuralNet) name() string {
	return 'Etc::NeuralNet'
}

const input_00 = [0, 0]
const input_01 = [0, 1]
const input_10 = [1, 0]
const input_11 = [1, 1]
const target_0 = [0]
const target_1 = [1]

struct Synapse {
mut:
	weight      f64
	prev_weight f64
	source      &Neuron
	dest        &Neuron
}

@[heap]
struct Neuron {
mut:
	synapses_in    []&Synapse
	synapses_out   []&Synapse
	threshold      f64
	prev_threshold f64
	error          f64
	output         f64
}

const learning_rate = 1.0
const momentum = 0.3

fn new_neuron() &Neuron {
	mut threshold := helper.next_float(1.0) * 2 - 1
	return &Neuron{
		threshold:      threshold
		prev_threshold: threshold
		output:         0.0
		error:          0.0
	}
}

fn (mut n Neuron) calculate_output() {
	mut activation := 0.0
	for synapse in n.synapses_in {
		activation += synapse.weight * synapse.source.output
	}
	activation -= n.threshold
	n.output = 1.0 / (1.0 + math.exp(-activation))
}

fn (n Neuron) derivative() f64 {
	return n.output * (1 - n.output)
}

fn (mut n Neuron) output_train(rate f64, target f64) {
	n.error = (target - n.output) * n.derivative()
	n.update_weights(rate)
}

fn (mut n Neuron) hidden_train(rate f64) {
	mut sum := 0.0
	for synapse in n.synapses_out {
		sum += synapse.prev_weight * synapse.dest.error
	}
	n.error = sum * n.derivative()
	n.update_weights(rate)
}

fn (mut n Neuron) update_weights(rate f64) {
	for mut synapse in n.synapses_in {
		temp_weight := synapse.weight
		synapse.weight += (rate * learning_rate * n.error * synapse.source.output) +
			(momentum * (synapse.weight - synapse.prev_weight))
		synapse.prev_weight = temp_weight
	}

	temp_threshold := n.threshold
	n.threshold += (rate * learning_rate * n.error * -1) +
		(momentum * (n.threshold - n.prev_threshold))
	n.prev_threshold = temp_threshold
}

fn (mut n Neuron) set_output(val f64) {
	n.output = val
}

fn (n Neuron) get_output() f64 {
	return n.output
}

fn (mut n Neuron) add_synapse_in(synapse &Synapse) {
	n.synapses_in << synapse
}

fn (mut n Neuron) add_synapse_out(synapse &Synapse) {
	n.synapses_out << synapse
}

@[heap]
struct NeuralNetwork {
mut:
	input_layer  []&Neuron
	hidden_layer []&Neuron
	output_layer []&Neuron
	synapses     []&Synapse
}

fn new_neural_network(inputs int, hidden int, outputs int) &NeuralNetwork {
	mut net := &NeuralNetwork{}

	for _ in 0 .. inputs {
		net.input_layer << new_neuron()
	}
	for _ in 0 .. hidden {
		net.hidden_layer << new_neuron()
	}
	for _ in 0 .. outputs {
		net.output_layer << new_neuron()
	}

	for mut source in net.input_layer {
		for mut dest in net.hidden_layer {
			mut weight := helper.next_float(1.0) * 2 - 1
			mut synapse := &Synapse{
				weight:      weight
				prev_weight: weight
				source:      source
				dest:        dest
			}
			source.add_synapse_out(synapse)
			dest.add_synapse_in(synapse)
			net.synapses << synapse
		}
	}

	for mut source in net.hidden_layer {
		for mut dest in net.output_layer {
			mut weight := helper.next_float(1.0) * 2 - 1
			mut synapse := &Synapse{
				weight:      weight
				prev_weight: weight
				source:      source
				dest:        dest
			}
			source.add_synapse_out(synapse)
			dest.add_synapse_in(synapse)
			net.synapses << synapse
		}
	}

	return net
}

fn (mut net NeuralNetwork) feed_forward(inputs []int) {
	for i in 0 .. net.input_layer.len {
		mut neuron := net.input_layer[i]
		neuron.set_output(f64(inputs[i]))
	}

	for mut neuron in net.hidden_layer {
		neuron.calculate_output()
	}

	for mut neuron in net.output_layer {
		neuron.calculate_output()
	}
}

fn (mut net NeuralNetwork) train(inputs []int, targets []int) {
	net.feed_forward(inputs)

	for i in 0 .. net.output_layer.len {
		mut neuron := net.output_layer[i]
		neuron.output_train(0.3, f64(targets[i]))
	}

	for mut neuron in net.hidden_layer {
		neuron.hidden_train(0.3)
	}
}

fn (net NeuralNetwork) current_outputs() []f64 {
	mut outputs := []f64{cap: net.output_layer.len}
	for neuron in net.output_layer {
		outputs << neuron.get_output()
	}
	return outputs
}

pub fn (mut n NeuralNet) prepare() {
	n.xor_net = new_neural_network(2, 10, 1)
}

pub fn (mut n NeuralNet) run(iteration_id int) {
	mut net := n.xor_net
	for _ in 0 .. 1000 {
		net.train(input_00, target_0)
		net.train(input_10, target_1)
		net.train(input_01, target_1)
		net.train(input_11, target_0)
	}
}

pub fn (n NeuralNet) checksum() u32 {
	mut net := n.xor_net

	mut sum := 0.0

	net.feed_forward(input_00)
	for v in net.current_outputs() {
		sum += v
	}

	net.feed_forward(input_01)
	for v in net.current_outputs() {
		sum += v
	}

	net.feed_forward(input_10)
	for v in net.current_outputs() {
		sum += v
	}

	net.feed_forward(input_11)
	for v in net.current_outputs() {
		sum += v
	}

	return helper.checksum_f64(sum)
}
