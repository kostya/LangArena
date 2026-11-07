module neural_net;

import benchmark;
import helper;
import std::io;
import std::math;
import std::collections::list;

const LEARNING_RATE = 1.0;
const MOMENTUM      = 0.3;
const TRAIN_RATE    = 0.3;

const double[2] INPUTS_00 = { 0, 0 };
const double[2] INPUTS_01 = { 0, 1 };
const double[2] INPUTS_10 = { 1, 0 };
const double[2] INPUTS_11 = { 1, 1 };
const double[1] TARGETS_0 = { 0 };
const double[1] TARGETS_1 = { 1 };

struct NeuralNetSynapse
{
	double weight;
	double prev_weight;
	NeuralNetNeuron* source_neuron;
	NeuralNetNeuron* dest_neuron;
}

struct NeuralNetNeuron
{
	List{NeuralNetSynapse*} synapses_in;
	List{NeuralNetSynapse*} synapses_out;

	double threshold;
	double prev_threshold;
	double error;
	double output;
}

fn void neuron_update_weights(NeuralNetNeuron* neuron)
{
	for (int i = 0; i < neuron.synapses_in.len(); i++)
	{
		NeuralNetSynapse* synapse = neuron.synapses_in[i];
		double temp_weight        = synapse.weight;
		synapse.weight += (TRAIN_RATE * LEARNING_RATE * neuron.error * synapse.source_neuron.output)
			+ (MOMENTUM * (synapse.weight - synapse.prev_weight));
		synapse.prev_weight = temp_weight;
	}

	double temp_threshold = neuron.threshold;
	neuron.threshold += (TRAIN_RATE * LEARNING_RATE * neuron.error * -1.0)
		+ (MOMENTUM * (neuron.threshold - neuron.prev_threshold));
	neuron.prev_threshold = temp_threshold;
}

fn void neuron_init(NeuralNetNeuron* neuron)
{
	double r = helper::helper_next_float(1.0);
	neuron.threshold = r * 2.0 - 1.0;
	neuron.prev_threshold = neuron.threshold;
	neuron.output = 0.0;
	neuron.error = 0.0;
	neuron.synapses_in.init(mem);
	neuron.synapses_out.init(mem);
}

fn void neuron_add_synapse_in(NeuralNetNeuron* neuron, NeuralNetSynapse* synapse)
{
	neuron.synapses_in.push(synapse);
}

fn void neuron_add_synapse_out(NeuralNetNeuron* neuron, NeuralNetSynapse* synapse)
{
	neuron.synapses_out.push(synapse);
}

fn double neuron_derivative(NeuralNetNeuron* neuron)
{
	return neuron.output * (1.0 - neuron.output);
}

fn void neuron_calculate_output(NeuralNetNeuron* neuron)
{
	double activation = 0.0;
	for (int i = 0; i < neuron.synapses_in.len(); i++)
	{
		NeuralNetSynapse* synapse = neuron.synapses_in[i];
		activation += synapse.weight * synapse.source_neuron.output;
	}
	activation -= neuron.threshold;
	neuron.output = 1.0 / (1.0 + math::exp(-activation));
}

fn void neuron_output_train(NeuralNetNeuron* neuron, double target)
{
	neuron.error = (target - neuron.output) * neuron_derivative(neuron);
	neuron_update_weights(neuron);
}

fn void neuron_hidden_train(NeuralNetNeuron* neuron)
{
	double sum = 0.0;
	for (int i = 0; i < neuron.synapses_out.len(); i++)
	{
		NeuralNetSynapse* synapse = neuron.synapses_out[i];
		sum += synapse.prev_weight * synapse.dest_neuron.error;
	}
	neuron.error = sum * neuron_derivative(neuron);
	neuron_update_weights(neuron);
}

struct NeuralNetwork
{
	NeuralNetNeuron* neurons;
	int total_neurons;

	int* input_layer;
	int input_count;
	int* hidden_layer;
	int hidden_count;
	int* output_layer;
	int output_count;

	NeuralNetSynapse* synapses;
	int synapse_count;
	int synapse_capacity;
}

fn NeuralNetwork* network_new(int inputs, int hidden, int outputs)
{
	NeuralNetwork* net = mem::new(NeuralNetwork);

	net.total_neurons = inputs + hidden + outputs;
	net.neurons = mem::new_array(NeuralNetNeuron, (usz)net.total_neurons);

	for (int i = 0; i < net.total_neurons; i++)
	{
		neuron_init(&net.neurons[i]);
	}

	net.input_count = inputs;
	net.hidden_count = hidden;
	net.output_count = outputs;

	net.input_layer = mem::new_array(int, (usz)inputs);
	net.hidden_layer = mem::new_array(int, (usz)hidden);
	net.output_layer = mem::new_array(int, (usz)outputs);

	for (int i = 0; i < inputs; i++)
	{
		net.input_layer[i] = i;
	}
	for (int i = 0; i < hidden; i++)
	{
		net.hidden_layer[i] = inputs + i;
	}
	for (int i = 0; i < outputs; i++)
	{
		net.output_layer[i] = inputs + hidden + i;
	}

	net.synapse_count = 0;
	net.synapse_capacity = inputs * hidden + hidden * outputs;
	net.synapses = mem::new_array(NeuralNetSynapse, (usz)net.synapse_capacity);

	for (int i = 0; i < inputs; i++)
	{
		NeuralNetNeuron* source = &net.neurons[net.input_layer[i]];
		for (int j = 0; j < hidden; j++)
		{
			NeuralNetNeuron* dest     = &net.neurons[net.hidden_layer[j]];
			NeuralNetSynapse* synapse = &net.synapses[net.synapse_count++];

			double r = helper::helper_next_float(1.0);
			synapse.weight = r * 2.0 - 1.0;
			synapse.prev_weight = synapse.weight;
			synapse.source_neuron = source;
			synapse.dest_neuron = dest;

			neuron_add_synapse_out(source, synapse);
			neuron_add_synapse_in(dest, synapse);
		}
	}

	for (int i = 0; i < hidden; i++)
	{
		NeuralNetNeuron* source = &net.neurons[net.hidden_layer[i]];
		for (int j = 0; j < outputs; j++)
		{
			NeuralNetNeuron* dest     = &net.neurons[net.output_layer[j]];
			NeuralNetSynapse* synapse = &net.synapses[net.synapse_count++];

			double r = helper::helper_next_float(1.0);
			synapse.weight = r * 2.0 - 1.0;
			synapse.prev_weight = synapse.weight;
			synapse.source_neuron = source;
			synapse.dest_neuron = dest;

			neuron_add_synapse_out(source, synapse);
			neuron_add_synapse_in(dest, synapse);
		}
	}

	return net;
}

