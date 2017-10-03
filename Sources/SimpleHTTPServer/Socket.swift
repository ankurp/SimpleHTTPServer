import Foundation
#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

public class ServerSocket {
  
  private var sockAddr: sockaddr_in!
  private let cSocket: Int32!
  private let socklen: UInt8!

  init(port: UInt16) {
    #if os(Linux)
      let sock_stream = Int32(SOCK_STREAM.rawValue)
    #else
      let sock_stream = SOCK_STREAM
    #endif

    cSocket = socket(AF_INET, Int32(sock_stream), 0)
    
    guard self.cSocket > -1 else {
      fatalError("Could not create server socket.")
    }
    
    let INADDR_ANY = in_addr_t(0)
    let zero = Int8(0)
    let sin_zero = (zero, zero, zero, zero, zero, zero, zero, zero)
    socklen = UInt8(socklen_t(MemoryLayout<sockaddr_in>.size))
    sockAddr = sockaddr_in()
    sockAddr.sin_family = sa_family_t(AF_INET)
    sockAddr.sin_port = in_port_t(htons(value: in_port_t(port)))
    sockAddr.sin_addr = in_addr(s_addr: INADDR_ANY)
    sockAddr.sin_zero = sin_zero
    #if os(macOS)
      sockAddr.sin_len = socklen
    #endif
  }
  
  public func isRunning() -> Bool {
    return cSocket > -1
  }
  
  public func listen() {
    let sockaddr = sockaddr_cast(p: &sockAddr)
    #if os(Linux)
      guard Glibc.bind(cSocket, sockaddr, socklen_t(socklen)) > -1 else {
        fatalError("Cannot bind to the socket")
      }

      guard Glibc.listen(cSocket, 5) > -1 else {
        fatalError("Cannot listen on the socket")
      }
    #else
      guard Darwin.bind(cSocket, sockaddr, socklen_t(socklen)) > -1 else {
        fatalError("Cannot bind to the socket")
      }

      guard Darwin.listen(cSocket, 5) > -1 else {
        fatalError("Cannot listen on the socket")
      }
    #endif

    print("Server listening on port \(portNumber)")
  }
  
  public func acceptClientConnection() -> ClientConnection {
    return ClientConnection(sock: cSocket)
  }

  private func htons(value: CUnsignedShort) -> CUnsignedShort {
    return (value << 8) + (value >> 8)
  }
  
  private func sockaddr_cast(p: UnsafeMutableRawPointer) -> UnsafeMutablePointer<sockaddr> {
    return UnsafeMutablePointer<sockaddr>(OpaquePointer(p));
  }
}

public class ClientConnection {
  private let clientSocket: Int32!
  private let bufferMax = 2048
  private var readBuffer: [UInt8]!
  
  init(sock: Int32) {
    var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
    let addr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
    let addrSockAddr = UnsafeMutablePointer<sockaddr>(OpaquePointer(addr))
    readBuffer = Array(repeating: UInt8(0), count: bufferMax)
    clientSocket = accept(sock, addrSockAddr, &length)
  }
  
  public func request	() -> Request? {
    var readBufferPointer = UnsafeMutablePointer<CChar>(OpaquePointer(readBuffer))!

    #if os(Linux)
      Glibc.read(clientSocket, readBufferPointer, bufferMax)
    #else
      Darwin.read(clientSocket, readBufferPointer, bufferMax)
    #endif
    
    if let httpRequest = String(validatingUTF8: readBufferPointer) {
      return Request(httpRequest: httpRequest)
    }
    
    return nil
  }
  
  public func respond(withHeaders: String, andContent: String = "") {
    defer {
      close()
    }
    
    send(clientSocket, withHeaders)
    send(clientSocket, "\r\n\r\n")
    send(clientSocket, andContent)
  }
  
  public func respond(withHeaders: String, andData data: NSData) {
    defer {
      close()
    }
    
    send(clientSocket, withHeaders)
    send(clientSocket, "\r\n\r\n")
    send(clientSocket, data)
  }
  
  public func close() {
    #if os(Linux)
      Glibc.close(clientSocket)
    #else
      Darwin.close(clientSocket)
    #endif
  }
  
  private func send(_ socket: Int32, _ output: String) {
    _ = output.withCString { (bytes) in
      #if os(Linux)
        Glibc.send(socket, bytes, Int(strlen(bytes)), 0)
      #else
        Darwin.send(socket, bytes, Int(strlen(bytes)), 0)
      #endif
    }
  }
  
  private func send(_ socket: Int32, _ data: NSData) {
    #if os(Linux)
      Glibc.send(clientSocket, data.bytes, data.length, 0)
    #else
      Darwin.send(clientSocket, data.bytes, data.length, 0)
    #endif
  }
}

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
