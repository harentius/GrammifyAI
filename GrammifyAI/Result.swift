import Foundation

struct Result {
    private static var STATUS_SUCCESS = "success"
    private static var STATUS_ERROR = "error"

    var status: String
    var error: String
    var output: String

    public static func success(output: String) -> Self {
        return Result(status: STATUS_SUCCESS, error: "", output: output)
    }

    public static func error(error: String) -> Self {
        return Result(status: STATUS_ERROR, error: error, output: "")
    }

    public func isSuccessful () -> Bool {
        return status == Result.STATUS_SUCCESS
    }
}
