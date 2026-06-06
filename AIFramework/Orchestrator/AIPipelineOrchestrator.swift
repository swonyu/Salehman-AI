import Foundation
import CoreImage

// MARK: - AI Pipeline Orchestrator

/// Central orchestrator that coordinates all AI components in a unified system.
/// Demonstrates end-to-end pipeline execution with data transformation across paradigms.
@MainActor
public final class AIPipelineOrchestrator {
    // Components
    private let vlm: VisionLanguageModel
    private let sam: SegmentAnythingModel
    private let lam: LargeActionModel
    private let vla: VisionLanguageActionModel
    private let diffusion: LatentDiffusionModel
    private let tabularML: TabularMLPipeline
    private let liquidNetwork: LiquidLearningNetwork
    private let slm: SmallLanguageModel
    private var moe: MixtureOfExperts?
    
    // State management
    private var executionLog: [String] = []
    private var pipelineState: PipelineState = .idle
    
    public enum PipelineState {
        case idle, processing, completed, error(String)
    }
    
    public init() {
        self.vlm = VisionLanguageModel()
        self.sam = SegmentAnythingModel()
        self.lam = LargeActionModel()
        self.vla = VisionLanguageActionModel()
        self.diffusion = LatentDiffusionModel()
        self.tabularML = TabularMLPipeline()
        self.liquidNetwork = LiquidLearningNetwork()
        self.slm = SmallLanguageModel()
        self.setupMixtureOfExperts()
    }
    
    // MARK: - Main Pipeline Execution
    
    public func executeEndToEnd(
        userCommand: String,
        image: CGImage,
        transactionFeatures: [String: Float]
    ) async -> PipelineExecutionResult {
        pipelineState = .processing
        executionLog.removeAll()
        
        log("=" * 60)
        log("🚀 AI PIPELINE ORCHESTRATOR — STARTING END-TO-END EXECUTION")
        log("=" * 60)
        log("User Command: '\(userCommand)'")
        log("")
        
        do {
            // Phase 1: Multimodal Understanding
            log("PHASE 1️⃣: MULTIMODAL UNDERSTANDING")
            log("-" * 40)
            let visionOutput = try await phase1Multimodal(image: image, prompt: userCommand)
            
            // Phase 2: Continuous Learning Adaptation
            log("\nPHASE 2️⃣: CONTINUOUS LEARNING & ADAPTATION")
            log("-" * 40)
            let liquidOutput = try await phase2ContinuousLearning(visualData: visionOutput.features)
            
            // Phase 3: Tabular Analysis
            log("\nPHASE 3️⃣: TABULAR ML & DECISION MAKING")
            log("-" * 40)
            let mlOutput = try await phase3TabularML(transactionFeatures: transactionFeatures)
            
            // Phase 4: Generative AI
            log("\nPHASE 4️⃣: GENERATIVE AI (DIFFUSION)")
            log("-" * 40)
            let diffusionOutput = try await phase4Generative(prompt: userCommand)
            
            // Phase 5: Action & Execution
            log("\nPHASE 5️⃣: ACTION & EXECUTION (LAM/VLA)")
            log("-" * 40)
            let actionOutput = try await phase5ActionExecution(
                command: userCommand,
                visualData: visionOutput.features
            )
            
            // Phase 6: Mixture of Experts Routing
            log("\nPHASE 6️⃣: MIXTURE OF EXPERTS ROUTING")
            log("-" * 40)
            let moeOutput = try await phase6MixtureOfExperts(input: visionOutput.tensor)
            
            // Phase 7: Small Language Model Generation
            log("\nPHASE 7️⃣: SMALL LANGUAGE MODEL GENERATION")
            log("-" * 40)
            let slmOutput = try await phase7SLMGeneration(prompt: userCommand)
            
            pipelineState = .completed
            
            let result = PipelineExecutionResult(
                success: true,
                executionTime: 0,
                phase1: visionOutput,
                phase2: liquidOutput,
                phase3: mlOutput,
                phase4: diffusionOutput,
                phase5: actionOutput,
                phase6: moeOutput,
                phase7: slmOutput,
                log: executionLog.joined(separator: "\n")
            )
            
            log("\n" + "=" * 60)
            log("✅ PIPELINE EXECUTION COMPLETED SUCCESSFULLY")
            log("=" * 60)
            
            return result
            
        } catch {
            pipelineState = .error(error.localizedDescription)
            log("\n❌ ERROR: \(error.localizedDescription)")
            return PipelineExecutionResult(
                success: false,
                executionTime: 0,
                phase1: nil,
                phase2: nil,
                phase3: nil,
                phase4: nil,
                phase5: nil,
                phase6: nil,
                phase7: nil,
                log: executionLog.joined(separator: "\n")
            )
        }
    }
    
