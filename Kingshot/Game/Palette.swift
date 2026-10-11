import UIKit

/// Colours sampled from the look of the Kingshot road minigame.
enum Palette {
    static let grass = UIColor(red: 0.16, green: 0.69, blue: 0.42, alpha: 1)
    static let grassDark = UIColor(red: 0.10, green: 0.50, blue: 0.30, alpha: 1)
    static let treeLight = UIColor(red: 0.20, green: 0.62, blue: 0.34, alpha: 1)
    static let sand = UIColor(red: 0.89, green: 0.80, blue: 0.62, alpha: 1)
    static let sandLight = UIColor(red: 0.93, green: 0.86, blue: 0.71, alpha: 1)
    static let cliff = UIColor(red: 0.58, green: 0.61, blue: 0.66, alpha: 1)
    static let cliffLight = UIColor(red: 0.70, green: 0.73, blue: 0.78, alpha: 1)
    static let cliffDark = UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
    static let shadow = UIColor(white: 0, alpha: 0.22)

    static let gateGood = UIColor(red: 0.16, green: 0.62, blue: 0.33, alpha: 1)
    static let gateGoodEdge = UIColor(red: 0.09, green: 0.42, blue: 0.22, alpha: 1)
    static let gateBad = UIColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 1)
    static let gateBadEdge = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
    static let coin = UIColor(red: 0.98, green: 0.78, blue: 0.20, alpha: 1)
    static let coinDark = UIColor(red: 0.80, green: 0.55, blue: 0.10, alpha: 1)

    static let crowdBody = UIColor(red: 0.98, green: 0.60, blue: 0.20, alpha: 1)
    static let crowdBodyDark = UIColor(red: 0.80, green: 0.42, blue: 0.10, alpha: 1)
    static let crowdHead = UIColor(red: 0.99, green: 0.82, blue: 0.58, alpha: 1)

    static let enemyBody = UIColor(red: 0.86, green: 0.16, blue: 0.16, alpha: 1)
    static let enemyBodyDark = UIColor(red: 0.60, green: 0.08, blue: 0.08, alpha: 1)
    static let enemyHead = UIColor(red: 0.96, green: 0.76, blue: 0.64, alpha: 1)
    static let enemyHelmet = UIColor(red: 0.66, green: 0.68, blue: 0.72, alpha: 1)

    static let heroTunic = UIColor(red: 0.16, green: 0.38, blue: 0.86, alpha: 1)
    static let heroGold = UIColor(red: 0.97, green: 0.76, blue: 0.22, alpha: 1)
    static let heroSkin = UIColor(red: 0.98, green: 0.80, blue: 0.62, alpha: 1)
    static let steel = UIColor(red: 0.80, green: 0.82, blue: 0.86, alpha: 1)
    static let wood = UIColor(red: 0.55, green: 0.36, blue: 0.18, alpha: 1)
    static let woodDark = UIColor(red: 0.40, green: 0.25, blue: 0.11, alpha: 1)

    static let hudText = UIColor.white
    static let hudBadge = UIColor(white: 0, alpha: 0.45)
    static let buttonGreen = UIColor(red: 0.22, green: 0.72, blue: 0.36, alpha: 1)
    static let buttonRed = UIColor(red: 0.86, green: 0.30, blue: 0.24, alpha: 1)
    static let panel = UIColor(red: 0.13, green: 0.16, blue: 0.22, alpha: 0.94)
}

enum Fonts {
    static let heavy = "AvenirNext-Heavy"
    static let bold = "AvenirNext-Bold"
    static let demi = "AvenirNext-DemiBold"
}
