const std = @import("std");
const Benchmark = @import("benchmark.zig").Benchmark;
const Helper = @import("helper.zig").Helper;
const math = std.math;

pub const NeuralNet = struct {
    allocator: std.mem.Allocator,
    helper: *Helper,
    result_val: u32,
    res: std.ArrayList(f64),
    xor_net: ?NeuralNetwork = null,

    const LEARNING_RATE: f64 = 1.0;
    const MOMENTUM: f64 = 0.3;
    const TRAIN_RATE: f64 = 0.3;

    const vtable = Benchmark.VTable{
        .prepare = prepareImpl,
        .run = runImpl,
        .checksum = checksumImpl,
        .deinit = deinitImpl,
    };

    const Synapse = struct {
        weight: f64,
        prev_weight: f64,
        source_neuron: usize,
        dest_neuron: usize,
    };

    const Neuron = struct {
        threshold: f64,
        prev_threshold: f64,
        output: f64,
        neuron_error: f64,
        synapses_in: std.ArrayList(usize),
        synapses_out: std.ArrayList(usize),

        fn init(helper: *Helper) Neuron {
            const t = helper.nextFloat(1.0);
            const threshold_val = t * 2.0 - 1.0;
            return Neuron{
                .threshold = threshold_val,
                .prev_threshold = threshold_val,
                .output = 0.0,
                .neuron_error = 0.0,
                .synapses_in = .{},
                .synapses_out = .{},
            };
        }

        fn derivative(self: Neuron) f64 {
            return self.output * (1.0 - self.output);
        }

        fn deinit(self: *Neuron, allocator: std.mem.Allocator) void {
            self.synapses_in.deinit(allocator);
            self.synapses_out.deinit(allocator);
        }
    };

    const NeuralNetwork = struct {
        input_layer: std.ArrayList(usize),
        hidden_layer: std.ArrayList(usize),
        output_layer: std.ArrayList(usize),
        neurons: std.ArrayList(Neuron),
        synapses: std.ArrayList(Synapse),
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, helper: *Helper, inputs: usize, hidden: usize, outputs: usize) !NeuralNetwork {
            var self = NeuralNetwork{
                .input_layer = .{},
                .hidden_layer = .{},
                .output_layer = .{},
                .neurons = .{},
                .synapses = .{},
                .allocator = allocator,
            };

            const total_neurons = inputs + hidden + outputs;
            try self.neurons.ensureTotalCapacity(allocator, total_neurons);

            for (0..total_neurons) |_| {
                try self.neurons.append(allocator, Neuron.init(helper));
            }

            try self.input_layer.ensureTotalCapacity(allocator, inputs);
            try self.hidden_layer.ensureTotalCapacity(allocator, hidden);
            try self.output_layer.ensureTotalCapacity(allocator, outputs);

            for (0..inputs) |i| {
                try self.input_layer.append(allocator, i);
            }

            for (inputs..inputs + hidden) |i| {
                try self.hidden_layer.append(allocator, i);
            }

            for (inputs + hidden..inputs + hidden + outputs) |i| {
                try self.output_layer.append(allocator, i);
            }

            // input -> hidden
            for (self.input_layer.items) |source_idx| {
                for (self.hidden_layer.items) |dest_idx| {
                    const synapse_idx = self.synapses.items.len;
                    const w_val = helper.nextFloat(1.0);
                    const w = w_val * 2.0 - 1.0;

                    try self.synapses.append(allocator, Synapse{
                        .weight = w,
                        .prev_weight = w,
                        .source_neuron = source_idx,
                        .dest_neuron = dest_idx,
                    });

                    try self.neurons.items[source_idx].synapses_out.append(allocator, synapse_idx);
                    try self.neurons.items[dest_idx].synapses_in.append(allocator, synapse_idx);
                }
            }

            // hidden -> output
            for (self.hidden_layer.items) |source_idx| {
                for (self.output_layer.items) |dest_idx| {
                    const synapse_idx = self.synapses.items.len;
                    const w_val = helper.nextFloat(1.0);
                    const w = w_val * 2.0 - 1.0;

                    try self.synapses.append(allocator, Synapse{
                        .weight = w,
                        .prev_weight = w,
                        .source_neuron = source_idx,
                        .dest_neuron = dest_idx,
                    });

                    try self.neurons.items[source_idx].synapses_out.append(allocator, synapse_idx);
                    try self.neurons.items[dest_idx].synapses_in.append(allocator, synapse_idx);
                }
            }

            return self;
        }

        fn deinit(self: *NeuralNetwork) void {
            for (self.neurons.items) |*neuron| {
                neuron.deinit(self.allocator);
            }
            self.input_layer.deinit(self.allocator);
            self.hidden_layer.deinit(self.allocator);
            self.output_layer.deinit(self.allocator);
            self.neurons.deinit(self.allocator);
            self.synapses.deinit(self.allocator);
        }

        fn train(self: *NeuralNetwork, inputs: []const f64, targets: []const f64) void {
            self.feedForward(inputs);

            for (self.output_layer.items, 0..) |neuron_idx, i| {
                self.outputTrain(neuron_idx, targets[i]);
            }

            for (self.hidden_layer.items) |neuron_idx| {
                self.hiddenTrain(neuron_idx);
            }
        }

        fn outputTrain(self: *NeuralNetwork, neuron_idx: usize, target: f64) void {
            var neuron = &self.neurons.items[neuron_idx];
            neuron.neuron_error = (target - neuron.output) * neuron.derivative();
            self.updateWeights(neuron_idx);
        }

        fn hiddenTrain(self: *NeuralNetwork, neuron_idx: usize) void {
            var neuron = &self.neurons.items[neuron_idx];

            var sum: f64 = 0.0;
            for (neuron.synapses_out.items) |synapse_idx| {
                const synapse = self.synapses.items[synapse_idx];
                const dest_neuron = &self.neurons.items[synapse.dest_neuron];
                sum += synapse.prev_weight * dest_neuron.neuron_error;
            }

            neuron.neuron_error = sum * neuron.derivative();
            self.updateWeights(neuron_idx);
        }

        fn updateWeights(self: *NeuralNetwork, neuron_idx: usize) void {
            var neuron = &self.neurons.items[neuron_idx];
            const err = neuron.neuron_error;

            for (neuron.synapses_in.items) |synapse_idx| {
                var synapse = &self.synapses.items[synapse_idx];
                const temp_weight = synapse.weight;
                const source_output = self.neurons.items[synapse.source_neuron].output;

                synapse.weight += (TRAIN_RATE * LEARNING_RATE * err * source_output) +
                    (MOMENTUM * (synapse.weight - synapse.prev_weight));
                synapse.prev_weight = temp_weight;
            }

            const temp_threshold = neuron.threshold;
            neuron.threshold += (TRAIN_RATE * LEARNING_RATE * err * -1.0) +
                (MOMENTUM * (neuron.threshold - neuron.prev_threshold));
            neuron.prev_threshold = temp_threshold;
        }

        fn feedForward(self: *NeuralNetwork, inputs: []const f64) void {
            for (self.input_layer.items, 0..) |neuron_idx, i| {
                self.neurons.items[neuron_idx].output = inputs[i];
            }

            for (self.hidden_layer.items) |neuron_idx| {
                var neuron = &self.neurons.items[neuron_idx];
                var activation: f64 = 0.0;

                for (neuron.synapses_in.items) |synapse_idx| {
                    const synapse = self.synapses.items[synapse_idx];
                    const source_output = self.neurons.items[synapse.source_neuron].output;
                    activation += synapse.weight * source_output;
                }

                const net_input = activation - neuron.threshold;
                const exp_val = std.math.exp(-net_input);
                neuron.output = 1.0 / (1.0 + exp_val);
            }

            for (self.output_layer.items) |neuron_idx| {
                var neuron = &self.neurons.items[neuron_idx];
                var activation: f64 = 0.0;

                for (neuron.synapses_in.items) |synapse_idx| {
                    const synapse = self.synapses.items[synapse_idx];
                    const source_output = self.neurons.items[synapse.source_neuron].output;
                    activation += synapse.weight * source_output;
                }

                const net_input = activation - neuron.threshold;
                const exp_val = std.math.exp(-net_input);
                neuron.output = 1.0 / (1.0 + exp_val);
            }
        }

        fn currentOutputs(self: *NeuralNetwork) std.ArrayList(f64) {
            var outputs = std.ArrayList(f64){};
            outputs.ensureTotalCapacity(self.allocator, self.output_layer.items.len) catch return outputs;
            for (self.output_layer.items) |neuron_idx| {
                outputs.appendAssumeCapacity(self.neurons.items[neuron_idx].output);
            }
            return outputs;
        }
    };

    pub fn init(allocator: std.mem.Allocator, helper: *Helper) !*NeuralNet {
        const self = try allocator.create(NeuralNet);
        errdefer allocator.destroy(self);

        self.* = NeuralNet{
            .allocator = allocator,
            .helper = helper,
            .result_val = 0,
            .res = .{},
            .xor_net = null,
        };

        return self;
    }

    pub fn deinit(self: *NeuralNet) void {
        if (self.xor_net) |*net| {
            net.deinit();
        }
        self.res.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn asBenchmark(self: *NeuralNet) Benchmark {
        return Benchmark.init(self, &vtable, self.helper, "NeuralNet");
    }

    fn prepareImpl(ptr: *anyopaque) void {
        const self: *NeuralNet = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;
        const helper = self.helper;

        if (self.xor_net) |*net| {
            net.deinit();
        }

        self.xor_net = NeuralNetwork.init(allocator, helper, 2, 10, 1) catch return;
    }

    fn runImpl(ptr: *anyopaque, _: i64) void {
        const self: *NeuralNet = @ptrCast(@alignCast(ptr));

        if (self.xor_net) |*xor_net| {
            xor_net.train(&[_]f64{ 0.0, 0.0 }, &[_]f64{0.0});
            xor_net.train(&[_]f64{ 1.0, 0.0 }, &[_]f64{1.0});
            xor_net.train(&[_]f64{ 0.0, 1.0 }, &[_]f64{1.0});
            xor_net.train(&[_]f64{ 1.0, 1.0 }, &[_]f64{0.0});

            self.res.clearAndFree(self.allocator);
        }
    }

    fn checksumImpl(ptr: *anyopaque) u32 {
        const self: *NeuralNet = @ptrCast(@alignCast(ptr));
        const allocator = self.allocator;

        if (self.xor_net) |*xor_net| {
            self.res.clearAndFree(allocator);

            const test_cases = [_][2]f64{
                .{ 0.0, 0.0 },
                .{ 0.0, 1.0 },
                .{ 1.0, 0.0 },
                .{ 1.0, 1.0 },
            };

            for (test_cases) |inputs| {
                xor_net.feedForward(&inputs);
                var outputs = xor_net.currentOutputs();
                defer outputs.deinit(allocator);
                for (outputs.items) |output| {
                    self.res.append(allocator, output) catch continue;
                }
            }

            var sum: f64 = 0.0;
            for (self.res.items) |v| {
                sum += v;
            }

            return self.helper.checksumFloat(sum);
        }

        return 0;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *NeuralNet = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};