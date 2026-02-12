use super::super::{Benchmark, helper};

#[derive(Clone)]
struct Synapse {
    weight: f64,
    prev_weight: f64,
    source_neuron: usize,
    dest_neuron: usize,
}

impl Synapse {
    fn new(source_neuron: usize, dest_neuron: usize) -> Self {
        let w = helper::next_float(1.0) * 2.0 - 1.0;
        Self {
            weight: w,
            prev_weight: w,
            source_neuron,
            dest_neuron,
        }
    }
}

#[derive(Clone)]
struct Neuron {
    threshold: f64,
    prev_threshold: f64,
    output: f64,
    error: f64,
    synapses_in: Vec<usize>,
    synapses_out: Vec<usize>,
}

impl Neuron {
    const LEARNING_RATE: f64 = 1.0;
    const MOMENTUM: f64 = 0.3;

    fn new() -> Self {
        let t = helper::next_float(1.0) * 2.0 - 1.0;
        Self {
            threshold: t,
            prev_threshold: t,
            output: 0.0,
            error: 0.0,
            synapses_in: Vec::new(),
            synapses_out: Vec::new(),
        }
    }

    fn derivative(&self) -> f64 {
        self.output * (1.0 - self.output)
    }
}

#[derive(Clone)]
struct NeuralNetwork {
    input_layer: Vec<usize>,
    hidden_layer: Vec<usize>,
    output_layer: Vec<usize>,
    neurons: Vec<Neuron>,
    synapses: Vec<Synapse>,
}

impl NeuralNetwork {
    fn new(inputs: usize, hidden: usize, outputs: usize) -> Self {
        let total_neurons = inputs + hidden + outputs;
        let mut neurons = Vec::with_capacity(total_neurons);
        for _ in 0..total_neurons {
            neurons.push(Neuron::new());
        }

        let input_layer: Vec<usize> = (0..inputs).collect();
        let hidden_layer: Vec<usize> = (inputs..inputs + hidden).collect();
        let output_layer: Vec<usize> = (inputs + hidden..inputs + hidden + outputs).collect();

        let mut synapses = Vec::new();

        for &source_idx in &input_layer {
            for &dest_idx in &hidden_layer {
                let synapse_idx = synapses.len();
                synapses.push(Synapse::new(source_idx, dest_idx));
                neurons[source_idx].synapses_out.push(synapse_idx);
                neurons[dest_idx].synapses_in.push(synapse_idx);
            }
        }

        for &source_idx in &hidden_layer {
            for &dest_idx in &output_layer {
                let synapse_idx = synapses.len();
                synapses.push(Synapse::new(source_idx, dest_idx));
                neurons[source_idx].synapses_out.push(synapse_idx);
                neurons[dest_idx].synapses_in.push(synapse_idx);
            }
        }

        Self {
            input_layer,
            hidden_layer,
            output_layer,
            neurons,
            synapses,
        }
    }

    fn train(&mut self, inputs: &[f64], targets: &[f64]) {
        self.feed_forward(inputs);

        const RATE: f64 = 0.3;

        for (i, &target) in targets.iter().enumerate() {
            let neuron_idx = self.output_layer[i];

            let output = self.neurons[neuron_idx].output;
            let derivative = self.neurons[neuron_idx].derivative();
            let error = (target - output) * derivative;
            self.neurons[neuron_idx].error = error;

            let synapses_in = self.neurons[neuron_idx].synapses_in.clone(); 
            for &synapse_idx in &synapses_in {
                let synapse = &mut self.synapses[synapse_idx];
                let source_output = self.neurons[synapse.source_neuron].output;

                let temp_weight = synapse.weight;
                synapse.weight += (RATE * Neuron::LEARNING_RATE * error * source_output)
                               + (Neuron::MOMENTUM * (synapse.weight - synapse.prev_weight));
                synapse.prev_weight = temp_weight;
            }

            let neuron = &mut self.neurons[neuron_idx];
            let temp_threshold = neuron.threshold;
            neuron.threshold += (RATE * Neuron::LEARNING_RATE * error * -1.0)
                             + (Neuron::MOMENTUM * (neuron.threshold - neuron.prev_threshold));
            neuron.prev_threshold = temp_threshold;
        }

        let mut hidden_errors = vec![0.0; self.hidden_layer.len()];

        for (i, &neuron_idx) in self.hidden_layer.iter().enumerate() {
            let neuron = &self.neurons[neuron_idx];
            let mut sum = 0.0;

            for &synapse_idx in &neuron.synapses_out {
                let synapse = &self.synapses[synapse_idx];

                sum += synapse.prev_weight * self.neurons[synapse.dest_neuron].error;
            }

            hidden_errors[i] = sum * neuron.derivative();
        }

        for (i, &neuron_idx) in self.hidden_layer.iter().enumerate() {
            let error = hidden_errors[i];
            self.neurons[neuron_idx].error = error;

            let synapses_in = self.neurons[neuron_idx].synapses_in.clone(); 
            for &synapse_idx in &synapses_in {
                let synapse = &mut self.synapses[synapse_idx];
                let source_output = self.neurons[synapse.source_neuron].output;

                let temp_weight = synapse.weight;
                synapse.weight += (RATE * Neuron::LEARNING_RATE * error * source_output)
                               + (Neuron::MOMENTUM * (synapse.weight - synapse.prev_weight));
                synapse.prev_weight = temp_weight;
            }

            let neuron = &mut self.neurons[neuron_idx];
            let temp_threshold = neuron.threshold;
            neuron.threshold += (RATE * Neuron::LEARNING_RATE * error * -1.0)
                             + (Neuron::MOMENTUM * (neuron.threshold - neuron.prev_threshold));
            neuron.prev_threshold = temp_threshold;
        }
    }

