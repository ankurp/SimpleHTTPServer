import Foundation
import Dispatch

class Server {
  let serverSocket: ServerSocket!
  let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  let queue = DispatchQueue(
    label: "simple.http.server",
    qos: .userInteractive,
    attributes: .concurrent
  )

  init(port: UInt16) {
    serverSocket = ServerSocket(port: port)
  }
  
  func start() {
    serverSocket.bindAndListen()

    repeat {
      let client = serverSocket.acceptClientConnection()
      queue.async {
        if let request = client.request(),
          let httpVerb = request.httpVerb,
          var filePath = request.path {
          
          if filePath.hasSuffix("/") {
            filePath += "index.html"
          }
          
          print("\(httpVerb) \(filePath)")
          if let data = NSData(contentsOf: self.currentDirectoryURL.appendingPathComponent(filePath)) {
            let headers = [
              "HTTP/1.1 200 OK",
              "server: Simple HTTP Server",
              "content-length: \(data.length)"
              ].joined(separator: "\n")

            client.respond(withHeaders: headers, andData: data)
          }

          client.respond(withHeaders: [
            "HTTP/1.1 404",
            "server: Simple HTTP Server"
          ].joined(separator: "\n"))
        } else {
          client.respond(withHeaders: [
            "HTTP/1.1 400 Bad",
            "server: Simple HTTP Server"
            ].joined(separator: "\n"))
        }
      }
    } while serverSocket.isRunning()
  }
}