fn void network_free(NeuralNetwork* net)
{
	if (!net) return;

	for (int i = 0; i < net.total_neurons; i++)
	{
		net.neurons[i].synapses_in.free();
		net.neurons[i].synapses_out.free();
	}

	free(net.neurons);
	free(net.input_layer);
	free(net.hidden_layer);
	free(net.output_layer);
	free(net.synapses);
	free(net);
}

fn void network_train(NeuralNetwork* net, double* inputs, double* targets)
{
	for (int i = 0; i < net.input_count; i++)
	{
		net.neurons[net.input_layer[i]].output = inputs[i];
	}

	for (int i = 0; i < net.hidden_count; i++)
	{
		neuron_calculate_output(&net.neurons[net.hidden_layer[i]]);
	}

	for (int i = 0; i < net.output_count; i++)
	{
		neuron_calculate_output(&net.neurons[net.output_layer[i]]);
	}

	for (int i = 0; i < net.output_count; i++)
	{
		neuron_output_train(&net.neurons[net.output_layer[i]], targets[i]);
	}

	for (int i = 0; i < net.hidden_count; i++)
	{
		neuron_hidden_train(&net.neurons[net.hidden_layer[i]]);
	}
}

fn void network_feed_forward(NeuralNetwork* net, double* inputs)
{
	for (int i = 0; i < net.input_count; i++)
	{
		net.neurons[net.input_layer[i]].output = inputs[i];
	}

	for (int i = 0; i < net.hidden_count; i++)
	{
		neuron_calculate_output(&net.neurons[net.hidden_layer[i]]);
	}

	for (int i = 0; i < net.output_count; i++)
	{
		neuron_calculate_output(&net.neurons[net.output_layer[i]]);
	}
}

fn double network_get_output(NeuralNetwork* net)
{
	return net.neurons[net.output_layer[0]].output;
}

struct NeuralNetData
{
	uint result_val;
	double sum_outputs;
	NeuralNetwork* xor_net;
}

fn void neural_net_prepare(Benchmark* self)
{
	NeuralNetData* data = (NeuralNetData*)self.data;

	network_free(data.xor_net);
	helper::helper_reset();

	data.xor_net = network_new(2, 10, 1);
}

fn void neural_net_run(Benchmark* self, int iteration_id)
{
	NeuralNetData* data = (NeuralNetData*)self.data;

	for (int iter = 0; iter < 1000; iter++)
	{
		network_train(data.xor_net, (double*)&INPUTS_00[0], (double*)&TARGETS_0[0]);
		network_train(data.xor_net, (double*)&INPUTS_10[0], (double*)&TARGETS_1[0]);
		network_train(data.xor_net, (double*)&INPUTS_01[0], (double*)&TARGETS_1[0]);
		network_train(data.xor_net, (double*)&INPUTS_11[0], (double*)&TARGETS_0[0]);
	}
}

fn uint neural_net_checksum(Benchmark* self)
{
	NeuralNetData* data = (NeuralNetData*)self.data;
	if (!data.xor_net) return 0;

	double sum = 0.0;

	network_feed_forward(data.xor_net, (double*)&INPUTS_00[0]);
	sum += network_get_output(data.xor_net);

	network_feed_forward(data.xor_net, (double*)&INPUTS_01[0]);
	sum += network_get_output(data.xor_net);

	network_feed_forward(data.xor_net, (double*)&INPUTS_10[0]);
	sum += network_get_output(data.xor_net);

	network_feed_forward(data.xor_net, (double*)&INPUTS_11[0]);
	sum += network_get_output(data.xor_net);

	data.sum_outputs = sum;
	return helper::helper_checksum_f64(sum);
}

fn void neural_net_cleanup(Benchmark* self)
{
	NeuralNetData* data = (NeuralNetData*)self.data;
	network_free(data.xor_net);
	data.xor_net = null;
}

fn Benchmark* neural_net_create() @cname("NeuralNet_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Etc::NeuralNet");

	NeuralNetData* data = mem::new(NeuralNetData);

	bench.data = data;
	bench.prepare = (PrepareFn)&neural_net_prepare;
	bench.run = (RunFn)&neural_net_run;
	bench.checksum = (ChecksumFn)&neural_net_checksum;
	bench.cleanup = (CleanupFn)&neural_net_cleanup;

	return bench;
}