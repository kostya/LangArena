public class NeuralNet : Benchmark
{
    private int _n;
    private double _sum;
    
    public override long Result => (long)Helper.Checksum(_sum);
    
    public NeuralNet()
    {
        _sum = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(NeuralNet);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _n = iter;
                return;
            }
        }
        _n = 1;
    }
    
    private class Synapse
    {
        public Neuron SourceNeuron { get; }
        public Neuron DestNeuron { get; }
        public double Weight { get; set; }
        public double PrevWeight { get; set; }
        
        public Synapse(Neuron sourceNeuron, Neuron destNeuron)
        {
            SourceNeuron = sourceNeuron;
            DestNeuron = destNeuron;
            PrevWeight = Weight = Helper.NextFloat() * 2 - 1;
        }
    }
    
    private class Neuron
    {
        private const double LEARNING_RATE = 1.0;
        private const double MOMENTUM = 0.3;
        
        public List<Synapse> SynapsesIn { get; } = new();
        public List<Synapse> SynapsesOut { get; } = new();
        public double Threshold { get; set; }
        public double PrevThreshold { get; set; }
        public double Error { get; set; }
        public double Output { get; set; }
        
        public Neuron()
        {
            PrevThreshold = Threshold = Helper.NextFloat() * 2 - 1;
        }
        
        public void CalculateOutput()
        {
            double activation = 0;
            foreach (var synapse in SynapsesIn)
            {
                activation += synapse.Weight * synapse.SourceNeuron.Output;
            }
            activation -= Threshold;
            
            Output = 1.0 / (1.0 + Math.Exp(-activation));
        }
        
        private double Derivative() => Output * (1 - Output);
        
        public void OutputTrain(double rate, double target)
        {
            Error = (target - Output) * Derivative();
            UpdateWeights(rate);
        }
        
        public void HiddenTrain(double rate)
        {
            Error = 0;
            foreach (var synapse in SynapsesOut)
            {
                Error += synapse.PrevWeight * synapse.DestNeuron.Error;
            }
            Error *= Derivative();
            UpdateWeights(rate);
        }
        
        private void UpdateWeights(double rate)
        {
            foreach (var synapse in SynapsesIn)
            {
                double tempWeight = synapse.Weight;
                synapse.Weight += (rate * LEARNING_RATE * Error * synapse.SourceNeuron.Output) +
                                 (MOMENTUM * (synapse.Weight - synapse.PrevWeight));
                synapse.PrevWeight = tempWeight;
            }
            
            double tempThreshold = Threshold;
            Threshold += (rate * LEARNING_RATE * Error * -1) +
                        (MOMENTUM * (Threshold - PrevThreshold));
            PrevThreshold = tempThreshold;
        }
    }
    
    private class NeuralNetwork
    {
        private readonly Neuron[] _inputLayer;
        private readonly Neuron[] _hiddenLayer;
        private readonly Neuron[] _outputLayer;
        
        public NeuralNetwork(int inputs, int hidden, int outputs)
        {
            _inputLayer = new Neuron[inputs];
            _hiddenLayer = new Neuron[hidden];
            _outputLayer = new Neuron[outputs];
            
            for (int i = 0; i < inputs; i++)
                _inputLayer[i] = new Neuron();
            for (int i = 0; i < hidden; i++)
                _hiddenLayer[i] = new Neuron();
            for (int i = 0; i < outputs; i++)
                _outputLayer[i] = new Neuron();
            
            // Connect input to hidden
            foreach (var source in _inputLayer)
            {
                foreach (var dest in _hiddenLayer)
                {
                    var synapse = new Synapse(source, dest);
                    source.SynapsesOut.Add(synapse);
                    dest.SynapsesIn.Add(synapse);
                }
            }
            
            // Connect hidden to output
            foreach (var source in _hiddenLayer)
            {
                foreach (var dest in _outputLayer)
                {
                    var synapse = new Synapse(source, dest);
                    source.SynapsesOut.Add(synapse);
                    dest.SynapsesIn.Add(synapse);
                }
            }
        }
        
        public void Train(double[] inputs, double[] targets)
        {
            FeedForward(inputs);
            
            for (int i = 0; i < _outputLayer.Length; i++)
            {
                _outputLayer[i].OutputTrain(0.3, targets[i]);
            }
            
            foreach (var neuron in _hiddenLayer)
            {
                neuron.HiddenTrain(0.3);
            }
        }
        
        public void FeedForward(double[] inputs)
        {
            for (int i = 0; i < _inputLayer.Length; i++)
            {
                _inputLayer[i].Output = inputs[i];
            }
            
            foreach (var neuron in _hiddenLayer)
            {
                neuron.CalculateOutput();
            }
            
            foreach (var neuron in _outputLayer)
            {
                neuron.CalculateOutput();
            }
        }
        
        public double[] CurrentOutputs()
        {
            return _outputLayer.Select(n => n.Output).ToArray();
        }
    }
    
    public override void Run()
    {
        var xor = new NeuralNetwork(2, 10, 1);
        double sum = 0;
        
        for (int i = 0; i < _n; i++)
        {
            xor.Train([0, 0], [0]);
            xor.Train([1, 0], [1]);
            xor.Train([0, 1], [1]);
            xor.Train([1, 1], [0]);
        }
        
        xor.FeedForward([0, 0]);
        sum += xor.CurrentOutputs().Sum();
        
        xor.FeedForward([0, 1]);
        sum += xor.CurrentOutputs().Sum();
        
        xor.FeedForward([1, 0]);
        sum += xor.CurrentOutputs().Sum();
        
        xor.FeedForward([1, 1]);
        sum += xor.CurrentOutputs().Sum();
        
        _sum = sum;
    }
}