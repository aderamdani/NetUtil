import Foundation

private func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

@discardableResult
private func run(_ executable: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    do {
        try process.run()
    } catch {
        fail("netutil: cannot run \(executable): \(error.localizedDescription)", code: 127)
    }
    process.waitUntilExit()
    return process.terminationStatus
}

private func usage() {
    print("""
    netutil — command-line network diagnostics (companion to the NetUtil app)

    USAGE:
      netutil ping <host> [count]
      netutil traceroute <host> [max-hops]
      netutil dns <domain> [record-type]
      netutil whois <domain>
      netutil speed
      netutil interfaces
      netutil help

    EXAMPLES:
      netutil ping 1.1.1.1 10
      netutil traceroute apple.com 20
      netutil dns apple.com MX
      netutil speed
    """)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    usage()
    exit(1)
}
let rest = Array(arguments.dropFirst())

switch command {
case "help", "-h", "--help":
    usage()

case "ping":
    guard let host = rest.first else { fail("netutil ping: missing host") }
    let count = rest.count > 1 ? (Int(rest[1]) ?? 5) : 5
    exit(run("/sbin/ping", ["-c", "\(count)", host]))

case "traceroute":
    guard let host = rest.first else { fail("netutil traceroute: missing host") }
    var args = ["-a"]
    if rest.count > 1, let hops = Int(rest[1]) { args += ["-m", "\(hops)"] }
    args.append(host)
    exit(run("/usr/bin/traceroute", args))

case "dns":
    guard let domain = rest.first else { fail("netutil dns: missing domain") }
    var args = ["+short"]
    if rest.count > 1 { args += ["-t", rest[1].uppercased()] }
    args.append(domain)
    exit(run("/usr/bin/dig", args))

case "whois":
    guard let domain = rest.first else { fail("netutil whois: missing domain") }
    exit(run("/usr/bin/whois", [domain]))

case "speed":
    exit(run("/usr/bin/networkQuality", ["-c"]))

case "interfaces":
    exit(run("/sbin/ifconfig", ["-a"]))

default:
    fail("netutil: unknown command '\(command)'. Run 'netutil help'.")
}