    fn feed_forward(&mut self, inputs: &[f64]) {

        for (i, &input) in inputs.iter().enumerate() {
            let neuron_idx = self.input_layer[i];
            self.neurons[neuron_idx].output = input;
        }

        for &neuron_idx in &self.hidden_layer {
            let mut activation = 0.0;
            let neuron = &self.neurons[neuron_idx];

            for &synapse_idx in &neuron.synapses_in {
                let synapse = &self.synapses[synapse_idx];
                activation += synapse.weight * self.neurons[synapse.source_neuron].output;
            }
            activation -= neuron.threshold;

            let output = 1.0 / (1.0 + (-activation).exp());
            self.neurons[neuron_idx].output = output;
        }

        for &neuron_idx in &self.output_layer {
            let mut activation = 0.0;
            let neuron = &self.neurons[neuron_idx];

            for &synapse_idx in &neuron.synapses_in {
                let synapse = &self.synapses[synapse_idx];
                activation += synapse.weight * self.neurons[synapse.source_neuron].output;
            }
            activation -= neuron.threshold;

            let output = 1.0 / (1.0 + (-activation).exp());
            self.neurons[neuron_idx].output = output;
        }
    }

    fn current_outputs(&self) -> Vec<f64> {
        self.output_layer.iter()
            .map(|&idx| self.neurons[idx].output)
            .collect()
    }
}

pub struct NeuralNet {
    xor_net: NeuralNetwork,
}

impl NeuralNet {
    pub fn new() -> Self {

        Self {
            xor_net: NeuralNetwork::new(0, 0, 0), 
        }
    }
}

impl Benchmark for NeuralNet {
    fn name(&self) -> String {
        "NeuralNet".to_string()
    }

    fn prepare(&mut self) {

        self.xor_net = NeuralNetwork::new(2, 10, 1);
    }

    fn run(&mut self, _iteration_id: i64) {

        self.xor_net.train(&[0.0, 0.0], &[0.0]);
        self.xor_net.train(&[1.0, 0.0], &[1.0]);
        self.xor_net.train(&[0.0, 1.0], &[1.0]);
        self.xor_net.train(&[1.0, 1.0], &[0.0]);
    }

    fn checksum(&self) -> u32 {
        let mut net_copy = self.xor_net.clone();

        net_copy.feed_forward(&[0.0, 0.0]);
        let outputs1 = net_copy.current_outputs();

        net_copy.feed_forward(&[0.0, 1.0]);
        let outputs2 = net_copy.current_outputs();

        net_copy.feed_forward(&[1.0, 0.0]);
        let outputs3 = net_copy.current_outputs();

        net_copy.feed_forward(&[1.0, 1.0]);
        let outputs4 = net_copy.current_outputs();

        let mut all_outputs = Vec::new();
        all_outputs.extend_from_slice(&outputs1);
        all_outputs.extend_from_slice(&outputs2);
        all_outputs.extend_from_slice(&outputs3);
        all_outputs.extend_from_slice(&outputs4);

        let sum: f64 = all_outputs.iter().sum();
        helper::checksum_f64(sum)
    }
}