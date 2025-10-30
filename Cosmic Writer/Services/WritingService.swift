//
//  WritingService.swift
//  Cosmic Writer
//
//  Shared AI writing service for both iOS and macOS
//

import Foundation
import CosmicSDK
import FoundationModels

class WritingService: ObservableObject {
    var writingExamples: [String] = []

    private(set) var bucket: String
    private(set) var readKey: String

    init(bucket: String, readKey: String) {
        self.bucket = bucket
        self.readKey = readKey
    }

    func updateConfig(bucket: String, readKey: String) {
        self.bucket = bucket
        self.readKey = readKey
    }

    // MARK: - Instructions

    var instructions: String {
        var baseInstructions = """
        You write as Karl Emil James Koch. Produce clear, compelling prose centred on product development and the pragmatic use of AI, with design–engineering overlap only when it genuinely adds value.

        Style and tone:
        - Conversational, direct, and grounded in real experience
        - British English spelling and terminology ALWAYS (e.g., colour, centre, organisation, analyse, realise, programme, theatre, labour, defence, offence, licence, practice/practise, etc.)
        - Active voice; varied sentence length
        - Prefer specifics over abstractions; show, don't just tell
        - Use lists only when they improve clarity; avoid formal headings unless already present or explicitly requested
        - AVOID clichéd openings like "In the ever-evolving landscape of..." or "stands as a testament to..."
        - Start with concrete observations, questions, or direct statements
        - NO generic business speak or buzzwords
        - NEVER use the word "User" except when specifically discussing UX/UI contexts
        - Instead say: "people", "someone", "you", "they", "humans", "individuals", or the specific role (e.g., "designers", "developers")
        - Example: DON'T say "Users can access..." - DO say "People can access..." or "You can access..."

        Approach:
        1) Identify the core idea and tighten the narrative around it.
        2) Improve clarity and flow; remove filler and repetition.
        3) Preserve the author's voice and intent; maintain existing structure unless it clearly harms readability.
        4) Keep length similar unless brevity improves quality.

        Reliability:
        - Do not invent facts, quotes, links, or statistics.
        - If a claim is uncertain, keep it qualitative or mark it for verification like [verify].
        - Keep code or technical details honest and minimal.

        Output requirements:
        - Markdown only, no preambles or explanations.
        - No front matter, metadata, or headings unless present in the draft or explicitly requested.
        - Maintain the author's established perspective and voice.
        - NEVER use American English spellings or terminology.
        """

        // Add writing examples if available
        if !writingExamples.isEmpty {
            baseInstructions += """


            WRITING STYLE REFERENCE ONLY (DO NOT copy content, topics, or ideas from these examples):
            The following excerpts demonstrate the author's writing style, sentence structure, and tone.
            Use them ONLY to understand HOW the author writes, NOT WHAT they write about.
            DO NOT reference or copy any subject matter, topics, or specific content from these examples.

            """
            for (index, example) in writingExamples.enumerated() {
                baseInstructions += "Style example \(index + 1) (for style reference only):\n\(example)\n\n"
            }
        }

        return baseInstructions
    }

    // MARK: - Load Writing Examples

    func loadWritingExamples() {
        guard !bucket.isEmpty && !readKey.isEmpty else {
            print("WritingService: Missing bucket or read key")
            return
        }

        let cosmic = CosmicSDKSwift(.createBucketClient(bucketSlug: bucket, readKey: readKey, writeKey: ""))

        cosmic.find(type: "writings",
                    props: "id,title,slug,metadata",
                    limit: 100,
                    status: .published
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    print("DEBUG: WritingService fetched \(response.objects.count) objects")

                    // Get random posts - DON'T filter by type since we already filtered in the query
                    let randomSlugs = response.objects
                        .shuffled()
                        .prefix(3)
                        .compactMap { $0.slug }

                    print("DEBUG: WritingService random slugs: \(randomSlugs)")

                    // Clear existing examples
                    self.writingExamples = []

                    // Extract content from metadata
                    let objectsToProcess = randomSlugs.compactMap({ slug in response.objects.first(where: { $0.slug == slug }) })

                    for object in objectsToProcess {
                        if let metadata = object.metadata,
                           let content = metadata.content.string, !content.isEmpty {
                            let firstParagraph = content.components(separatedBy: "\n\n").first ?? content
                            let excerpt = String(firstParagraph.prefix(400)).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !excerpt.isEmpty {
                                self.writingExamples.append(excerpt)
                                print("DEBUG: WritingService loaded example from \(object.slug ?? "unknown")")
                            }
                        }
                    }

                    print("DEBUG: WritingService total examples loaded: \(self.writingExamples.count)")

                case .failure(let error):
                    print("WritingService: Failed to load writing examples: \(error)")
                }
            }
        }
    }
}