    // MARK: - Phase Methods
    
    private func phase1Multimodal(image: CGImage, prompt: String) async throws -> Phase1Output {
        log("📸 Vision-Language Model Processing...")
        let vlmResult = await vlm.execute(VLMInput(image: image, prompt: prompt))
        log("   ✓ VLM Output: \(vlmResult.confidence > 0.5 ? "High confidence" : "Low confidence")")
        
        log("🔍 Segment Anything Model Processing...")
        let samResult = await sam.execute(SAMInput(image: image))
        log("   ✓ SAM Detected: \(samResult.boundingBoxes.count) segments")
        
        let features = Array(repeating: Float.random(in: 0...1), count: 512)
        let tensor = Tensor(data: features, shape: [1, 512])
        
        return Phase1Output(
            vlmOutput: vlmResult,
            samOutput: samResult,
            features: features,
            tensor: tensor
        )
    }
    
    private func phase2ContinuousLearning(visualData: [Float]) async throws -> Phase2Output {
        log("🌊 Liquid Learning Network Processing...")
        let inputTensor = Tensor(data: visualData, shape: [1, visualData.count])
        let liquidState = await liquidNetwork.execute(inputTensor)
        log("   ✓ Internal State Updated: \(liquidState.internalState.count) dimensions")
        
        log("🎓 Reinforcement Learning Episode...")
        var rlLoop = RLTrainingLoop(stateSize: 100)
        let episodeReward = await rlLoop.runEpisode { action in
            let nextState = Tensor(data: Array(repeating: Float(action) / 4.0, count: 10), shape: [1, 10])
            return RLStep(
                state: Tensor(data: visualData.prefix(10).map { Float($0) }, shape: [1, 10]),
                action: action,
                reward: Float.random(in: 0...1),
                nextState: nextState,
                isDone: false
            )
        }
        log("   ✓ Episode Reward: \(String(format: "%.2f", episodeReward))")
        
        return Phase2Output(
            liquidState: liquidState,
            rlEpisodeReward: episodeReward
        )
    }
    
    private func phase3TabularML(transactionFeatures: [String: Float]) async throws -> Phase3Output {
        log("💳 Tabular ML Pipeline (Fraud Detection)...")
        let prediction = await tabularML.execute(TabularInput(features: transactionFeatures))
        log("   ✓ Fraud Prediction: \(prediction.label) (confidence: \(String(format: "%.1f%%", prediction.probability * 100)))")
        
        return Phase3Output(prediction: prediction)
    }
    
    private func phase4Generative(prompt: String) async throws -> Phase4Output {
        log("🎨 Latent Diffusion Model (Text-to-Image)...")
        let steps = await diffusion.execute(DiffusionInput(prompt: prompt))
        log("   ✓ Diffusion Steps: \(steps.count)/50 completed")
        if let lastStep = steps.last, let image = lastStep.estimatedImage {
            log("   ✓ Final image tensor: \(image.flatCount) elements")
        }
        
        return Phase4Output(diffusionSteps: steps)
    }
    
