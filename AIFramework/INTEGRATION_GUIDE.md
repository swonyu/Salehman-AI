# AI Framework Integration Guide

## Quick Start

### 1. Framework Overview
The AIFramework is a modular, end-to-end system demonstrating 5 major AI paradigm categories:

```
┌─────────────────────────────────────────────┐
│     AIPipelineOrchestrator (Main Hub)       │
└────────────┬────────────────────────────────┘
             │
    ┌────────┼────────┬────────┬──────────┐
    │        │        │        │          │
    ▼        ▼        ▼        ▼          ▼
 Multimodal Action  Generative Learning Config
   (VLM/SAM) (LAM/VLA) (Diffusion) (Liquid/RL/MoE)
```

### 2. Component Responsibilities

| Component | Input | Output | Use Case |
|-----------|-------|--------|----------|
| **VLM** | CGImage + String | VLMOutput (desc, confidence) | Image-text alignment |
| **SAM** | CGImage + Optional prompts | SegmentationResult | Object segmentation |
| **LAM** | String objective | ActionExecutionResult (events) | Digital automation |
| **VLA** | String command + [Float] visual | TrajectoryVector | Robotic motion |
| **Diffusion** | String prompt | [DiffusionStep] | Text-to-image |
| **TabularML** | [String: Float] features | TabularPrediction | Classification |
| **LiquidNet** | Tensor | LiquidState | Adaptive learning |
| **RL Agent** | RLStep episodes | Updated Q-values | Policy learning |
| **MoE** | Tensor | Tensor (combined) | Expert routing |
| **SLM** | String prompt | String (generated) | Local generation |

### 3. Using Individual Components

#### Example: Vision-Language Model
```swift
let vlm = VisionLanguageModel()
let input = VLMInput(image: myImage, prompt: "What is in this image?")
let output = await vlm.execute(input)
print("Confidence: \(output.confidence)")
print("Description: \(output.description)")
```

#### Example: Segment Anything Model
```swift
let sam = SegmentAnythingModel()
let input = SAMInput(
    image: myImage,
    promptPoints: [(x: 0.5, y: 0.5)],
    promptBox: nil
)
let result = await sam.execute(input)
print("Detected segments: \(result.boundingBoxes.count)")
```

#### Example: Action Models
```swift
// Digital agent (LAM)
let lam = LargeActionModel()
let lamResult = await lam.execute(LAMInput(objective: "Open the settings menu"))
print("Events: \(lamResult.eventSequence.count)")

// Robotic controller (VLA)
let vla = VisionLanguageActionModel()
let vlaInput = VLAInput(command: "Move forward and grasp", visualData: features)
let vlaResult = await vla.execute(vlaInput)
if let trajectory = vlaResult.trajectoryVector {
    print("Target: (\(trajectory.x), \(trajectory.y), \(trajectory.z))")
}
```

#### Example: Mixture of Experts
```swift
let experts: [String: MixtureOfExperts.AIExpertClosure] = [
    "vision_expert": { tensor in tensor.map { $0 * 0.5 } },
    "reasoning_expert": { tensor in tensor.map { tanh($0) } }
]
let moe = MixtureOfExperts(experts: experts)
let input = Tensor(data: features, shape: [1, features.count])
let combined = await moe.execute(input)
```

### 4. Full Pipeline Execution

```swift
let orchestrator = AIPipelineOrchestrator()

let result = await orchestrator.executeEndToEnd(
    userCommand: "Analyze this image and predict fraud risk",
    image: sampleImage,
    transactionFeatures: ["amount": 2500, "velocity": 2.5]
)

print("Success: \(result.success)")
print("Full Log:\n\(result.log)")

// Access individual phase results
if let phase1 = result.phase1 {
    print("VLM Confidence: \(phase1.vlmOutput.confidence)")
}
if let phase5 = result.phase5 {
    print("LAM Events: \(phase5.lamResult.eventSequence.count)")
}
```

### 5. Data Flow Through Pipeline

```
User Input (command + image + features)
    │
    ├─► PHASE 1: Multimodal Analysis
    │   • VLM embeds image + text
    │   • SAM segments objects
    │   └─► Visual features [Float]
    │
    ├─► PHASE 2: Continuous Learning
    │   • Liquid Network processes features
    │   • RL agent learns from rewards
    │   └─► Adapted internal state
    │
    ├─► PHASE 3: Tabular ML
    │   • Feature normalization
    │   • Tree ensemble prediction
    │   └─► Classification + explanation
    │
    ├─► PHASE 4: Generative AI
    │   • Text-to-image diffusion
    │   • Iterative denoising (50 steps)
    │   └─► Image tensor
    │
    ├─► PHASE 5: Action Execution
    │   • LAM breaks down objective → events
    │   • VLA generates trajectory → motion
    │   └─► Event sequence + motion vector
    │
    ├─► PHASE 6: Expert Routing
    │   • MoE routes input to specialists
    │   • Combines expert outputs
    │   └─► Fused representation
    │
    └─► PHASE 7: Language Generation
        • SLM generates response
        └─► Final text output

Pipeline Result (success flag + all phase outputs + execution log)
```

