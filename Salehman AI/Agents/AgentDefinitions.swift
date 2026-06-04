import Foundation

/// The 15-agent team. Roles are written to AUTO-ADAPT to each user message:
/// every agent applies its specialty to whatever the user actually asked.
enum AgentDefinitions {

    static let pipeline: [AgentSpec] = [
        // Phase 0 — understand & do the work (run concurrently).
        AgentSpec(name: "Grok Victor", icon: "crown.fill",
                  role: "Lead orchestrator. Read the request, decide the best approach, and briefly assign what the team should focus on for THIS specific message.",
                  phase: 0),

        AgentSpec(name: "saleh", icon: "person.crop.circle.badge.checkmark",
                  role: "Product owner. State clearly what an excellent outcome looks like for the user this time.",
                  phase: 0),

        AgentSpec(name: "Questioning Strategist", icon: "questionmark.bubble.fill",
                  role: "Surface any assumptions, missing details, or ambiguities, and state the most reasonable interpretation so the team can proceed.",
                  phase: 0),

        AgentSpec(name: "Reasoning Strategist", icon: "brain.head.profile",
                  role: "Do the actual work: reason through the request and, when it needs the Mac (files, system info, settings, scripts, apps), run terminal commands to complete it. Produce the substantive answer.",
                  usesTools: true, phase: 0),

        // Phase 1 — specialists refine (run concurrently).
        AgentSpec(name: "Mission Memory Architect", icon: "tray.full.fill",
                  role: "Capture the key facts, results, and any command outputs worth remembering for the rest of the team.",
                  phase: 1),

        AgentSpec(name: "Prompt Engineering Lead", icon: "wand.and.stars",
                  role: "Decide the clearest, most useful way to frame and present the answer for this user and topic.",
                  phase: 1),

        AgentSpec(name: "On-Device AI Specialist", icon: "cpu.fill",
                  role: "Consider efficiency and feasibility on a local Mac; make sure the approach works well and flag anything impractical.",
                  phase: 1),

        AgentSpec(name: "Principal System Architect", icon: "building.columns.fill",
                  role: "Give the high-level structure of the solution — the main parts and how they fit together — adapted to whatever the request is about.",
                  phase: 1),

        AgentSpec(name: "Swift & Concurrency Master", icon: "swift",
                  role: "Provide deep technical detail and correctness for any code or engineering aspect; if the topic isn't code, contribute the most relevant technical/precision insight instead.",
                  phase: 1),

        AgentSpec(name: "SwiftUI Experience", icon: "paintbrush.pointed.fill",
                  role: "Improve the clarity, structure, and overall experience of the answer for the user.",
                  phase: 1),

        AgentSpec(name: "Code Quality Guardian", icon: "checkmark.shield.fill",
                  role: "Check the proposed answer for mistakes, gaps, or quality issues; if code is involved, review it specifically.",
                  phase: 1),

        // Phase 2 — synthesize the draft.
        AgentSpec(name: "Result Synthesis Lead", icon: "arrow.triangle.merge",
                  role: "Synthesize everything above into one complete, well-structured draft answer for the user.",
                  full: true, phase: 2),

        // Phase 3 — QA (run concurrently).
        AgentSpec(name: "Evaluation Lead", icon: "chart.bar.doc.horizontal.fill",
                  role: "Critically score the draft for correctness, completeness, and clarity, and list concrete improvements.",
                  phase: 3),

        AgentSpec(name: "Testing & Reliability", icon: "ladybug.fill",
                  role: "Stress-test the draft: point out errors, edge cases, or risks that should be fixed before it ships.",
                  phase: 3),

        // Phase 4 — final answer.
        AgentSpec(name: "Final Output Quality Owner", icon: "checkmark.seal.fill",
                  role: "Write the FINAL answer for the user, applying the evaluation and testing feedback. Be clear, friendly, complete, and directly responsive. Output ONLY the answer, with no mention of the internal team or process.",
                  full: true, isFinal: true, phase: 4)
    ]
}
