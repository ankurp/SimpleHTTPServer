let portNumber = UInt16(CommandLine.arguments.last ?? "") ?? UInt16(4000)
let server = Server(port: portNumber)
server.start()