### 6. Key Protocols & Patterns

#### AIComponent Protocol
All major components conform to this:
```swift
public protocol AIComponent: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func execute(_ input: Input) async -> Output
}
```

#### StreamingAIComponent Protocol
For components that produce multiple outputs:
```swift
public protocol StreamingAIComponent: AIComponent {
    associatedtype StreamOutput: Sendable
    
    func executeStreaming(_ input: Input) async -> AsyncStream<StreamOutput>
}
```

### 7. Error Handling

```swift
public enum PipelineError: Error {
    case moeNotInitialized
    case invalidInput
    case processingFailed(String)
}

// Usage
do {
    let result = await orchestrator.executeEndToEnd(...)
    if !result.success {
        print("Pipeline failed: see result.log for details")
    }
} catch {
    print("Error: \(error)")
}
```

### 8. Performance Considerations

| Component | Complexity | Memory | GPU? |
|-----------|-----------|--------|------|
| VLM | O(n) feature extraction | ~10 MB | No (Vision) |
| SAM | O(n²) mask refinement | ~20 MB | No |
| LAM | O(k) task decomposition | ~1 MB | No |
| VLA | O(m) trajectory calc | ~5 MB | No |
| Diffusion | O(50n) iterative | ~100 MB | Yes (Metal) |
| TabularML | O(n*trees) | ~2 MB | No |
| LiquidNet | O(state²) update | ~5 MB | Yes (Accelerate) |
| RL | O(state_space) | ~1 MB | No |
| MoE | O(k log n) routing | ~10 MB | No |
| SLM | O(vocab * hidden) | ~20 MB | No |

### 9. Testing Individual Components

```swift
// Test VLM
let image = createTestImage()
let vlm = VisionLanguageModel()
let output = await vlm.execute(VLMInput(image: image, prompt: "test"))
assert(output.confidence >= 0, "Confidence must be non-negative")

// Test RL
var agent = RLAgent(stateSize: 100)
let step = RLStep(
    state: Tensor(data: [0.5], shape: [1]),
    action: 0,
    reward: 1.0,
    nextState: Tensor(data: [0.6], shape: [1]),
    isDone: false
)
agent.learn(from: step)
let action = agent.selectAction(state: step.nextState)
assert(action >= 0 && action < 4, "Action must be valid")
```

### 10. Integration with Salehman AI

The AIFramework can be integrated into the existing Salehman AI app:

```swift
// In your AppState or ViewModel
let orchestrator = AIPipelineOrchestrator()

// On user input
@Published var aiResult: PipelineExecutionResult?

func processUserCommand(_ command: String) async {
    let result = await orchestrator.executeEndToEnd(
        userCommand: command,
        image: currentScreenCapture,
        transactionFeatures: getCurrentTransactionData()
    )
    self.aiResult = result
    // Update UI with result
}
```

### 11. Extending the Framework

To add a new component:

1. Create a struct/class conforming to `AIComponent`
2. Define Input and Output types
3. Implement `execute(_:)` method
4. Add to orchestrator's phase methods
5. Update documentation

Example:
```swift
public final class MyCustomComponent: AIComponent {
    public func execute(_ input: MyInput) async -> MyOutput {
        // Implementation
    }
}
```

### 12. Debugging & Logging

All orchestrator phases are logged:
```swift
let result = await orchestrator.executeEndToEnd(...)
print(result.log)  // Detailed step-by-step execution log
```

Individual components also log internally via `print` statements.

---

## Architecture Decision Records (ADR)

### ADR-1: Async/Await for Concurrency
**Decision**: Use Swift 6 async/await instead of callbacks or Combine.  
**Reason**: Structured concurrency, MainActor safety, clearer data flow.

### ADR-2: Protocols for Component Abstraction
**Decision**: AIComponent protocol for all major modules.  
**Reason**: Enables composition, testing, and future neural engine swaps.

### ADR-3: Sendable for Thread Safety
**Decision**: All public types marked Sendable.  
**Reason**: Prevents data races in concurrent contexts.

### ADR-4: Value Semantics for Data Types
**Decision**: Tensor, BoundingBox, etc. are structs (value types).  
**Reason**: Implicit CoW, thread-safe by default, predictable lifetime.

---

## FAQ

**Q: Can I use only one component?**  
A: Yes! Each component is independent. Just import and use `VisionLanguageModel()` directly.

**Q: How do I replace a component with a custom one?**  
A: Conform to the same protocol (e.g., `AIComponent`) and swap the instance.

**Q: Can I run this on iOS?**  
A: Yes, with minor changes (AppKit → UIKit for some components).

**Q: How accurate are the simulations?**  
A: These are demonstrations. Production use requires real neural engine models.

**Q: Is the pipeline production-ready?**  
A: The architecture is solid, but simulated components need CoreML/Metal replacements.

---

Generated for: Salehman AI Framework Integration  
Last Updated: 2026-06-07
