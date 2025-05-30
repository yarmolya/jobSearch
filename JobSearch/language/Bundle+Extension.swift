import Foundation
import UIKit

private var bundleKey: UInt8 = 0

final class BundleEx: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static let once: Void = {
        object_setClass(Bundle.main, BundleEx.self)
    }()

    class func setLanguage(_ language: String) {
        Bundle.once
        let isLanguageRTL = Locale.Language(identifier: language).characterDirection == .rightToLeft
        UIView.appearance().semanticContentAttribute = isLanguageRTL ? .forceRightToLeft : .forceLeftToRight

        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let langBundle = Bundle(path: path) else {
            return
        }

        objc_setAssociatedObject(Bundle.main, &bundleKey, langBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

