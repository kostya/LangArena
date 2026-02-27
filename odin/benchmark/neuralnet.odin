package benchmark

import "core:math"

INPUT_00 := [2]f64{0.0, 0.0}
INPUT_01 := [2]f64{0.0, 1.0}
INPUT_10 := [2]f64{1.0, 0.0}
INPUT_11 := [2]f64{1.0, 1.0}
TARGET_0 := [1]f64{0.0}
TARGET_1 := [1]f64{1.0}

Neuron :: struct {
    synapses_in: [dynamic]^Synapse,
    synapses_out: [dynamic]^Synapse,
    threshold: f64,
    prev_threshold: f64,
    error: f64,
    output: f64,
}

Synapse :: struct {
    weight: f64,
    prev_weight: f64,
    source_neuron: ^Neuron,
    dest_neuron: ^Neuron,
}

LEARNING_RATE :: 1.0
MOMENTUM :: 0.3

create_neuron :: proc() -> ^Neuron {
    n := new(Neuron)
    n.threshold = next_float() * 2.0 - 1.0
    n.prev_threshold = n.threshold
    n.output = 0.0
    n.error = 0.0
    return n
}

destroy_neuron :: proc(n: ^Neuron) {
    if n == nil {
        return
    }
    delete(n.synapses_in)
    delete(n.synapses_out)
    free(n)
}

calculate_output :: proc(n: ^Neuron) {
    activation: f64 = 0.0
    for synapse in n.synapses_in {
        activation += synapse.weight * synapse.source_neuron.output
    }
    activation -= n.threshold
    n.output = 1.0 / (1.0 + math.exp(-activation))
}

derivative :: proc(n: ^Neuron) -> f64 {
    return n.output * (1.0 - n.output)
}

output_train :: proc(n: ^Neuron, rate, target: f64) {
    n.error = (target - n.output) * derivative(n)
    update_weights(n, rate)
}

hidden_train :: proc(n: ^Neuron, rate: f64) {
    sum: f64 = 0.0
    for synapse in n.synapses_out {
        sum += synapse.prev_weight * synapse.dest_neuron.error
    }
    n.error = sum * derivative(n)
    update_weights(n, rate)
}

update_weights :: proc(n: ^Neuron, rate: f64) {
    for synapse in n.synapses_in {
        temp_weight := synapse.weight
        synapse.weight += (rate * LEARNING_RATE * n.error * synapse.source_neuron.output) +
                         (MOMENTUM * (synapse.weight - synapse.prev_weight))
        synapse.prev_weight = temp_weight
    }

    temp_threshold := n.threshold
    n.threshold += (rate * LEARNING_RATE * n.error * -1.0) +
                  (MOMENTUM * (n.threshold - n.prev_threshold))
    n.prev_threshold = temp_threshold
}

create_synapse :: proc(source, dest: ^Neuron) -> ^Synapse {
    s := new(Synapse)
    s.weight = next_float() * 2.0 - 1.0
    s.prev_weight = s.weight
    s.source_neuron = source
    s.dest_neuron = dest

    append(&source.synapses_out, s)
    append(&dest.synapses_in, s)

    return s
}

NeuralNetwork :: struct {
    input_layer: []^Neuron,
    hidden_layer: []^Neuron,
    output_layer: []^Neuron,
    synapses: [dynamic]^Synapse,
}

create_neural_network :: proc(inputs, hidden, outputs: int) -> ^NeuralNetwork {
    nn := new(NeuralNetwork)

    nn.input_layer = make([]^Neuron, inputs)
    for i in 0..<inputs {
        nn.input_layer[i] = create_neuron()
    }

    nn.hidden_layer = make([]^Neuron, hidden)
    for i in 0..<hidden {
        nn.hidden_layer[i] = create_neuron()
    }

    nn.output_layer = make([]^Neuron, outputs)
    for i in 0..<outputs {
        nn.output_layer[i] = create_neuron()
    }

    for source in nn.input_layer {
        for dest in nn.hidden_layer {
            synapse := create_synapse(source, dest)
            append(&nn.synapses, synapse)
        }
    }

    for source in nn.hidden_layer {
        for dest in nn.output_layer {
            synapse := create_synapse(source, dest)
            append(&nn.synapses, synapse)
        }
    }

    return nn
}