    private func phase5ActionExecution(command: String, visualData: [Float]) async throws -> Phase5Output {
        log("🎯 Large Action Model Processing...")
        let lamResult = await lam.execute(LAMInput(objective: command))
        log("   ✓ Generated Event Sequence: \(lamResult.eventSequence.count) events")
        log("   ✓ Execution Time: \(String(format: "%.2f", lamResult.executionTime))s")
        
        log("🤖 Vision-Language-Action Model Processing...")
        let vlaResult = await vla.execute(VLAInput(command: command, visualData: visualData))
        if let trajectory = vlaResult.trajectoryVector {
            log("   ✓ Generated Trajectory: (\(String(format: "%.2f", trajectory.x)), \(String(format: "%.2f", trajectory.y)), \(String(format: "%.2f", trajectory.z)))")
            log("   ✓ Grip State: \(String(format: "%.1f%%", trajectory.grip * 100))")
        }
        
        return Phase5Output(lamResult: lamResult, vlaResult: vlaResult)
    }
    
    private func phase6MixtureOfExperts(input: Tensor) async throws -> Phase6Output {
        guard let moe = moe else { throw PipelineError.moeNotInitialized }
        
        log("🧠 Mixture of Experts Routing...")
        let moeOutput = await moe.execute(input)
        log("   ✓ MoE Output Shape: \(moeOutput.shape)")
        log("   ✓ Combined Expert Outputs: \(moeOutput.flatCount) elements")
        
        return Phase6Output(moeOutput: moeOutput)
    }
    
    private func phase7SLMGeneration(prompt: String) async throws -> Phase7Output {
        log("📝 Small Language Model Generation...")
        let slmOutput = await slm.generate(prompt: prompt, maxTokens: 20)
        log("   ✓ Generated Text: '\(slmOutput)'")
        
        return Phase7Output(generatedText: slmOutput)
    }
    
    // MARK: - Setup & Utility
    
    private func setupMixtureOfExperts() {
        let experts: [String: MixtureOfExperts.AIExpertClosure] = [
            "vision_expert": { tensor in
                tensor.map { $0 * 0.5 }
            },
            "reasoning_expert": { tensor in
                tensor.map { value in
                    let normalized = value / (sqrt(tensor.data.reduce(0) { $0 + $1 * $1 }) + 0.001)
                    return tanh(normalized)
                }
            },
            "action_expert": { tensor in
                tensor.map { value in
                    max(-1.0, min(1.0, value * 2.0))
                }
            }
        ]
        
        self.moe = MixtureOfExperts(experts: experts)
    }
    
    private func log(_ message: String) {
        print(message)
        executionLog.append(message)
    }
    
    private func tanh(_ x: Float) -> Float {
        let expX = exp(x)
        let expNegX = exp(-x)
        return (expX - expNegX) / (expX + expNegX)
    }
}

extension String {
    fileprivate static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

// MARK: - Output Types

public struct Phase1Output: Sendable {
    public let vlmOutput: VLMOutput
    public let samOutput: SegmentationResult
    public let features: [Float]
    public let tensor: Tensor
}

public struct Phase2Output: Sendable {
    public let liquidState: LiquidState
    public let rlEpisodeReward: Float
}

public struct Phase3Output: Sendable {
    public let prediction: TabularPrediction
}

public struct Phase4Output: Sendable {
    public let diffusionSteps: [DiffusionStep]
}

public struct Phase5Output: Sendable {
    public let lamResult: ActionExecutionResult
    public let vlaResult: ActionExecutionResult
}

public struct Phase6Output: Sendable {
    public let moeOutput: Tensor
}

public struct Phase7Output: Sendable {
    public let generatedText: String
}

public struct PipelineExecutionResult: Sendable {
    public let success: Bool
    public let executionTime: TimeInterval
    public let phase1: Phase1Output?
    public let phase2: Phase2Output?
    public let phase3: Phase3Output?
    public let phase4: Phase4Output?
    public let phase5: Phase5Output?
    public let phase6: Phase6Output?
    public let phase7: Phase7Output?
    public let log: String
}

// MARK: - Error Types

public enum PipelineError: Error, Sendable {
    case moeNotInitialized
    case invalidInput
    case processingFailed(String)
}
