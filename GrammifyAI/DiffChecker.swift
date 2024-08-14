import Foundation
import SwiftDiff

struct DiffChecker {
    public static func diffCheck(incorrectString: String, correctString: String) -> AttributedString {
        var diff = diff(text1: incorrectString, text2: correctString)
        var correctAttributedString = AttributedString()

        for el in diff {
            var fragment: AttributedString
            
            switch el {
            case .equal(let text):
                fragment = AttributedString(text)

                break
            case .insert(let text):
                fragment = AttributedString(text)
                fragment.foregroundColor = .green
                break
            case .delete(let text):
                fragment = AttributedString(text)
                fragment.foregroundColor = .red
                fragment.strikethroughColor = .red
                fragment.strikethroughStyle = .single
                break
            }

            correctAttributedString = correctAttributedString + fragment
        }

        return correctAttributedString
    }
}
