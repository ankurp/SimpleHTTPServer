import Foundation
#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

let zero = Int8(0)

public class ServerSocket {
  
  private var sockAddr: sockaddr_in!
  private let cSocket: Int32!
  private let socklen: UInt8!

  init(port: UInt16) {
    let htonsPort = (port << 8) + (port >> 8)

    #if os(Linux)
      let sock_stream = Int32(SOCK_STREAM.rawValue)
    #else
      let sock_stream = SOCK_STREAM
    #endif

    self.cSocket = socket(AF_INET, Int32(sock_stream), 0)
    
    guard self.cSocket > -1 else {
      fatalError("Could not create server socket.")
    }

    self.socklen = UInt8(socklen_t(MemoryLayout<sockaddr_in>.size))
    self.sockAddr = sockaddr_in()
    self.sockAddr.sin_family = sa_family_t(AF_INET)
    self.sockAddr.sin_port = in_port_t(htonsPort)
    self.sockAddr.sin_addr = in_addr(s_addr: in_addr_t(0))
    self.sockAddr.sin_zero = (zero, zero, zero, zero, zero, zero, zero, zero)
    #if os(macOS)
      self.sockAddr.sin_len = socklen
    #endif
  }
  
  public func isRunning() -> Bool {
    return self.cSocket > -1
  }
  
  public func bindAndListen() {
    withUnsafePointer(to: &self.sockAddr) { sockaddrInPtr in
      let sockaddrPtr = UnsafeRawPointer(sockaddrInPtr).assumingMemoryBound(to: sockaddr.self)
      guard bind(self.cSocket, sockaddrPtr, socklen_t(self.socklen)) > -1 else {
        fatalError("Cannot bind to the socket")
      }
    }

    guard listen(self.cSocket, 5) > -1 else {
      fatalError("Cannot listen on the socket")
    }

    print("Server listening on port \(portNumber)")
  }
  
  public func acceptClientConnection() -> ClientConnection {
    return ClientConnection(sock: self.cSocket)
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
    self.readBuffer = Array(repeating: UInt8(0), count: bufferMax)
    self.clientSocket = accept(sock, addrSockAddr, &length)
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
    let response = withHeaders + "\r\n\r\n" + andContent
    self.send(clientSocket, response)
    self.close()
  }
  
  public func respond(withHeaders: String, andData data: NSData) {    
    self.send(clientSocket, withHeaders + "\r\n\r\n")
    self.send(clientSocket, data)
    self.close()
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
