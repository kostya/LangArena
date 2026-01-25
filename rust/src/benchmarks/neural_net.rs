use super::super::{Benchmark, INPUT, helper};

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
}

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
        
        // Input to hidden connections
        for &source_idx in &input_layer {
            for &dest_idx in &hidden_layer {
                let synapse_idx = synapses.len();
                synapses.push(Synapse::new(source_idx, dest_idx));
                neurons[source_idx].synapses_out.push(synapse_idx);
                neurons[dest_idx].synapses_in.push(synapse_idx);
            }
        }
        
        // Hidden to output connections
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
        
        // Сначала вычисляем ошибки для всех нейронов
        for (i, &target) in targets.iter().enumerate() {
            let neuron_idx = self.output_layer[i];
            let neurons_slice = self.neurons.as_slice();
            let error = (target - neurons_slice[neuron_idx].output) * neurons_slice[neuron_idx].derivative();
            self.neurons[neuron_idx].error = error;
        }
        
        for &neuron_idx in &self.hidden_layer {
            let mut sum = 0.0;
            for &synapse_idx in &self.neurons[neuron_idx].synapses_out {
                let synapse = &self.synapses[synapse_idx];
                sum += synapse.weight * self.neurons[synapse.dest_neuron].error;
            }
            self.neurons[neuron_idx].error = sum * self.neurons[neuron_idx].derivative();
        }
        
        // Затем обновляем веса
        for (i, &neuron_idx) in self.output_layer.iter().enumerate() {
            let _target = targets[i]; // Переменная не используется, но нужна для индексации
            let error = self.neurons[neuron_idx].error;
            
            for &synapse_idx in &self.neurons[neuron_idx].synapses_in {
                let synapse = &mut self.synapses[synapse_idx];
                let temp_weight = synapse.weight;
                let source_output = self.neurons[synapse.source_neuron].output;
                synapse.weight += (0.3 * Neuron::LEARNING_RATE * error * source_output) 
                    + (Neuron::MOMENTUM * (synapse.weight - synapse.prev_weight));
                synapse.prev_weight = temp_weight;
            }
            
            let temp_threshold = self.neurons[neuron_idx].threshold;
            self.neurons[neuron_idx].threshold += (0.3 * Neuron::LEARNING_RATE * error * -1.0)
                + (Neuron::MOMENTUM * (self.neurons[neuron_idx].threshold - self.neurons[neuron_idx].prev_threshold));
            self.neurons[neuron_idx].prev_threshold = temp_threshold;
        }
        
        for &neuron_idx in &self.hidden_layer {
            let error = self.neurons[neuron_idx].error;
            
            for &synapse_idx in &self.neurons[neuron_idx].synapses_in {
                let synapse = &mut self.synapses[synapse_idx];
                let temp_weight = synapse.weight;
                let source_output = self.neurons[synapse.source_neuron].output;
                synapse.weight += (0.3 * Neuron::LEARNING_RATE * error * source_output) 
                    + (Neuron::MOMENTUM * (synapse.weight - synapse.prev_weight));
                synapse.prev_weight = temp_weight;
            }
            
            let temp_threshold = self.neurons[neuron_idx].threshold;
            self.neurons[neuron_idx].threshold += (0.3 * Neuron::LEARNING_RATE * error * -1.0)
                + (Neuron::MOMENTUM * (self.neurons[neuron_idx].threshold - self.neurons[neuron_idx].prev_threshold));
            self.neurons[neuron_idx].prev_threshold = temp_threshold;
        }
    }
    
    fn feed_forward(&mut self, inputs: &[f64]) {
        for (i, &input) in inputs.iter().enumerate() {
            let neuron_idx = self.input_layer[i];
            self.neurons[neuron_idx].output = input;
        }
        
        for &neuron_idx in &self.hidden_layer {
            let mut activation = 0.0;
            for &synapse_idx in &self.neurons[neuron_idx].synapses_in {
                let synapse = &self.synapses[synapse_idx];
                let source = &self.neurons[synapse.source_neuron];
                activation += synapse.weight * source.output;
            }
            activation -= self.neurons[neuron_idx].threshold;
            self.neurons[neuron_idx].output = 1.0 / (1.0 + (-activation).exp());
        }
        
        for &neuron_idx in &self.output_layer {
            let mut activation = 0.0;
            for &synapse_idx in &self.neurons[neuron_idx].synapses_in {
                let synapse = &self.synapses[synapse_idx];
                let source = &self.neurons[synapse.source_neuron];
                activation += synapse.weight * source.output;
            }
            activation -= self.neurons[neuron_idx].threshold;
            self.neurons[neuron_idx].output = 1.0 / (1.0 + (-activation).exp());
        }
    }
    
    fn current_outputs(&self) -> Vec<f64> {
        self.output_layer.iter()
            .map(|&idx| self.neurons[idx].output)
            .collect()
    }
}

pub struct NeuralNet {
    n: i32,
    result: Vec<f64>,
}

impl NeuralNet {
    pub fn new() -> Self {
        let name = "NeuralNet".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            result: Vec::new(),
        }
    }
}

impl Benchmark for NeuralNet {
    fn name(&self) -> String {
        "NeuralNet".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let mut xor = NeuralNetwork::new(2, 10, 1);
        
        for _ in 0..self.n {
            xor.train(&[0.0, 0.0], &[0.0]);
            xor.train(&[1.0, 0.0], &[1.0]);
            xor.train(&[0.0, 1.0], &[1.0]);
            xor.train(&[1.0, 1.0], &[0.0]);
        }
        
        let test_cases = [
            [0.0, 0.0],
            [0.0, 1.0],
            [1.0, 0.0],
            [1.0, 1.0],
        ];
        
        for inputs in test_cases {
            xor.feed_forward(&inputs);
            self.result.extend_from_slice(&xor.current_outputs());
        }
    }
    
    fn result(&self) -> i64 {
        let sum: f64 = self.result.iter().sum();
        helper::checksum_f64(sum) as i64
    }
}

// Вспомогательные методы для Neuron (добавляем в impl Neuron)
impl Neuron {
    fn derivative(&self) -> f64 {
        self.output * (1.0 - self.output)
    }
}