public class Request {
  let requestHeaders: [String]!
  var httpVerb: String?
  var path: String?

  init(httpRequest: String) {
    requestHeaders = httpRequest.split(separator: "\n").map({ $0.description })
    if let httpLine = requestHeaders.first {
      let parts = httpLine.split(separator: " ").map({ $0.description })
      httpVerb = parts[0]
      path = parts[1]
    }
  }
}
