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
    case errorLevelAnalysis
    case noiseConsistency
    case edgeArtifacts
    case lightingConsistency

    var displayName: String {
        switch self {
        case .faceSymmetry: return "Face Symmetry"
        case .backgroundConsistency: return "Background Consistency"
        case .colorDistribution: return "Color Distribution"
        case .textureUniformity: return "Texture Uniformity"
        case .sharpnessPattern: return "Sharpness Pattern"
        case .errorLevelAnalysis: return "Error Level Analysis"
        case .noiseConsistency: return "Noise Consistency"
        case .edgeArtifacts: return "Edge Artifacts"
        case .lightingConsistency: return "Lighting Consistency"
        }
    }

    var weight: Double {
        switch self {
        case .faceSymmetry: return 1.5           // Reduced — selfies are naturally symmetric
        case .backgroundConsistency: return 1.0  // Weak — phone cameras have deep DOF naturally
        case .colorDistribution: return 1.0
        case .textureUniformity: return 1.2
        case .sharpnessPattern: return 0.8       // Weak — computational photography produces uniform sharpness
        case .errorLevelAnalysis: return 2.0     // Strong — compression artifacts reveal edited regions
        case .noiseConsistency: return 1.5       // Composited regions have different sensor noise
        case .edgeArtifacts: return 1.8          // Strong — solid fills + sharp edges = compositing
        case .lightingConsistency: return 1.3    // Mismatched lighting direction across faces/background
        }
    }

    var isAICheck: Bool {
        switch self {
        case .faceSymmetry, .backgroundConsistency, .colorDistribution, .textureUniformity, .sharpnessPattern:
            return true
        case .errorLevelAnalysis, .noiseConsistency, .edgeArtifacts, .lightingConsistency:
            return false
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
        async let edgeFlag = checkEdgeArtifacts(scaled)
        async let elaFlag = checkErrorLevelAnalysis(scaled)
        async let noiseFlag = checkNoiseConsistency(scaled)
        async let lightingFlag = checkLightingConsistency(scaled)

        let results = await [faceFlag, bgFlag, colorFlag, textureFlag, sharpnessFlag,
                             edgeFlag, elaFlag, noiseFlag, lightingFlag]
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
        // Real selfies (front-facing, arm's length) routinely hit 0.97-0.99
        if combinedSymmetry > 0.993 {
            return ImageSuspicionFlag(
                type: .faceSymmetry,
                finding: "Face shows unusually high bilateral symmetry (\(Int(combinedSymmetry * 100))%) — common in AI-generated faces",
                suspicionLevel: min((combinedSymmetry - 0.993) * 30.0 + 0.3, 0.7)
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
        // uniform sharpness, and indoor photos (gyms, offices) have subjects at similar
        // distances — threshold must be very conservative
        if cv < 0.04 && mean > 5.0 {
            return ImageSuspicionFlag(
                type: .backgroundConsistency,
                finding: "Unnaturally uniform sharpness across the image — real photos typically show depth-of-field variation",
                suspicionLevel: min(0.3, max(0.15, 0.35 - cv * 5.0))
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
        // Typical photos: entropy 4.5-5.8, AI images often: 3.0-4.0
        // Indoor photos with limited color palette (gyms, offices) can dip below 4.0
        if entropy < 3.4 {
            return ImageSuspicionFlag(
                type: .colorDistribution,
                finding: "Color distribution is unusually uniform — AI-generated images often show smoother color gradients",
                suspicionLevel: min(0.35, max(0.2, (3.6 - entropy) * 0.5))
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
        // the similarity is extreme. Indoor photos with uniform lighting routinely
        // have similar edge density everywhere, so keep this very tight.
        let ratio = centerEdge / fullEdge
        if ratio > 0.97 && ratio < 1.03 && fullEdge > 0.02 && fullEdge < 0.06 {
            return ImageSuspicionFlag(
                type: .textureUniformity,
                finding: "Texture complexity is unusually consistent between subject and background",
                suspicionLevel: 0.15
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
        // and indoor scenes at similar distance produce uniform sharpness —
        // only flag at extremely low CV values
        if cv < 0.02 && mean > 3.0 {
            return ImageSuspicionFlag(
                type: .sharpnessPattern,
                finding: "Sharpness is unnaturally consistent across the entire image — natural photos show focal depth variation",
                suspicionLevel: min(0.3, max(0.15, 0.3 - cv * 8.0))
            )
        }

        return nil
    }

    // MARK: - Check 7: Edge Artifact Detection

    private func checkEdgeArtifacts(_ image: UIImage) -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // Part A: Detect solid color fills (black rectangles, painted-over regions)
        // Apply edge detection and check for cells with near-zero edges
        guard let edgesFilter = CIFilter(name: "CIEdges") else { return nil }
        edgesFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgesFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        guard let edgeOutput = edgesFilter.outputImage else { return nil }

        let width = ciImage.extent.width
        let height = ciImage.extent.height
        let cols = 8
        let rows = 8
        let cellWidth = width / CGFloat(cols)
        let cellHeight = height / CGFloat(rows)

        var solidCells = 0
        let totalCells = cols * rows

        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(
                    x: ciImage.extent.origin.x + CGFloat(col) * cellWidth,
                    y: ciImage.extent.origin.y + CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                if let intensity = measureAverageIntensity(edgeOutput, in: rect), intensity < 0.005 {
                    solidCells += 1
                }
            }
        }

        let solidRatio = Double(solidCells) / Double(totalCells)
        var suspicion: Double = 0

        if solidRatio > 0.05 {
            // >5% solid cells — likely has painted-over / blocked regions
            suspicion = min(0.6, solidRatio * 4.0)
        }

        // Part B: Strong edge detection for unnaturally sharp compositing boundaries
        guard let strongEdgesFilter = CIFilter(name: "CIEdges") else { return nil }
        strongEdgesFilter.setValue(ciImage, forKey: kCIInputImageKey)
        strongEdgesFilter.setValue(5.0, forKey: kCIInputIntensityKey)
        guard let strongEdgeOutput = strongEdgesFilter.outputImage else { return nil }

        // Histogram the strong edge image — check for high-intensity edge concentration
        guard let histFilter = CIFilter(name: "CIAreaHistogram") else { return nil }
        histFilter.setValue(strongEdgeOutput, forKey: kCIInputImageKey)
        histFilter.setValue(CIVector(cgRect: strongEdgeOutput.extent), forKey: "inputExtent")
        histFilter.setValue(32, forKey: "inputCount")
        histFilter.setValue(1.0, forKey: "inputScale")

        guard let histOutput = histFilter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 32 * 4)
        ciContext.render(
            histOutput,
            toBitmap: &bitmap,
            rowBytes: 32 * 4,
            bounds: CGRect(x: 0, y: 0, width: 32, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Sum all bins and check ratio in top bins (indices 24-31)
        var totalEdgePixels: Double = 0
        var topBinPixels: Double = 0
        for i in 0..<32 {
            let val = Double(bitmap[i * 4])
            totalEdgePixels += val
            if i >= 24 {
                topBinPixels += val
            }
        }

        if totalEdgePixels > 0 {
            let topRatio = topBinPixels / totalEdgePixels
            if topRatio > 0.15 {
                // High concentration of very strong edges — compositing boundaries
                suspicion = max(suspicion, min(0.7, topRatio * 2.5))
            }
        }

        // Combined: solid fills + sharp edges together is very strong evidence
        if solidRatio > 0.05 && suspicion > 0.3 {
            suspicion = min(0.8, suspicion + 0.15)
        }

        guard suspicion > 0 else { return nil }

        let finding: String
        if solidRatio > 0.05 {
            finding = "Detected solid color regions (\(Int(solidRatio * 100))% of image) with sharp compositing boundaries — consistent with photo manipulation"
        } else {
            finding = "Unnaturally sharp edge boundaries detected — may indicate composited or pasted elements"
        }

        return ImageSuspicionFlag(
            type: .edgeArtifacts,
            finding: finding,
            suspicionLevel: suspicion
        )
    }

    // MARK: - Check 8: Error Level Analysis (ELA)

    private func checkErrorLevelAnalysis(_ image: UIImage) -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // Re-compress at 75% JPEG quality
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.75),
              let recompressedUI = UIImage(data: jpegData),
              let recompressedCG = recompressedUI.cgImage else { return nil }

        let recompressedCI = CIImage(cgImage: recompressedCG)

        // Compute pixel difference using CIDifferenceBlendMode
        guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode") else { return nil }
        diffFilter.setValue(ciImage, forKey: kCIInputImageKey)
        diffFilter.setValue(recompressedCI, forKey: kCIInputBackgroundImageKey)
        guard let diffOutput = diffFilter.outputImage else { return nil }

        // Measure error levels across a 4x4 grid
        let width = ciImage.extent.width
        let height = ciImage.extent.height
        let cols = 4
        let rows = 4
        let cellWidth = width / CGFloat(cols)
        let cellHeight = height / CGFloat(rows)

        var cellIntensities: [Double] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(
                    x: ciImage.extent.origin.x + CGFloat(col) * cellWidth,
                    y: ciImage.extent.origin.y + CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                if let intensity = measureAverageIntensity(diffOutput, in: rect) {
                    cellIntensities.append(intensity)
                }
            }
        }

        guard cellIntensities.count >= 16 else { return nil }

        let mean = cellIntensities.reduce(0, +) / Double(cellIntensities.count)
        guard mean > 0 else { return nil }

        let variance = cellIntensities.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(cellIntensities.count)
        let cv = sqrt(variance) / mean

        // Count outlier cells (intensity > 2x mean)
        let outliers = cellIntensities.filter { $0 > mean * 2.0 }.count
        let outlierRatio = Double(outliers) / Double(cellIntensities.count)

        // Authentic photos have uniform compression artifacts (low CV)
        // Composites show inconsistent error levels where edits were made
        guard cv > 0.6 || outlierRatio > 0.2 else { return nil }

        let suspicion = min(0.7, max(cv * 0.5, outlierRatio * 2.0))

        return ImageSuspicionFlag(
            type: .errorLevelAnalysis,
            finding: "Inconsistent compression artifacts detected across the image (CV: \(String(format: "%.2f", cv))) — regions may have been edited or composited from different sources",
            suspicionLevel: suspicion
        )
    }

    // MARK: - Check 9: Noise/Grain Consistency

    private func checkNoiseConsistency(_ image: UIImage) -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // Extract noise layer: blur the image then subtract to isolate noise
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(3.0, forKey: kCIInputRadiusKey)
        guard let blurredOutput = blurFilter.outputImage else { return nil }

        // Crop blurred image to original extent (blur extends bounds)
        let blurredCropped = blurredOutput.cropped(to: ciImage.extent)

        // Difference to isolate noise
        guard let diffFilter = CIFilter(name: "CIDifferenceBlendMode") else { return nil }
        diffFilter.setValue(ciImage, forKey: kCIInputImageKey)
        diffFilter.setValue(blurredCropped, forKey: kCIInputBackgroundImageKey)
        guard let noiseOutput = diffFilter.outputImage else { return nil }

        // Measure noise energy across 4x4 grid
        let width = ciImage.extent.width
        let height = ciImage.extent.height
        let cols = 4
        let rows = 4
        let cellWidth = width / CGFloat(cols)
        let cellHeight = height / CGFloat(rows)

        var noiseEnergies: [Double] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let rect = CGRect(
                    x: ciImage.extent.origin.x + CGFloat(col) * cellWidth,
                    y: ciImage.extent.origin.y + CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                if let intensity = measureAverageIntensity(noiseOutput, in: rect) {
                    noiseEnergies.append(intensity)
                }
            }
        }

        guard noiseEnergies.count >= 16 else { return nil }

        let mean = noiseEnergies.reduce(0, +) / Double(noiseEnergies.count)
        guard mean > 0 else { return nil }

        let variance = noiseEnergies.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(noiseEnergies.count)
        let cv = sqrt(variance) / mean

        let maxNoise = noiseEnergies.max() ?? 0
        let minNoise = noiseEnergies.min() ?? 0
        let noiseRatio = minNoise > 0 ? maxNoise / minNoise : 0

        // Dual gate: both CV and max/min ratio must be high
        // Different source photos have different sensor noise patterns
        guard cv > 0.5 && noiseRatio > 2.5 else { return nil }

        let suspicion = min(0.6, cv * 0.4 + (noiseRatio - 2.5) * 0.1)

        return ImageSuspicionFlag(
            type: .noiseConsistency,
            finding: "Inconsistent noise/grain patterns detected across the image — different regions may originate from different source photos",
            suspicionLevel: suspicion
        )
    }

    // MARK: - Check 10: Lighting Direction Analysis

    private func checkLightingConsistency(_ image: UIImage) async -> ImageSuspicionFlag? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        // Detect faces
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let faces = request.results, !faces.isEmpty else { return nil }

        let width = ciImage.extent.width
        let height = ciImage.extent.height

        // For each face, estimate light direction from left/right luminance difference
        var faceLightDirections: [Double] = []

        for face in faces {
            let bbox = face.boundingBox
            let faceRect = CGRect(
                x: bbox.origin.x * width,
                y: bbox.origin.y * height,
                width: bbox.width * width,
                height: bbox.height * height
            )

            let leftHalf = CGRect(
                x: faceRect.origin.x,
                y: faceRect.origin.y,
                width: faceRect.width / 2,
                height: faceRect.height
            )
            let rightHalf = CGRect(
                x: faceRect.origin.x + faceRect.width / 2,
                y: faceRect.origin.y,
                width: faceRect.width / 2,
                height: faceRect.height
            )

            // Convert to grayscale for luminance measurement
            guard let grayFilter = CIFilter(name: "CIColorControls") else { continue }
            grayFilter.setValue(ciImage, forKey: kCIInputImageKey)
            grayFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            guard let grayImage = grayFilter.outputImage else { continue }

            guard let leftLum = measureAverageIntensity(grayImage, in: leftHalf),
                  let rightLum = measureAverageIntensity(grayImage, in: rightHalf) else {
                continue
            }

            // Light direction: positive = lit from right, negative = lit from left
            let direction = rightLum - leftLum
            faceLightDirections.append(direction)
        }

        guard !faceLightDirections.isEmpty else { return nil }

        // Measure background light direction (top-left vs top-right of image)
        guard let grayFilter = CIFilter(name: "CIColorControls") else { return nil }
        grayFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayFilter.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let grayImage = grayFilter.outputImage else { return nil }

        let bgLeftRect = CGRect(x: 0, y: height * 0.6, width: width * 0.3, height: height * 0.4)
        let bgRightRect = CGRect(x: width * 0.7, y: height * 0.6, width: width * 0.3, height: height * 0.4)

        guard let bgLeftLum = measureAverageIntensity(grayImage, in: bgLeftRect),
              let bgRightLum = measureAverageIntensity(grayImage, in: bgRightRect) else {
            return nil
        }

        let bgDirection = bgRightLum - bgLeftLum

        var suspicion: Double = 0
        var finding = ""

        // Check face-to-background lighting conflict
        for faceDir in faceLightDirections {
            let conflict = faceDir * bgDirection // Negative product = opposite directions
            if conflict < -0.08 {
                suspicion = max(suspicion, min(0.6, abs(conflict) * 3.0))
                finding = "Face lighting direction conflicts with background lighting — the face may have been composited from a different photo"
            }
        }

        // Check face-to-face lighting consistency (if multiple faces)
        if faceLightDirections.count >= 2 {
            let maxDir = faceLightDirections.max() ?? 0
            let minDir = faceLightDirections.min() ?? 0
            let spread = maxDir - minDir

            if spread > 0.25 {
                let multiFaceSuspicion = min(0.6, spread * 1.5)
                if multiFaceSuspicion > suspicion {
                    suspicion = multiFaceSuspicion
                    finding = "Faces in the image show inconsistent lighting directions (spread: \(String(format: "%.2f", spread))) — they may have been composited from different photos"
                }
            }
        }

        guard suspicion > 0 else { return nil }

        return ImageSuspicionFlag(
            type: .lightingConsistency,
            finding: finding,
            suspicionLevel: suspicion
        )
    }

    // MARK: - Scoring

    private func calculateWeightedScore(_ flags: [ImageSuspicionFlag]) -> Double {
        guard !flags.isEmpty else { return 0.0 }

        // Category-based scoring: compute AI and composite scores independently
        // within their own weight pools, then take the max.
        // This prevents adding composite checks from diluting AI detection sensitivity.
        let aiChecks = ImageCheckType.allCases.filter { $0.isAICheck }
        let compositeChecks = ImageCheckType.allCases.filter { !$0.isAICheck }

        let aiTotalWeight = aiChecks.reduce(0.0) { $0 + $1.weight }
        let compositeTotalWeight = compositeChecks.reduce(0.0) { $0 + $1.weight }

        var aiWeightedSum: Double = 0
        var compositeWeightedSum: Double = 0

        for flag in flags {
            if flag.type.isAICheck {
                aiWeightedSum += flag.suspicionLevel * flag.type.weight
            } else {
                compositeWeightedSum += flag.suspicionLevel * flag.type.weight
            }
        }

        let aiScore = aiTotalWeight > 0 ? aiWeightedSum / aiTotalWeight : 0
        let compositeScore = compositeTotalWeight > 0 ? compositeWeightedSum / compositeTotalWeight : 0

        var score = max(aiScore, compositeScore)

        // If both categories flag, add a bonus — evidence of both AI and compositing
        if aiScore > 0.15 && compositeScore > 0.15 {
            score += 0.1
        }

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
            return "On-device analysis found no obvious signs of AI generation or photo manipulation. The image passed all heuristic checks."
        }

        let flagDescriptions = flags.map { $0.type.displayName }
        let joined = flagDescriptions.joined(separator: ", ")

        let hasAIFlags = flags.contains { $0.type.isAICheck }
        let hasCompositeFlags = flags.contains { !$0.type.isAICheck }

        let threatDescription: String
        if hasAIFlags && hasCompositeFlags {
            threatDescription = "AI generation and photo manipulation"
        } else if hasCompositeFlags {
            threatDescription = "photo manipulation or compositing"
        } else {
            threatDescription = "AI generation"
        }

        switch riskLevel {
        case .low:
            return "Minor indicators detected (\(joined)), but overall the image appears genuine."
        case .medium:
            return "Some suspicious characteristics found: \(joined). The image may warrant further investigation for \(threatDescription)."
        case .high:
            return "Multiple indicators detected: \(joined). This image shows significant signs of \(threatDescription)."
        case .critical:
            return "Strong indicators found across multiple checks: \(joined). This image is very likely the result of \(threatDescription)."
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
