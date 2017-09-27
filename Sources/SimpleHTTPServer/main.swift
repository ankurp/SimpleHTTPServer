#if os(Linux)
  import Glibc
  
  let sock_stream = Int32(SOCK_STREAM.rawValue)
#else
  import Darwin.C

  let sock_stream = SOCK_STREAM
#endif

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
  let clientSocket = accept(sock, nil, nil)

  queue.async {
    let htmlResponse = "<!DOCTYPE html><html><body><h1>Hello from Swift Web Server.</h1></body></html>\n"
    let headers = [
      "HTTP/1.1 200 OK",
      "server: Simple HTTP Server",
      "content-length: \(htmlResponse.characters.count)",
      "content-type: text/html; charset=utf-8"
    ].joined(separator: "\n")
    
    respond(clientSocket, withHeaders: headers, andWithContent: htmlResponse)
  }
} while sock > -1
