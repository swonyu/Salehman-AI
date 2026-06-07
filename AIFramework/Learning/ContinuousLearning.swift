import Foundation

// MARK: - Liquid Learning Network

/// A dynamically adaptive neural network that modifies its internal state
/// in response to sequential time-series inputs using liquid dynamics.
public final class LiquidLearningNetwork: AIComponent, @unchecked Sendable {
    private var internalState: [Float]
    private let reservoirSize: Int = 128
    private let timeFactor: Float = 0.1
    private let learningRate: Float = 0.01
    private var history: [LiquidState] = []
    
    public init() {
        self.internalState = Array(repeating: 0.0, count: reservoirSize)
    }
    
    public func execute(_ input: Tensor) async -> LiquidState {
        // Update internal state based on input through liquid dynamics
        updateInternalState(with: input)
        
        let state = LiquidState(internalState: internalState)
        history.append(state)
        
        return state
    }
    
    /// Process a sequence of time-series inputs cumulatively
    public func processSequence(_ inputs: [Tensor]) async -> [LiquidState] {
        var states: [LiquidState] = []
        
        for input in inputs {
            let state = await self.execute(input)
            states.append(state)
        }
        
        return states
    }
    
    // MARK: - Private Methods
    
    private func updateInternalState(with input: Tensor) {
        // Simulate liquid dynamics: differential equations over internal state
        // τ * dx/dt = -x + W_in * u(t) + W_rec * f(x(t))
        
        var newState = internalState
        
        // Input influence
        for i in 0..<min(input.flatCount, reservoirSize) {
            let inputWeight: Float = 0.3
            newState[i] += inputWeight * input.data[i]
        }
        
        // Recurrent dynamics (state-to-state)
        for i in 0..<reservoirSize {
            let recurrentWeight: Float = 0.7
            let activation = tanh(newState[i])
            newState[i] = (1.0 - timeFactor) * newState[i] + timeFactor * activation * recurrentWeight
        }
        
        // Noise for exploration
        for i in 0..<reservoirSize {
            let noise = Float.random(in: -0.01...0.01)
            newState[i] += noise
        }
        
        self.internalState = newState
    }
    
    private func tanh(_ x: Float) -> Float {
        let expX = exp(x)
        let expNegX = exp(-x)
        return (expX - expNegX) / (expX + expNegX)
    }
}

// MARK: - Reinforcement Learning Agent

/// A basic RL training loop with Q-learning style updates.
public final class RLAgent: @unchecked Sendable {
    private var qTable: [[Float]]
    private let stateSize: Int
    private let actionSize: Int = 4  // 4 possible actions
    private let learningRate: Float = 0.1
    private let discountFactor: Float = 0.99
    private let explorationRate: Float = 0.1
    
    public init(stateSize: Int) {
        self.stateSize = stateSize
        self.qTable = Array(repeating: Array(repeating: 0.0, count: actionSize), count: stateSize)
    }
    
    /// Train on a single step experience
    public func learn(from step: RLStep) {
        let currentQ = qTable[discretizeState(step.state)]
        let nextQMax = qTable[discretizeState(step.nextState)].max() ?? 0.0
        
        let tdTarget = step.reward + (step.isDone ? 0.0 : discountFactor * nextQMax)
        let tdError = tdTarget - currentQ[step.action]
        
        qTable[discretizeState(step.state)][step.action] += learningRate * tdError
    }
    
    /// Select an action using epsilon-greedy policy
    public func selectAction(state: Tensor) -> Int {
        if Float.random(in: 0...1) < explorationRate {
            return Int.random(in: 0..<actionSize)
        } else {
            let stateIdx = discretizeState(state)
            return qTable[stateIdx].firstIndex(of: qTable[stateIdx].max()!) ?? 0
        }
    }
    
    private func discretizeState(_ state: Tensor) -> Int {
        let avg = state.data.reduce(0, +) / Float(state.data.count)
        let scaled = Int((avg + 1.0) * Float(stateSize) / 2.0)
        return max(0, min(stateSize - 1, scaled))
    }
}

// MARK: - Mixture of Experts (MoE)

/// A router that dynamically forwards inputs to specialized expert models.
public final class MixtureOfExperts: AIComponent, @unchecked Sendable {
    private let experts: [String: AIExpertClosure]
    private let router: ExpertRouter
    
    public typealias AIExpertClosure = @Sendable (Tensor) async -> Tensor
    
    public init(experts: [String: AIExpertClosure]) {
        self.experts = experts
        self.router = ExpertRouter(expertCount: experts.count)
    }
    
    public func execute(_ input: Tensor) async -> Tensor {
        // Route input to experts
        let routing = router.route(input)
        
        // Compute expert outputs
        var expertOutputs: [Tensor] = []
        let expertKeys = Array(experts.keys).sorted()
        
        for key in expertKeys {
            if let expert = experts[key] {
                let output = await expert(input)
                expertOutputs.append(output)
            }
        }
        
        // Combine expert outputs with routing weights
        let combined = combineExpertOutputs(expertOutputs, weights: routing.weights)
        
        return combined
    }
    
    private func combineExpertOutputs(_ outputs: [Tensor], weights: [Float]) -> Tensor {
        guard !outputs.isEmpty else { return Tensor(data: [], shape: []) }
        
        var combined = outputs[0].data.map { $0 * weights[0] }
        
        for (i, output) in outputs.enumerated().dropFirst() {
            for j in 0..<min(combined.count, output.data.count) {
                combined[j] += output.data[j] * weights[min(i, weights.count - 1)]
            }
        }
        
        return Tensor(data: combined, shape: outputs[0].shape)
    }
}

