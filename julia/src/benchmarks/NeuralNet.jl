mutable struct Synapse
    weight::Float64
    prev_weight::Float64
    source_neuron::Int32
    dest_neuron::Int32
end

function Synapse(source_neuron::Int32, dest_neuron::Int32)
    w = Helper.next_float() * 2.0 - 1.0
    return Synapse(w, w, source_neuron, dest_neuron)
end

mutable struct Neuron
    threshold::Float64
    prev_threshold::Float64
    output::Float64
    error::Float64
    synapses_in::Vector{Int32}
    synapses_out::Vector{Int32}
end

function Neuron()
    t = Helper.next_float() * 2.0 - 1.0
    return Neuron(t, t, 0.0, 0.0, Int32[], Int32[])
end

@inline function derivative(neuron::Neuron)::Float64
    return neuron.output * (1.0 - neuron.output)
end

const LEARNING_RATE = 1.0
const MOMENTUM = 0.3
const TRAIN_RATE = 0.3

mutable struct NeuralNetwork
    input_layer::Vector{Int32}
    hidden_layer::Vector{Int32}
    output_layer::Vector{Int32}
    neurons::Vector{Neuron}
    synapses::Vector{Synapse}
end

function NeuralNetwork(inputs::Int, hidden::Int, outputs::Int)
    total_neurons = inputs + hidden + outputs
    neurons = Vector{Neuron}(undef, total_neurons)

    for i = 1:total_neurons
        neurons[i] = Neuron()
    end

    input_layer = [i for i = 1:inputs]
    hidden_layer = [i for i = (inputs+1):(inputs+hidden)]
    output_layer = [i for i = (inputs+hidden+1):(inputs+hidden+outputs)]

    synapses = Synapse[]

    for source_idx in input_layer
        for dest_idx in hidden_layer
            synapse = Synapse(Int32(source_idx), Int32(dest_idx))
            push!(synapses, synapse)
            synapse_idx = length(synapses)

            push!(neurons[source_idx].synapses_out, Int32(synapse_idx))
            push!(neurons[dest_idx].synapses_in, Int32(synapse_idx))
        end
    end

    for source_idx in hidden_layer
        for dest_idx in output_layer
            synapse = Synapse(Int32(source_idx), Int32(dest_idx))
            push!(synapses, synapse)
            synapse_idx = length(synapses)

            push!(neurons[source_idx].synapses_out, Int32(synapse_idx))
            push!(neurons[dest_idx].synapses_in, Int32(synapse_idx))
        end
    end

    return NeuralNetwork(input_layer, hidden_layer, output_layer, neurons, synapses)
end

function train!(net::NeuralNetwork, inputs::Vector{Float64}, targets::Vector{Float64})
    feed_forward!(net, inputs)

    @inbounds for (i, target) in enumerate(targets)
        neuron_idx = net.output_layer[i]
        neuron = net.neurons[neuron_idx]

        error = (target - neuron.output) * derivative(neuron)
        net.neurons[neuron_idx].error = error

        for synapse_idx in neuron.synapses_in
            synapse = net.synapses[synapse_idx]
            source_output = net.neurons[synapse.source_neuron].output

            temp_weight = synapse.weight
            delta = TRAIN_RATE * LEARNING_RATE * error * source_output
            momentum_term = MOMENTUM * (synapse.weight - synapse.prev_weight)
            net.synapses[synapse_idx] = Synapse(
                synapse.weight + delta + momentum_term,
                temp_weight,
                synapse.source_neuron,
                synapse.dest_neuron,
            )
        end

        temp_threshold = neuron.threshold
        delta_threshold = TRAIN_RATE * LEARNING_RATE * error * -1.0
        momentum_threshold = MOMENTUM * (neuron.threshold - neuron.prev_threshold)
        net.neurons[neuron_idx] = Neuron(
            neuron.threshold + delta_threshold + momentum_threshold,
            temp_threshold,
            neuron.output,
            error,
            neuron.synapses_in,
            neuron.synapses_out,
        )
    end

    hidden_errors = Vector{Float64}(undef, length(net.hidden_layer))

    @inbounds for (i, neuron_idx) in enumerate(net.hidden_layer)
        neuron = net.neurons[neuron_idx]
        sum_error = 0.0

        for synapse_idx in neuron.synapses_out
            synapse = net.synapses[synapse_idx]

            sum_error += synapse.prev_weight * net.neurons[synapse.dest_neuron].error
        end

        hidden_errors[i] = sum_error * derivative(neuron)
    end

    @inbounds for (i, neuron_idx) in enumerate(net.hidden_layer)
        error = hidden_errors[i]
        neuron = net.neurons[neuron_idx]
        net.neurons[neuron_idx].error = error

        for synapse_idx in neuron.synapses_in
            synapse = net.synapses[synapse_idx]
            source_output = net.neurons[synapse.source_neuron].output

            temp_weight = synapse.weight
            delta = TRAIN_RATE * LEARNING_RATE * error * source_output
            momentum_term = MOMENTUM * (synapse.weight - synapse.prev_weight)
            net.synapses[synapse_idx] = Synapse(
                synapse.weight + delta + momentum_term,
                temp_weight,
                synapse.source_neuron,
                synapse.dest_neuron,
            )
        end

        temp_threshold = neuron.threshold
        delta_threshold = TRAIN_RATE * LEARNING_RATE * error * -1.0
        momentum_threshold = MOMENTUM * (neuron.threshold - neuron.prev_threshold)
        net.neurons[neuron_idx] = Neuron(
            neuron.threshold + delta_threshold + momentum_threshold,
            temp_threshold,
            neuron.output,
            error,
            neuron.synapses_in,
            neuron.synapses_out,
        )
    end
