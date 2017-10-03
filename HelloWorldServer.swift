import Darwin.C

func htons(_ value: CUnsignedShort) -> CUnsignedShort {
  return (value << 8) + (value >> 8)
}

func sockaddrTypeCast(_ pointer: UnsafeMutableRawPointer) -> UnsafeMutablePointer<sockaddr> {
  return UnsafeMutablePointer<sockaddr>(OpaquePointer(pointer));
}

func respond(_ client: Int32, withHeaders: String, andWithContent: String) {
  let response = withHeaders + "\r\n\r\n" + andWithContent
  _ = response.withCString { bytes in
    send(client, bytes, Int(strlen(bytes)), 0)
    close(client)
  }
}

let sock = socket(AF_INET, Int32(SOCK_STREAM), 0)
guard sock > -1 else {
  fatalError("Could not create server socket.")
}

let portNumber = UInt16(CommandLine.arguments.last ?? "") ?? UInt16(4000)
let zero = Int8(0)
let socklen = UInt8(socklen_t(MemoryLayout<sockaddr_in>.size))
var serveraddr = sockaddr_in()
serveraddr.sin_family = sa_family_t(AF_INET)
serveraddr.sin_port = in_port_t(htons(in_port_t(portNumber)))
serveraddr.sin_addr = in_addr(s_addr: in_addr_t(0))
serveraddr.sin_zero = (zero, zero, zero, zero, zero, zero, zero, zero)
serveraddr.sin_len = socklen

guard bind(sock, sockaddrTypeCast(&serveraddr), socklen_t(socklen)) > -1 else {
  fatalError("Cannot bind to the socket")
}

guard listen(sock, 5) > -1 else {
  fatalError("Cannot listen on the socket")
}

print("Server listening on port \(portNumber)")

repeat {
  let client = accept(sock, nil, nil)
  let headers = [
    "HTTP/1.1 200 OK",
    "server: Simple HTTP Server",
  ].joined(separator: "\n")
  let htmlResponse = "<!DOCTYPE html><html><body><h1>Hello from Swift Web Server.</h1></body></html>\n"  
  respond(client, withHeaders: headers, andWithContent: htmlResponse)
} while sock > -1