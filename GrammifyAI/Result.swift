import Foundation

struct Result {
    private static var STATUS_SUCCESS = "success"
    private static var STATUS_ERROR = "error"

    var status: String
    var error: String
    var errorDetails: String
    var output: String

    public static func success(output: String) -> Self {
        return Result(status: STATUS_SUCCESS, error: "", errorDetails: "", output: output)
    }

    public static func error(error: String, errorDetails: String = "") -> Self {
        return Result(status: STATUS_ERROR, error: error, errorDetails: errorDetails, output: "")
    }

    public func isSuccessful () -> Bool {
        return status == Result.STATUS_SUCCESS
    }
}