destroy_neural_network :: proc(nn: ^NeuralNetwork) {
    if nn == nil {
        return
    }

    for synapse in nn.synapses {
        free(synapse)
    }
    delete(nn.synapses)

    for neuron in nn.input_layer {
        destroy_neuron(neuron)
    }
    delete(nn.input_layer)

    for neuron in nn.hidden_layer {
        destroy_neuron(neuron)
    }
    delete(nn.hidden_layer)

    for neuron in nn.output_layer {
        destroy_neuron(neuron)
    }
    delete(nn.output_layer)

    free(nn)
}

feed_forward :: proc(nn: ^NeuralNetwork, inputs: []f64) {

    for i in 0..<len(nn.input_layer) {
        nn.input_layer[i].output = inputs[i]
    }

    for neuron in nn.hidden_layer {
        calculate_output(neuron)
    }

    for neuron in nn.output_layer {
        calculate_output(neuron)
    }
}

train :: proc(nn: ^NeuralNetwork, inputs, targets: []f64) {
    feed_forward(nn, inputs)

    for i in 0..<len(nn.output_layer) {
        output_train(nn.output_layer[i], 0.3, targets[i])
    }

    for neuron in nn.hidden_layer {
        hidden_train(neuron, 0.3)
    }
}

current_outputs :: proc(nn: ^NeuralNetwork) -> []f64 {
    outputs := make([]f64, len(nn.output_layer))
    for i in 0..<len(nn.output_layer) {
        outputs[i] = nn.output_layer[i].output
    }
    return outputs
}

NeuralNet :: struct {
    using base: Benchmark,
    xor_net: ^NeuralNetwork,
    result_val: u32,
}

neuralnet_prepare :: proc(bench: ^Benchmark) {
    nn := cast(^NeuralNet)bench

    nn.xor_net = create_neural_network(2, 10, 1)
}

neuralnet_run :: proc(bench: ^Benchmark, iteration_id: int) {
    nn := cast(^NeuralNet)bench

    for _ in 0..<1000 {
        train(nn.xor_net, INPUT_00[:], TARGET_0[:])
        train(nn.xor_net, INPUT_10[:], TARGET_1[:])
        train(nn.xor_net, INPUT_01[:], TARGET_1[:])
        train(nn.xor_net, INPUT_11[:], TARGET_0[:])
    }
}

neuralnet_checksum :: proc(bench: ^Benchmark) -> u32 {
    nn := cast(^NeuralNet)bench

    feed_forward(nn.xor_net, {0.0, 0.0})
    outputs1 := current_outputs(nn.xor_net)
    defer delete(outputs1)

    feed_forward(nn.xor_net, {0.0, 1.0})
    outputs2 := current_outputs(nn.xor_net)
    defer delete(outputs2)

    feed_forward(nn.xor_net, {1.0, 0.0})
    outputs3 := current_outputs(nn.xor_net)
    defer delete(outputs3)

    feed_forward(nn.xor_net, {1.0, 1.0})
    outputs4 := current_outputs(nn.xor_net)
    defer delete(outputs4)

    sum: f64 = 0.0
    for v in outputs1 {
        sum += v
    }
    for v in outputs2 {
        sum += v
    }
    for v in outputs3 {
        sum += v
    }
    for v in outputs4 {
        sum += v
    }

    return checksum_f64(sum)
}

neuralnet_cleanup :: proc(bench: ^Benchmark) {
    nn := cast(^NeuralNet)bench
    if nn.xor_net != nil {
        destroy_neural_network(nn.xor_net)
    }
}

create_neuralnet :: proc() -> ^Benchmark {
    nn := new(NeuralNet)
    nn.name = "Etc::NeuralNet"
    nn.vtable = default_vtable()

    nn.vtable.run = neuralnet_run
    nn.vtable.checksum = neuralnet_checksum
    nn.vtable.prepare = neuralnet_prepare
    nn.vtable.cleanup = neuralnet_cleanup

    return cast(^Benchmark)nn
}