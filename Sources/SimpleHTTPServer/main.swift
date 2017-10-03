#if os(Linux)
  import Glibc
  
  let sock_stream = Int32(SOCK_STREAM.rawValue)
#else
  import Darwin.C

  let sock_stream = SOCK_STREAM
#endif

import Foundation
import Dispatch

let portNumber = getPortNumber()
let sock = socket(AF_INET, Int32(sock_stream), 0)

guard sock > -1 else {
  fatalError("Could not create server socket.")
}

let (sockaddr, socklen) = getServerSockAddr()

guard bind(sock, sockaddr, socklen_t(socklen)) > -1 else {
  fatalError("Cannot bind to the socket")
}

guard listen(sock, 5) > -1 else {
  fatalError("Cannot listen on the socket")
}

print("Server listening on port \(portNumber)")

let queue = DispatchQueue(
  label: "simple.http.server",
  qos: .userInteractive,
  attributes: .concurrent
)

repeat {
  var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
  let addr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
  let addrSockAddr = UnsafeMutablePointer<sockaddr>(OpaquePointer(addr))
  let bufferMax = 2048
  let zero = UInt8(0)
  var readBuffer = Array(repeating: zero, count: bufferMax)
  let clientSocket = accept(sock, addrSockAddr, &length)
  read(clientSocket, &readBuffer, bufferMax)

  if let request = String(validatingUTF8: UnsafeMutablePointer<CChar>(OpaquePointer(readBuffer))) {
    queue.async {
      let filePath = request.split(separator: "\n")[0].split(separator: " ")[1].description
      let fileManager = FileManager.default
      let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
      let fileURL = currentDirectoryURL.appendingPathComponent("\(filePath)\(filePath.hasSuffix("/") ? "/index.html" : "")")

      print("serving \(filePath)")
      if let data = NSData(contentsOf: fileURL) {
        let headers = [
          "HTTP/1.1 200 OK",
          "server: Simple HTTP Server",
          "content-length: \(data.length)"
        ].joined(separator: "\n")
        
        respond(clientSocket, withHeaders: headers, andWithData: data)
      }

      respond(clientSocket, withHeaders: [
        "HTTP/1.1 404",
        "server: Simple HTTP Server"
      ].joined(separator: "\n"), andWithContent: "")
    }
  } else {
    respond(clientSocket, withHeaders: [
      "HTTP/1.1 400 Bad",
      "server: Simple HTTP Server"
    ].joined(separator: "\n"), andWithContent: "")
  }
} while sock > -1
