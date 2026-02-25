import Foundation
import UIKit
import Vision
import CoreImage

// MARK: - Result Types

struct LocalImageScanResult {
    var suspicionFlags: [ImageSuspicionFlag]
    var overallScore: Double        // 0.0 - 1.0
    var riskLevel: RiskLevel
    var summary: String
    var recommendation: String
}

struct ImageSuspicionFlag: Identifiable {
    let id = UUID()
    let type: ImageCheckType
    let finding: String             // Human-readable description
    let suspicionLevel: Double      // 0.0 - 1.0
}

enum ImageCheckType: String, CaseIterable {
    case faceSymmetry
    case backgroundConsistency
    case colorDistribution
    case textureUniformity
    case sharpnessPattern

    var displayName: String {
        switch self {
        case .faceSymmetry: return "Face Symmetry"
        case .backgroundConsistency: return "Background Consistency"
        case .colorDistribution: return "Color Distribution"
        case .textureUniformity: return "Texture Uniformity"
        case .sharpnessPattern: return "Sharpness Pattern"
        }
    }

    var weight: Double {
        switch self {
        case .faceSymmetry: return 1.5           // Reduced — selfies are naturally symmetric
        case .backgroundConsistency: return 1.0  // Weak — phone cameras have deep DOF naturally
        case .colorDistribution: return 1.0
        case .textureUniformity: return 1.2
        case .sharpnessPattern: return 0.8       // Weak — computational photography produces uniform sharpness
        }
    }
}

// MARK: - Analyzer

struct LocalImageAnalyzer {
    private let ciContext = CIContext()
    private let maxDimension: CGFloat = 1024

    func analyze(_ image: UIImage) async -> LocalImageScanResult {
        let scaled = downscale(image)

        // Run all checks concurrently
        async let faceFlag = checkFaceSymmetry(scaled)
        async let bgFlag = checkBackgroundConsistency(scaled)
        async let colorFlag = checkColorDistribution(scaled)
        async let textureFlag = checkTextureUniformity(scaled)
        async let sharpnessFlag = checkSharpnessPatterns(scaled)

        let results = await [faceFlag, bgFlag, colorFlag, textureFlag, sharpnessFlag]
        let flags = results.compactMap { $0 }

        let score = calculateWeightedScore(flags)
        let riskLevel = riskLevelFromScore(score)
        let summary = buildSummary(flags: flags, riskLevel: riskLevel)
        let recommendation = buildRecommendation(riskLevel: riskLevel)

        return LocalImageScanResult(
            suspicionFlags: flags,
            overallScore: score,
            riskLevel: riskLevel,
            summary: summary,
            recommendation: recommendation
        )
    }

    // MARK: - Image Scaling