end

function feed_forward!(net::NeuralNetwork, inputs::Vector{Float64})

    @inbounds for (i, input) in enumerate(inputs)
        neuron_idx = net.input_layer[i]
        net.neurons[neuron_idx] = Neuron(
            net.neurons[neuron_idx].threshold,
            net.neurons[neuron_idx].prev_threshold,
            input,
            net.neurons[neuron_idx].error,
            net.neurons[neuron_idx].synapses_in,
            net.neurons[neuron_idx].synapses_out,
        )
    end

    @inbounds for neuron_idx in net.hidden_layer
        neuron = net.neurons[neuron_idx]
        activation = 0.0

        for synapse_idx in neuron.synapses_in
            synapse = net.synapses[synapse_idx]
            activation += synapse.weight * net.neurons[synapse.source_neuron].output
        end
        activation -= neuron.threshold

        output = 1.0 / (1.0 + exp(-activation))
        net.neurons[neuron_idx] = Neuron(
            neuron.threshold,
            neuron.prev_threshold,
            output,
            neuron.error,
            neuron.synapses_in,
            neuron.synapses_out,
        )
    end

    @inbounds for neuron_idx in net.output_layer
        neuron = net.neurons[neuron_idx]
        activation = 0.0

        for synapse_idx in neuron.synapses_in
            synapse = net.synapses[synapse_idx]
            activation += synapse.weight * net.neurons[synapse.source_neuron].output
        end
        activation -= neuron.threshold

        output = 1.0 / (1.0 + exp(-activation))
        net.neurons[neuron_idx] = Neuron(
            neuron.threshold,
            neuron.prev_threshold,
            output,
            neuron.error,
            neuron.synapses_in,
            neuron.synapses_out,
        )
    end
end

function current_outputs(net::NeuralNetwork)::Vector{Float64}
    outputs = Vector{Float64}(undef, length(net.output_layer))
    @inbounds for (i, neuron_idx) in enumerate(net.output_layer)
        outputs[i] = net.neurons[neuron_idx].output
    end
    return outputs
end

mutable struct NeuralNet <: AbstractBenchmark
    xor_net::Union{NeuralNetwork,Nothing}
    result::UInt32

    function NeuralNet()
        new(nothing, UInt32(0))
    end
end

name(b::NeuralNet)::String = "Etc::NeuralNet"

function prepare(b::NeuralNet)

    b.xor_net = NeuralNetwork(2, 10, 1)
end

function run(b::NeuralNet, iteration_id::Int64)
    if b.xor_net === nothing
        error("Neural network not initialized. Call prepare() first.")
    end

    train!(b.xor_net, [0.0, 0.0], [0.0])
    train!(b.xor_net, [1.0, 0.0], [1.0])
    train!(b.xor_net, [0.0, 1.0], [1.0])
    train!(b.xor_net, [1.0, 1.0], [0.0])
end

function checksum(b::NeuralNet)::UInt32
    if b.xor_net === nothing
        return UInt32(0)
    end

    net = b.xor_net

    total = 0.0

    feed_forward!(net, [0.0, 0.0])
    total += Base.sum(current_outputs(net))

    feed_forward!(net, [0.0, 1.0])
    total += Base.sum(current_outputs(net))

    feed_forward!(net, [1.0, 0.0])
    total += Base.sum(current_outputs(net))

    feed_forward!(net, [1.0, 1.0])
    total += Base.sum(current_outputs(net))

    return Helper.checksum_f64(total)
end
