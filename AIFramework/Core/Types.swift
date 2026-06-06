import Foundation
import Vision
import CoreML

// MARK: - Core Type Definitions

/// Represents a tensor in the AI pipeline (flexible n-dimensional array wrapper).
public struct Tensor {
    public let data: [Float]
    public let shape: [Int]
    
    public init(data: [Float], shape: [Int]) {
        self.data = data
        self.shape = shape
    }
    
    public var flatCount: Int { data.count }
    
    /// Element-wise operation
    public func map(_ transform: (Float) -> Float) -> Tensor {
        Tensor(data: data.map(transform), shape: shape)
    }
}

/// Represents a bounding box detected in vision tasks.
public struct BoundingBox {
    public let x: Float
    public let y: Float
    public let width: Float
    public let height: Float
    public let confidence: Float
    public let label: String?
    
    public init(x: Float, y: Float, width: Float, height: Float, confidence: Float, label: String? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.confidence = confidence
        self.label = label
    }
}

/// Represents a segmentation mask with point coordinates.
public struct SegmentationResult {
    public let masks: [Tensor]
    public let boundingBoxes: [BoundingBox]
    public let pointCoordinates: [(x: Float, y: Float)]
    public let confidence: Float
}

/// Represents a physical trajectory for robotic or digital systems.
public struct TrajectoryVector {
    public let x: Float  // Position X
    public let y: Float  // Position Y
    public let z: Float  // Position Z
    public let grip: Float  // Grip state (0.0 = open, 1.0 = closed)
    
    public init(x: Float, y: Float, z: Float, grip: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.grip = max(0.0, min(1.0, grip))
    }
}

/// Represents a system event (keyboard, mouse, etc.).
public struct SystemEvent {
    public enum EventType {
        case mouseClick(x: Int, y: Int)
        case keyPress(String)
        case drag(fromX: Int, fromY: Int, toX: Int, toY: Int)
        case wait(milliseconds: Int)
    }
    
    public let type: EventType
    public let timestamp: Date
    
    public init(_ type: EventType) {
        self.type = type
        self.timestamp = Date()
    }
}

/// Represents an action taken by the LAM/VLA system.
public struct ActionExecutionResult {
    public let actionID: UUID
    public let eventSequence: [SystemEvent]
    public let trajectoryVector: TrajectoryVector?
    public let executionTime: TimeInterval
    public let success: Bool
    public let reasoning: String
}

/// Represents the state of a Liquid Network at a point in time.
public struct LiquidState {
    public var internalState: [Float]
    public var timestamp: Date
    
    public init(internalState: [Float]) {
        self.internalState = internalState
        self.timestamp = Date()
    }
}

/// Represents a single step in a Reinforcement Learning episode.
public struct RLStep {
    public let state: Tensor
    public let action: Int
    public let reward: Float
    public let nextState: Tensor
    public let isDone: Bool
}

/// Represents routing weights for Mixture of Experts.
public struct RouterOutput {
    public let expertIndices: [Int]
    public let weights: [Float]
    public let topK: Int
    
    public init(expertIndices: [Int], weights: [Float], topK: Int = 2) {
        self.expertIndices = expertIndices
        self.weights = weights
        self.topK = topK
    }
}

/// Vision-Language Model output.
public struct VLMOutput {
    public let description: String
    public let confidence: Float
    public let detections: [BoundingBox]
    public let reasoning: String
}

/// Diffusion pipeline intermediate state.
public struct DiffusionStep {
    public let stepNumber: Int
    public let noiseScale: Float
    public let latent: Tensor
    public let estimatedImage: Tensor?
}

/// Tabular ML prediction result.
public struct TabularPrediction {
    public let label: String
    public let probability: Float
    public let features: [String: Float]
    public let explanation: String
}

/// Protocol for any AI component that can be executed asynchronously.
public protocol AIComponent: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func execute(_ input: Input) async -> Output
}

/// Protocol for components that support streaming output.
public protocol StreamingAIComponent: AIComponent {
    associatedtype StreamOutput: Sendable
    
    func executeStreaming(_ input: Input) async -> AsyncStream<StreamOutput>
}
