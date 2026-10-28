import Foundation

enum K9sLaunch {
    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    static func script(kubeconfig: String, context: String) -> String {
        let directory = URL(fileURLWithPath: kubeconfig).deletingLastPathComponent().path
        return """
        #!/bin/zsh
        # Run in Terminal's environment so existing auth tools and credentials work.
        export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
        /bin/rm -f -- "$0"
        if ! command -v k9s >/dev/null 2>&1; then
            printf '%s\\n' 'Chưa tìm thấy k9s. Cài k9s (ví dụ: brew install k9s), rồi thử lại.'
            printf '%s' 'Nhấn Enter để đóng phiên này… '
            read -r reply
            exit 127
        fi
        cd -- \(quote(directory)) || exit 1
        exec k9s --kubeconfig=\(quote(kubeconfig)) --context=\(quote(context))

        """
    }
}
