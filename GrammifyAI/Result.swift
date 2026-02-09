import Foundation

struct Result {
    private static var STATUS_SUCCESS = "success"
    private static var STATUS_ERROR = "error"

    var status: String
    var error: String
    var errorDetails: String
    var output: String
    var errors: [CorrectionError]
    var detectedLanguage: String

    public static func success(output: String, errors: [CorrectionError] = [], detectedLanguage: String = "") -> Self {
        return Result(status: STATUS_SUCCESS, error: "", errorDetails: "", output: output, errors: errors, detectedLanguage: detectedLanguage)
    }

    public static func error(error: String, errorDetails: String = "") -> Self {
        return Result(status: STATUS_ERROR, error: error, errorDetails: errorDetails, output: "", errors: [], detectedLanguage: "")
    }

    public func isSuccessful () -> Bool {
        return status == Result.STATUS_SUCCESS
    }
}
