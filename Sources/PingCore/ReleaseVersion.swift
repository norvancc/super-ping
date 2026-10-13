import Foundation

public enum ReleaseVersion {
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ value: String) -> [Int]? {
            let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
            let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
            guard pieces.count == 3, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
            let result = pieces.compactMap { Int($0) }; return result.count == 3 ? result : nil
        }
        guard let a = parts(candidate), let b = parts(current) else { return false }
        return a.lexicographicallyPrecedes(b) == false && a != b
    }
    public static func validDigest(_ digest: String?) -> String? {
        guard let digest, digest.hasPrefix("sha256:") else { return nil }
        let value = String(digest.dropFirst(7)).lowercased()
        return value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) } ? value : nil
    }
}
