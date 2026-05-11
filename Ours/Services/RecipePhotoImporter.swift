import CoreImage
import Foundation
import UIKit
import Vision

enum RecipePhotoImporter {

    static func importFrom(imageData: Data) async throws -> RecipeDraft {
        guard let image = UIImage(data: imageData) else { throw RecipeImportError.nothingUseful }
        guard let cgImage = cgImage(from: image) else { throw RecipeImportError.nothingUseful }

        let text = try await recognizeText(in: cgImage)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecipeImportError.nothingUseful
        }

        let parsed = RecipeIngredientParser.parse(text)
        let inferredTitle = inferTitle(from: text)

        guard !parsed.ingredients.isEmpty || !parsed.instructions.isEmpty else {
            return RecipeDraft(
                name: inferredTitle,
                instructions: text,
                ingredients: [],
                iconHint: nil,
                sourceURL: nil
            )
        }

        return RecipeDraft(
            name: inferredTitle,
            instructions: parsed.instructions,
            ingredients: parsed.ingredients,
            iconHint: nil,
            sourceURL: nil
        )
    }

    // MARK: - Image normalization

    private static func cgImage(from image: UIImage) -> CGImage? {
        if let cg = image.cgImage { return cg }
        guard let ci = CIImage(image: image) else { return nil }
        return CIContext().createCGImage(ci, from: ci.extent)
    }

    // MARK: - Vision

    private static func recognizeText(in cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNRecognizeTextRequest { req, error in
                if let error { continuation.resume(throwing: error); return }
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ""); return
                }
                let lines = observations
                    .sorted { lhs, rhs in
                        let dy = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
                        if dy < 0.012 { return lhs.boundingBox.midX < rhs.boundingBox.midX }
                        return lhs.boundingBox.midY > rhs.boundingBox.midY
                    }
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["sv-SE", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    // MARK: - Title heuristic

    private static func inferTitle(from text: String) -> String {
        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return "" }
        if first.count <= 60 && !first.contains(":") {
            return first
        }
        return ""
    }
}