    private func downscale(_ image: UIImage) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }



    // MARK: - Check 2: Face Symmetry

    private func checkFaceSymmetry(_ image: UIImage) async -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results,
              let face = results.first,
              let landmarks = face.landmarks else {
            return nil // No face detected — can't assess symmetry
        }

        // Compare left vs right eye sizes and positions
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye,
              let nose = landmarks.noseCrest else {
            return nil
        }

        let leftEyePoints = leftEye.normalizedPoints
        let rightEyePoints = rightEye.normalizedPoints
        let nosePoints = nose.normalizedPoints

        guard !leftEyePoints.isEmpty, !rightEyePoints.isEmpty, !nosePoints.isEmpty else {
            return nil
        }

        // Calculate eye center positions
        let leftCenter = centroid(of: leftEyePoints)
        let rightCenter = centroid(of: rightEyePoints)
        let noseMid = centroid(of: nosePoints)

        // Measure distance from each eye center to nose midline
        let leftDist = distance(leftCenter, noseMid)
        let rightDist = distance(rightCenter, noseMid)

        guard leftDist > 0, rightDist > 0 else { return nil }

        // Symmetry ratio: 1.0 = perfectly symmetric
        let symmetryRatio = min(leftDist, rightDist) / max(leftDist, rightDist)

        // Also check eye size symmetry
        let leftEyeSpread = eyeSpread(leftEyePoints)
        let rightEyeSpread = eyeSpread(rightEyePoints)
        let sizeRatio: Double
        if leftEyeSpread > 0 && rightEyeSpread > 0 {
            sizeRatio = min(leftEyeSpread, rightEyeSpread) / max(leftEyeSpread, rightEyeSpread)
        } else {
            sizeRatio = 0.5
        }

        // Combined symmetry score — very high symmetry is suspicious
        let combinedSymmetry = (symmetryRatio + sizeRatio) / 2.0

        // Natural faces typically have 0.85-0.95 symmetry
        // AI faces often have >0.99 — only flag near-perfect symmetry
        // Real selfies (front-facing, arm's length) routinely hit 0.97-0.98
        if combinedSymmetry > 0.985 {
            return ImageSuspicionFlag(
                type: .faceSymmetry,
                finding: "Face shows unusually high bilateral symmetry (\(Int(combinedSymmetry * 100))%) — common in AI-generated faces",
                suspicionLevel: min((combinedSymmetry - 0.985) * 20.0 + 0.3, 0.7)
            )
        }

        return nil
    }

    // MARK: - Check 3: Background Consistency

    private func checkBackgroundConsistency(_ image: UIImage) -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        let width = ciImage.extent.width
        let height = ciImage.extent.height

        // Split image into quadrants and measure sharpness in each
        let quadrants: [(String, CGRect)] = [
            ("top-left", CGRect(x: 0, y: height / 2, width: width / 2, height: height / 2)),
            ("top-right", CGRect(x: width / 2, y: height / 2, width: width / 2, height: height / 2)),
            ("bottom-left", CGRect(x: 0, y: 0, width: width / 2, height: height / 2)),
            ("bottom-right", CGRect(x: width / 2, y: 0, width: width / 2, height: height / 2))
        ]

        var sharpnessValues: [Double] = []

        for (_, rect) in quadrants {
            let cropped = ciImage.cropped(to: rect)
            if let sharpness = measureSharpness(cropped) {
                sharpnessValues.append(sharpness)
            }
        }

        guard sharpnessValues.count >= 4 else { return nil }

        let mean = sharpnessValues.reduce(0, +) / Double(sharpnessValues.count)
        guard mean > 0 else { return nil }

        // Coefficient of variation — how much sharpness varies across quadrants
        let variance = sharpnessValues.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(sharpnessValues.count)
        let cv = sqrt(variance) / mean

        // AI images often have unnaturally uniform sharpness (low CV)
        // Real photos with depth-of-field have higher CV
        // Note: modern phone cameras with computational photography naturally produce
        // uniform sharpness, so this threshold must be conservative
        if cv < 0.08 && mean > 5.0 {
            return ImageSuspicionFlag(
                type: .backgroundConsistency,
                finding: "Unnaturally uniform sharpness across the image — real photos typically show depth-of-field variation",
                suspicionLevel: max(0.2, 0.45 - cv * 3.0)
            )
        }

        return nil
    }

    // MARK: - Check 4: Color Distribution

    private func checkColorDistribution(_ image: UIImage) -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // Get histogram using CIAreaHistogram
        guard let histogramFilter = CIFilter(name: "CIAreaHistogram") else { return nil }
        histogramFilter.setValue(ciImage, forKey: kCIInputImageKey)
        histogramFilter.setValue(CIVector(cgRect: ciImage.extent), forKey: "inputExtent")
        histogramFilter.setValue(64, forKey: "inputCount") // 64 bins
        histogramFilter.setValue(1.0, forKey: "inputScale")

        guard let histOutput = histogramFilter.outputImage else { return nil }

        // Render histogram to pixel data
        var bitmap = [UInt8](repeating: 0, count: 64 * 4) // 64 bins, RGBA
        ciContext.render(
            histOutput,
            toBitmap: &bitmap,
            rowBytes: 64 * 4,
            bounds: CGRect(x: 0, y: 0, width: 64, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Extract red channel values as histogram
        var values: [Double] = []
        for i in 0..<64 {
            values.append(Double(bitmap[i * 4])) // Red channel
        }

        guard !values.isEmpty else { return nil }

        let total = values.reduce(0, +)
        guard total > 0 else { return nil }

        // Normalize
        let normalized = values.map { $0 / total }

        // Calculate entropy — AI images tend toward smoother, lower-entropy distributions
        var entropy: Double = 0
        for p in normalized where p > 0 {
            entropy -= p * log2(p)
        }

        // Very low entropy suggests overly uniform color distribution
        // Typical photos: entropy 4.5-5.8, AI images often: 3.5-4.5
        if entropy < 3.8 {
            return ImageSuspicionFlag(
                type: .colorDistribution,
                finding: "Color distribution is unusually uniform — AI-generated images often show smoother color gradients",
                suspicionLevel: max(0.3, (4.0 - entropy) * 0.5)
            )
        }

        return nil
    }

    // MARK: - Check 5: Texture Uniformity

    private func checkTextureUniformity(_ image: UIImage) -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // Apply edge detection
        guard let edgesFilter = CIFilter(name: "CIEdges") else { return nil }
        edgesFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgesFilter.setValue(1.0, forKey: kCIInputIntensityKey)

        guard let edgeOutput = edgesFilter.outputImage else { return nil }

        // Measure average edge intensity across regions
        let width = ciImage.extent.width
        let height = ciImage.extent.height

        // Sample center region (where face/subject typically is) vs periphery
        let centerRect = CGRect(
            x: width * 0.25, y: height * 0.25,
            width: width * 0.5, height: height * 0.5
        )
        let fullRect = ciImage.extent

        guard let centerEdge = measureAverageIntensity(edgeOutput, in: centerRect),
              let fullEdge = measureAverageIntensity(edgeOutput, in: fullRect) else {
            return nil
        }

        guard fullEdge > 0 else { return nil }

        // AI images often have very low edge density (smooth textures)
        // Only flag at very low thresholds to avoid false positives on soft-lit portraits
        if fullEdge < 0.03 {
            return ImageSuspicionFlag(
                type: .textureUniformity,
                finding: "Very low texture detail detected — AI-generated images often show unnaturally smooth surfaces",
                suspicionLevel: max(0.25, (0.05 - fullEdge) * 6.0)
            )
        }

        // Check if center and full have very similar edge density — only flag when
        // the similarity is extreme (the previous 0.85-1.15 range was too broad and
        // caught many well-lit real photos)
        let ratio = centerEdge / fullEdge
        if ratio > 0.93 && ratio < 1.07 && fullEdge > 0.02 && fullEdge < 0.08 {
            return ImageSuspicionFlag(
                type: .textureUniformity,
                finding: "Texture complexity is unusually consistent between subject and background",
                suspicionLevel: 0.2
            )
        }

        return nil
    }

    // MARK: - Check 6: Sharpness Patterns

    private func checkSharpnessPatterns(_ image: UIImage) -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        let width = ciImage.extent.width
        let height = ciImage.extent.height

        // Create a 3x3 grid and measure sharpness in each cell
        let cols = 3
        let rows = 3
        let cellWidth = width / CGFloat(cols)
        let cellHeight = height / CGFloat(rows)

        var gridSharpness: [Double] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(
                    x: CGFloat(col) * cellWidth,
                    y: CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                let cropped = ciImage.cropped(to: rect)
                if let sharpness = measureSharpness(cropped) {
                    gridSharpness.append(sharpness)
                }
            }
        }

        guard gridSharpness.count >= 9 else { return nil }

        let mean = gridSharpness.reduce(0, +) / Double(gridSharpness.count)
        guard mean > 0 else { return nil }

        let variance = gridSharpness.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(gridSharpness.count)
        let cv = sqrt(variance) / mean

        // Natural photos with bokeh/depth typically have CV > 0.3
        // AI images with uniform sharpness have CV < 0.1
        // Note: phone cameras with small sensors produce deep DOF naturally,
        // so only flag at very low CV values
        if cv < 0.04 && mean > 3.0 {
            return ImageSuspicionFlag(
                type: .sharpnessPattern,
                finding: "Sharpness is unnaturally consistent across the entire image — natural photos show focal depth variation",
                suspicionLevel: max(0.2, 0.4 - cv * 5.0)
            )
        }

        return nil
    }

    // MARK: - Scoring

    private func calculateWeightedScore(_ flags: [ImageSuspicionFlag]) -> Double {
        guard !flags.isEmpty else { return 0.0 }

        let totalWeight = ImageCheckType.allCases.reduce(0.0) { $0 + $1.weight }
        var weightedSum: Double = 0

        for flag in flags {
            weightedSum += flag.suspicionLevel * flag.type.weight
        }

        var score = weightedSum / totalWeight

        // No co-occurrence or face+other bonuses — let the weighted average
        // speak for itself. Compound multipliers inflated weak signals into
        // false positives on normal selfies.

        return min(1.0, max(0.0, score))
    }

    private func riskLevelFromScore(_ score: Double) -> RiskLevel {
        switch score {
        case ..<0.25: return .low
        case 0.25..<0.50: return .medium
        case 0.50..<0.75: return .high
        default: return .critical     // Only flag critical when evidence is strong
        }
    }

    // MARK: - Summary & Recommendation

    private func buildSummary(flags: [ImageSuspicionFlag], riskLevel: RiskLevel) -> String {
        if flags.isEmpty {
            return "On-device analysis found no obvious signs of AI generation. The image passed all heuristic checks."
        }

        let flagDescriptions = flags.map { $0.type.displayName }
        let joined = flagDescriptions.joined(separator: ", ")

        switch riskLevel {
        case .low:
            return "Minor indicators detected (\(joined)), but overall the image appears genuine."
        case .medium:
            return "Some suspicious characteristics found: \(joined). The image may warrant further investigation."
        case .high:
            return "Multiple AI indicators detected: \(joined). This image shows significant signs of being AI-generated."
        case .critical:
            return "Strong AI generation indicators found across multiple checks: \(joined). This image is very likely AI-generated."
        }
    }

    private func buildRecommendation(riskLevel: RiskLevel) -> String {
        switch riskLevel {
        case .low:
            return "The image passed on-device checks. For higher confidence, enable Reality Defender API analysis in Settings. Always verify identities through video calls."
        case .medium:
            return "Some potential AI indicators were found. We recommend verifying this person's identity through a live video call. Enable Reality Defender API for more accurate analysis."
        case .high:
            return "This image shows multiple signs of AI generation. Do not trust this profile photo. Request a live video call and reverse image search the photo independently."
        case .critical:
            return "This image is very likely AI-generated. Do not share personal or financial information with this person. Report the profile to the platform."
        }
    }

    // MARK: - Helpers

    private func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sumX = points.map(\.x).reduce(0, +)
        let sumY = points.map(\.y).reduce(0, +)
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x)
        let dy = Double(a.y - b.y)
        return sqrt(dx * dx + dy * dy)
    }

    private func eyeSpread(_ points: [CGPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let dx = Double((xs.max() ?? 0) - (xs.min() ?? 0))
        let dy = Double((ys.max() ?? 0) - (ys.min() ?? 0))
        return sqrt(dx * dx + dy * dy)
    }

    /// Measure sharpness of a CIImage region using the Laplacian variance method
    private func measureSharpness(_ ciImage: CIImage) -> Double? {
        // Convert to grayscale
        guard let grayFilter = CIFilter(name: "CIColorControls") else { return nil }
        grayFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayFilter.setValue(0.0, forKey: kCIInputSaturationKey)

        guard let grayImage = grayFilter.outputImage else { return nil }

        // Apply edge detection as a proxy for Laplacian
        guard let edgesFilter = CIFilter(name: "CIEdges") else { return nil }
        edgesFilter.setValue(grayImage, forKey: kCIInputImageKey)
        edgesFilter.setValue(1.0, forKey: kCIInputIntensityKey)

        guard let edgeOutput = edgesFilter.outputImage else { return nil }

        // Get average pixel value of the edge-detected image
        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return nil }
        avgFilter.setValue(edgeOutput, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: edgeOutput.extent), forKey: "inputExtent")

        guard let avgOutput = avgFilter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            avgOutput,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Return luminance as sharpness proxy
        return Double(pixel[0]) / 255.0 * 100.0
    }

    /// Measure average pixel intensity in a region of a CIImage
    private func measureAverageIntensity(_ ciImage: CIImage, in rect: CGRect) -> Double? {
        let cropped = ciImage.cropped(to: rect)

        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return nil }
        avgFilter.setValue(cropped, forKey: kCIInputImageKey)
        avgFilter.setValue(CIVector(cgRect: cropped.extent), forKey: "inputExtent")

        guard let avgOutput = avgFilter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            avgOutput,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return Double(pixel[0]) / 255.0
    }
}
