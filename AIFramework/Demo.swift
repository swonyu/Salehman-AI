import Foundation
import CoreImage
import AppKit

// MARK: - Main Execution Entry Point

@main
struct AIFrameworkDemo {
    static func main() async {
        print("""
        
        ╔════════════════════════════════════════════════════════════╗
        ║  UNIFIED MULTIMODAL AI FRAMEWORK DEMONSTRATION            ║
        ║  Advanced AI Paradigms: Vision, Action, Learning & More   ║
        ╚════════════════════════════════════════════════════════════╝
        
        """)
        
        // Initialize the orchestrator
        let orchestrator = AIPipelineOrchestrator()
        
        // Create a sample image (gradient for demonstration)
        guard let sampleImage = createSampleImage() else {
            print("❌ Failed to create sample image")
            return
        }
        
        // Define a complex user command
        let userCommand = "Analyze the image, detect objects, and execute a task to move forward and grasp the object"
        
        // Define transaction features for fraud detection
        let transactionFeatures: [String: Float] = [
            "transaction_amount": 2500.0,
            "transaction_velocity": 2.5,
            "merchant_risk_score": 0.35,
            "time_of_day": 14.5,
            "device_risk": 0.2
        ]
        
        print("🔧 INPUT CONFIGURATION:")
        print("   User Command: '\(userCommand)'")
        print("   Sample Image: 512×512 gradient")
        print("   Transaction Amount: $\(Int(transactionFeatures["transaction_amount"] ?? 0))")
        print("")
        
        // Execute the full pipeline
        let result = await orchestrator.executeEndToEnd(
            userCommand: userCommand,
            image: sampleImage,
            transactionFeatures: transactionFeatures
        )
        
        // Print detailed results
        print("""
        
        
        ╔════════════════════════════════════════════════════════════╗
        ║  DETAILED PIPELINE RESULTS                                ║
        ╚════════════════════════════════════════════════════════════╝
        
        """)
        
        if let phase1 = result.phase1 {
            print("📊 PHASE 1 — MULTIMODAL VISION")
            print("   VLM Confidence: \(String(format: "%.1f%%", phase1.vlmOutput.confidence * 100))")
            print("   VLM Description: \(phase1.vlmOutput.description.split(separator: "\n").first ?? "")")
            print("   SAM Detections: \(phase1.samOutput.boundingBoxes.count) segments")
            print("   Feature Vector Dimension: \(phase1.features.count)")
            print("")
        }
        
        if let phase2 = result.phase2 {
            print("🌊 PHASE 2 — CONTINUOUS LEARNING")
            print("   Liquid Network State Dimension: \(phase2.liquidState.internalState.count)")
            print("   RL Episode Reward: \(String(format: "%.3f", phase2.rlEpisodeReward))")
            print("")
        }
        
        if let phase3 = result.phase3 {
            print("💳 PHASE 3 — TABULAR ML (FRAUD DETECTION)")
            print("   Classification: \(phase3.prediction.label)")
            print("   Confidence: \(String(format: "%.1f%%", phase3.prediction.probability * 100))")
            print("   " + phase3.prediction.explanation.split(separator: "\n").first ?? "")
            print("")
        }
        
        if let phase4 = result.phase4 {
            print("🎨 PHASE 4 — GENERATIVE AI (DIFFUSION)")
            print("   Total Diffusion Steps: \(phase4.diffusionSteps.count)")
            if let lastStep = phase4.diffusionSteps.last {
                print("   Final Noise Scale: \(String(format: "%.3f", lastStep.noiseScale))")
                if let image = lastStep.estimatedImage {
                    print("   Final Image Tensor: \(image.flatCount) elements")
                }
            }
            print("")
        }
        
        if let phase5 = result.phase5 {
            print("⚙️ PHASE 5 — ACTION & EXECUTION")
            print("   LAM Status: \(phase5.lamResult.success ? "✓ Success" : "✗ Failed")")
            print("   LAM Events Generated: \(phase5.lamResult.eventSequence.count)")
            print("   LAM Execution Time: \(String(format: "%.2f", phase5.lamResult.executionTime))s")
            if let trajectory = phase5.vlaResult.trajectoryVector {
                print("   VLA Trajectory: x=\(String(format: "%.2f", trajectory.x)), y=\(String(format: "%.2f", trajectory.y)), z=\(String(format: "%.2f", trajectory.z))")
                print("   VLA Grip State: \(String(format: "%.0f%%", trajectory.grip * 100))")
            }
            print("")
        }
        
        if let phase6 = result.phase6 {
            print("🧠 PHASE 6 — MIXTURE OF EXPERTS")
            print("   MoE Output Shape: \(phase6.moeOutput.shape)")
            print("   MoE Combined Output Elements: \(phase6.moeOutput.flatCount)")
            print("")
        }
        
        if let phase7 = result.phase7 {
            print("📝 PHASE 7 — SMALL LANGUAGE MODEL")
            print("   Generated Text: '\(phase7.generatedText.prefix(100))...'")
            print("")
        }
        
        print("""
        
        ╔════════════════════════════════════════════════════════════╗
        ║  EXECUTION SUMMARY                                        ║
        ╚════════════════════════════════════════════════════════════╝
        
        """)
        print("Status: \(result.success ? "✅ SUCCESS" : "❌ FAILED")")
        print("Total Phases Executed: 7/7")
        print("")
        print("📋 Full Execution Log:")
        print("—" * 60)
        print(result.log)
        print("—" * 60)
        
        print("""
        
        ✨ FRAMEWORK CAPABILITIES DEMONSTRATED:
        
        1️⃣ MULTIMODAL AI
           • Vision-Language Model (VLM) with image-text alignment
           • Segment Anything Model (SAM) for object segmentation
        
        2️⃣ ACTION & DECISION AI
           • Large Action Model (LAM) for task decomposition & execution
           • Vision-Language-Action (VLA) for trajectory planning
        
        3️⃣ SPECIALIZED & GENERATIVE AI
           • Latent Diffusion Model for text-to-image generation
           • Tabular ML for fraud detection & classification
        
        4️⃣ CONTINUOUS LEARNING
           • Liquid Learning Networks for adaptive state management
           • Reinforcement Learning with Q-learning updates
           • Mixture of Experts for dynamic routing
           • Small Language Models for on-device generation
        
        5️⃣ UNIFIED ORCHESTRATOR
           • End-to-end pipeline coordination
           • Structured concurrency (async/await)
           • Component modularity and composability
        
        All components integrate seamlessly using Swift 6 protocols,
        structured concurrency, and native Apple frameworks.
        
        """)
    }
    
    // MARK: - Helper Functions
    
    private static func createSampleImage() -> CGImage? {
        let size = CGSize(width: 512, height: 512)
        let rect = CGRect(origin: .zero, size: size)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // Create gradient: blue to red
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                let progress = Float(x) / Float(size.width)
                let r = UInt8(progress * 255)
                let g = UInt8((1.0 - progress) * 128)
                let b = UInt8((1.0 - progress) * 255)
                let a: UInt8 = 255
                
                let offset = (y * Int(size.width) + x) * 4
                let data = context.data!.assumingMemoryBound(to: UInt8.self)
                data[offset] = r
                data[offset + 1] = g
                data[offset + 2] = b
                data[offset + 3] = a
            }
        }
        
        return context.makeImage()
    }
}

// Helper for string repetition
extension String {
    fileprivate static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
