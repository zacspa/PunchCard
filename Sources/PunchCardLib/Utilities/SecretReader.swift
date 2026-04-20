import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Reads a secret from the controlling terminal with echo suppressed.
/// Returns `nil` if stdin is not a TTY (e.g. piped input) so the caller can
/// fall back to line-based read.
public enum SecretReader {
    /// Prompt the user for a secret on stderr, disable terminal echo, read a
    /// line from stdin, restore echo, and return the entered text (without the
    /// trailing newline). When stdin is not a TTY, reads a plain line.
    public static func read(prompt: String) -> String? {
        FileHandle.standardError.write(Data(prompt.utf8))

        let fd = fileno(stdin)
        if isatty(fd) != 0 {
            var oldTerm = termios()
            if tcgetattr(fd, &oldTerm) != 0 {
                return readLine(strippingNewline: true)
            }
            var newTerm = oldTerm
            newTerm.c_lflag &= ~tcflag_t(ECHO)
            _ = tcsetattr(fd, TCSAFLUSH, &newTerm)
            defer {
                _ = tcsetattr(fd, TCSAFLUSH, &oldTerm)
                FileHandle.standardError.write(Data("\n".utf8))
            }
            return readLine(strippingNewline: true)
        }
        return readLine(strippingNewline: true)
    }
}