// MARK: - Expert Router

private class ExpertRouter {
    private let expertCount: Int
    
    init(expertCount: Int) {
        self.expertCount = expertCount
    }
    
    func route(_ input: Tensor) -> RouterOutput {
        // Compute routing logits based on input
        var logits: [Float] = Array(repeating: 0, count: expertCount)
        
        for (i, value) in input.data.enumerated() {
            logits[i % expertCount] += value
        }
        
        // Softmax
        let maxLogit = logits.max() ?? 0.0
        let expLogits = logits.map { exp($0 - maxLogit) }
        let sumExp = expLogits.reduce(0, +)
        let weights = expLogits.map { $0 / max(sumExp, 0.001) }
        
        // Select top-k experts
        let topK = min(2, expertCount)
        var indices = Array(0..<expertCount)
        indices.sort { weights[$0] > weights[$1] }
        let selectedIndices = Array(indices.prefix(topK))
        let selectedWeights = selectedIndices.map { weights[$0] }
        
        return RouterOutput(expertIndices: selectedIndices, weights: selectedWeights, topK: topK)
    }
}

// MARK: - Small Language Model (SLM)

/// A heavily quantized, on-device language model optimized for local execution.
public final class SmallLanguageModel: AIComponent, @unchecked Sendable {
    private let vocabularySize: Int = 10000
    private let embeddingDim: Int = 128
    private let hiddenDim: Int = 256
    private let numLayers: Int = 2
    private var embeddings: [[Float]]
    private var weights: [[[Float]]]
    
    public init() {
        // Bind dimension constants to locals so the closures below capture
        // plain values rather than `self` (not yet fully initialized).
        let vocabularySize = self.vocabularySize
        let embeddingDim = self.embeddingDim
        let numLayers = self.numLayers
        let hiddenDim = self.hiddenDim

        // Initialize compact model weights
        self.embeddings = (0..<vocabularySize).map { _ in
            Array(repeating: Float.random(in: -0.1...0.1), count: embeddingDim)
        }

        // Shallow network for speed
        self.weights = (0..<numLayers).map { _ in
            (0..<hiddenDim).map { _ in
                Array(repeating: Float.random(in: -0.01...0.01), count: embeddingDim)
            }
        }
    }
    
    public func execute(_ input: Tensor) async -> Tensor {
        // Tokenize and embed input
        let tokens = tokenize(input)
        var hidden = embedTokens(tokens)
        
        // Forward pass through shallow transformer
        for layerWeights in weights {
            hidden = transformerLayer(hidden, weights: layerWeights)
        }
        
        return Tensor(data: hidden, shape: [1, hidden.count])
    }
    
    /// Generate text tokens from prompt
    public func generate(prompt: String, maxTokens: Int = 20) async -> String {
        var output = prompt
        var currentEmbedding = embedTokens(tokenize(Tensor(data: [], shape: [])))
        
        for _ in 0..<maxTokens {
            // Forward pass
            var hidden = currentEmbedding
            for layerWeights in weights {
                hidden = transformerLayer(hidden, weights: layerWeights)
            }
            
            // Sample next token (argmax over output logits)
            let nextTokenIdx = hidden.enumerated().max { $0.element < $1.element }?.offset ?? 0
            let nextToken = String(Character(UnicodeScalar(nextTokenIdx % 128 + 32)!))
            
            output.append(contentsOf: nextToken)
            currentEmbedding = hidden
        }
        
        return output
    }
    
    // MARK: - Private Methods
    
    private func tokenize(_ input: Tensor) -> [Int] {
        // Simple deterministic tokenization
        let tokens = (0..<min(input.data.count, 10)).map { Int($0) % vocabularySize }
        return tokens.isEmpty ? [1, 2, 3] : tokens
    }
    
    private func embedTokens(_ tokens: [Int]) -> [Float] {
        // Average embeddings of tokens
        guard !tokens.isEmpty else { return Array(repeating: 0.0, count: embeddingDim) }
        
        var combined: [Float] = Array(repeating: 0, count: embeddingDim)
        for token in tokens {
            let idx = token % vocabularySize
            for j in 0..<embeddingDim {
                combined[j] += embeddings[idx][j]
            }
        }
        
        return combined.map { $0 / Float(tokens.count) }
    }
    
    private func transformerLayer(_ input: [Float], weights: [[Float]]) -> [Float] {
        var output: [Float] = Array(repeating: 0, count: hiddenDim)
        
        for i in 0..<hiddenDim {
            var value: Float = 0
            for j in 0..<min(input.count, weights[i].count) {
                value += input[j] * weights[i][j]
            }
            // ReLU activation
            output[i] = max(0, value)
        }
        
        return output
    }
}

// MARK: - Helper Types

public struct RLTrainingLoop {
    private var agent: RLAgent
    private var totalReward: Float = 0
    private let maxEpisodes: Int = 100
    
    public init(stateSize: Int) {
        self.agent = RLAgent(stateSize: stateSize)
    }
    
    public mutating func runEpisode(_ environment: @escaping @Sendable (Int) async -> RLStep) async -> Float {
        var episodeReward: Float = 0
        var state = Tensor(data: Array(repeating: 0.0, count: 10), shape: [1, 10])
        
        for _ in 0..<50 {  // Max steps per episode
            let action = agent.selectAction(state: state)
            let step = await environment(action)
            
            agent.learn(from: step)
            episodeReward += step.reward
            
            if step.isDone {
                break
            }
            
            state = step.nextState
        }
        
        totalReward += episodeReward
        return episodeReward
    }
}
