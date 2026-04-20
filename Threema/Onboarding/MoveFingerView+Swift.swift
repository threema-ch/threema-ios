import CommonCrypto

extension MoveFingerView {
    private func generateSeedWithPoints(points: [CGPoint]) {
        #if !DEBUG
            return;
        #endif
        
        // Reset the internal digest
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        numberOfPositionsRecorded = 0

        for var point in points where numberOfPositionsRecorded < points.count {
            var timestamp = Date().timeIntervalSinceReferenceDate

            var ctx = CC_SHA256_CTX()
            CC_SHA256_Init(&ctx)

            // Add previous digest
            CC_SHA256_Update(&ctx, &digest, CC_LONG(digest.count))

            // Add current position and timestamp
            CC_SHA256_Update(&ctx, &point, CC_LONG(MemoryLayout.size(ofValue: point)))
            CC_SHA256_Update(&ctx, &timestamp, CC_LONG(MemoryLayout.size(ofValue: timestamp)))
            
            var finalDigest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256_Final(&finalDigest, &ctx)
            digest = finalDigest

            numberOfPositionsRecorded += 1
            delegate?.didMoveFinger(in: self)
        }
    }

    @objc func generateRandomSeed(numberOfPositionsRequired: Int) {
        #if !DEBUG
            return;
        #endif
        
        // Get the view's frame dimensions
        let frame = bounds // Use bounds instead of frame for internal size

        // Extract width and height
        let width = frame.width
        let height = frame.height

        var points: [CGPoint] = []
        for _ in 0..<numberOfPositionsRequired {
            // Generate random x and y coordinates within the view's bounds
            let x = CGFloat(arc4random_uniform(UInt32(width)))
            let y = CGFloat(arc4random_uniform(UInt32(height)))
            points.append(CGPoint(x: x, y: y))
        }
        
        generateSeedWithPoints(points: points)
    }
}
