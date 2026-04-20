import Foundation

extension UIImage {
    @objc public final func applying(
        symbolWeight: SymbolWeight,
        symbolScale: SymbolScale,
        paletteColors: [UIColor]? = nil
    ) -> UIImage {
        let weightConfig = UIImage.SymbolConfiguration(weight: symbolWeight)
        let scaleConfig = UIImage.SymbolConfiguration(scale: symbolScale)
        
        guard let paletteColors else {
            let combinedConfig = scaleConfig.applying(weightConfig)
            return withConfiguration(combinedConfig)
        }

        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: paletteColors)

        var combinedConfig = scaleConfig.applying(weightConfig)
        combinedConfig = combinedConfig.applying(paletteConfig)
        return withConfiguration(combinedConfig)
    }
    
    public final func applying(
        textStyle: UIFont.TextStyle,
        symbolScale: SymbolScale,
        paletteColors: [UIColor]? = nil
    ) -> UIImage {
        let textStyleConfig = UIImage.SymbolConfiguration(textStyle: textStyle, scale: symbolScale)
        
        guard let paletteColors else {
            return withConfiguration(textStyleConfig)
        }
        
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: paletteColors)
        let combinedConfig = textStyleConfig.applying(paletteConfig)
        return withConfiguration(combinedConfig)
    }
    
    public final func applying(
        pointSize: CGFloat,
        symbolWeight: SymbolWeight,
        symbolScale: SymbolScale,
        paletteColors: [UIColor]? = nil
    ) -> UIImage {
        let pointSizeConfig = UIImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: symbolWeight,
            scale: symbolScale
        )
        
        guard let paletteColors else {
            return withConfiguration(pointSizeConfig)
        }
        
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: paletteColors)
        let combinedConfig = pointSizeConfig.applying(paletteConfig)
        return withConfiguration(combinedConfig)
    }
    
    public final func applying(
        symbolFont: UIFont,
        symbolScale: SymbolScale,
        paletteColors: [UIColor]? = nil
    ) -> UIImage {
        let fontConfig = UIImage.SymbolConfiguration(
            font: symbolFont,
            scale: symbolScale
        )
        
        guard let paletteColors else {
            return withConfiguration(fontConfig)
        }
        
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: paletteColors)
        let combinedConfig = fontConfig.applying(paletteConfig)
        return withConfiguration(combinedConfig)
    }
    
    public final func applying(configuration: UIImage.SymbolConfiguration, paletteColors: [UIColor]) -> UIImage {
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: paletteColors)
        let combinedConfig = configuration.applying(paletteConfig)
        return withConfiguration(combinedConfig)
    }
        
    public final func applying(paletteColors: [UIColor]) -> UIImage {
        let paletteConfig = UIImage.SymbolConfiguration(paletteColors: paletteColors)
        return withConfiguration(paletteConfig)
    }
}
