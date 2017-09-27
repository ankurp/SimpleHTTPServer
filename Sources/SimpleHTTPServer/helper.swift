#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

func getPortNumber() -> UInt16 {
  if let arg = CommandLine.arguments.last, let value = UInt16(arg) {
    return value
  } else {
    return 4000
  }
}

func htons(value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8)
}

func sockaddr_cast(p: UnsafeMutableRawPointer) -> UnsafeMutablePointer<sockaddr> {
    return UnsafeMutablePointer<sockaddr>(OpaquePointer(p));
}

func getServerSockAddr() -> (UnsafeMutablePointer<sockaddr>, UInt8) {
  let INADDR_ANY = in_addr_t(0)
  let zero = Int8(0)
  let sin_zero = (zero, zero, zero, zero, zero, zero, zero, zero)
  let socklen = UInt8(socklen_t(MemoryLayout<sockaddr_in>.size))
  var serveraddr = sockaddr_in()
  serveraddr.sin_family = sa_family_t(AF_INET)
  serveraddr.sin_port = in_port_t(htons(value: in_port_t(portNumber)))
  serveraddr.sin_addr = in_addr(s_addr: INADDR_ANY)
  serveraddr.sin_zero = sin_zero
  #if os(macOS)
    serveraddr.sin_len = socklen
  #endif

  return (sockaddr_cast(p: &serveraddr), socklen)
}

func write(_ socket: Int32, _ output: String) {
  _ = output.withCString { (bytes) in
    send(socket, bytes, Int(strlen(bytes)), 0)
  }
}

func respond(_ clientSocket: Int32, withHeaders: String, andWithContent: String) {
  defer {
    close(clientSocket)
  }
  
  write(clientSocket, withHeaders)
  write(clientSocket, "\r\n\r\n")
  write(clientSocket, andWithContent)
}
