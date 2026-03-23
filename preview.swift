import SwiftUI
import UIKit
import CryptoKit

// 1. Representable para mostrar el UIViewController compilado
struct ViewControllerRepresentable: UIViewControllerRepresentable {
    let vc: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { vc }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// 2. Wrapper para NSCache
class CachedVC: NSObject {
    let vc: UIViewController
    init(_ vc: UIViewController) { self.vc = vc }
}

struct ContentView: View {
    @State private var code: String = """
import SwiftUI

struct MiVista: View {
    @State private var count = 0
    var body: some View {
        VStack(spacing: 30) {
            Text("Contador: \\(count)")
                .font(.title)
            
            Button("Incrementar") {
                count += 1
            }
        }
    }
}
"""
    @State private var remoteVC: UIViewController?
    @State private var errorMessage: String = ""
    @State private var compilationID = UUID()
    @State private var isCompiling = false
    @State private var isTaskRunning = false
    
    private let cache = NSCache<NSString, CachedVC>()

    var body: some View {
        HStack(spacing: 0) {
            // EDITOR
            VStack(spacing: 0) {
                TextEditor(text: $code)
                    .frame(minWidth: 350)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable) // Fuerza teclado estándar
                    .textInputAutocapitalization(.never)
                
                if !errorMessage.isEmpty {
                    ScrollView {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 11, design: .monospaced))
                            .padding()
                    }
                    .frame(height: 150)
                    .background(Color(UIColor.secondarySystemBackground))
                }
                
                HStack {
                    if isCompiling {
                        ProgressView().padding(.leading)
                    }
                    Spacer()
                    Button("Renderizar (Cmd+R)") {
                        handleRKey()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .padding()
                }
            }
            .frame(width: 450)
            
            Divider()
            
            // PREVIEW (Simulador iPhone)
            ZStack {
                Color(UIColor.systemGroupedBackground)
                if let vc = remoteVC {
                    ViewControllerRepresentable(vc: vc)
                        .id(compilationID)
                        .frame(width: 393, height: 852)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 50))
                        .overlay(RoundedRectangle(cornerRadius: 50).stroke(Color.black, lineWidth: 10))
                        .shadow(radius: 30)
                } else {
                    Text("Escribe código y pulsa Cmd+R").foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 500)
        }
    }

    // --- Lógica de Compilación ---

    func handleRKey() {
        let hash = SHA256.hash(data: Data(code.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        
        if let cached = cache.object(forKey: hash as NSString) {
            print("🚀 Cache Hit!")
            self.remoteVC = cached.vc
            self.compilationID = UUID()
            self.errorMessage = ""
        } else {
            isCompiling = true
            startCompilation(hash: hash)
        }
    }

    func startCompilation(hash: String) {
        if isTaskRunning { return }
        isTaskRunning = true
        
        // 1. Extraer nombre de la struct
        let pattern = #"struct\s+(\w+)\s*:\s*View"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let structName = regex?.firstMatch(in: code, range: NSRange(code.startIndex..., in: code))
            .map { String(code[Range($0.range(at: 1), in: code)!]) } ?? "MiVista"

        // 2. Preparar archivos temporales
        let ts = Int(Date().timeIntervalSince1970)
        let swiftFile = NSTemporaryDirectory() + "UserCode_\(ts).swift"
        let dylibFile = NSTemporaryDirectory() + "UserCode_\(ts).dylib"
        
        let finalCode = """
import SwiftUI
import UIKit

\(code)

@_cdecl("makeUserView")
public func makeUserView() -> UnsafeMutableRawPointer {
    let vc = UIHostingController(rootView: \(structName)())
    return Unmanaged.passRetained(vc).toOpaque()
}
"""
        try? finalCode.write(toFile: swiftFile, atomically: true, encoding: .utf8)

        DispatchQueue.global(qos: .userInitiated).async {
            // 3. Invocación dinámica de NSTask para evitar SIGABRT en Catalyst
            guard let taskClass = NSClassFromString("NSTask") as? NSObject.Type else {
                DispatchQueue.main.async { self.errorMessage = "Error: NSTask no disponible"; self.isCompiling = false; self.isTaskRunning = false }
                return
            }
            
            let task = taskClass.init()
            let sdk = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
            
            // NOTA: Cambia arm64 por x86_64 si estás en un Mac con Intel
            let args = [
                "-sdk", sdk,
                "-target", "arm64-apple-ios14.0-macabi",
                "-F", "\(sdk)/System/iOSSupport/System/Library/Frameworks",
                "-I", "\(sdk)/System/iOSSupport/usr/include",
                "-emit-library", "-Onone", "-o", dylibFile, swiftFile
            ]
            
            task.setValue("/usr/bin/swiftc", forKey: "launchPath")
            task.setValue(args, forKey: "arguments")
            
            let errorPipe = Pipe()
            task.setValue(errorPipe, forKey: "standardError")
            
            let launchSelector = NSSelectorFromString("launch")
            let waitUntilExitSelector = NSSelectorFromString("waitUntilExit")
            
            if task.responds(to: launchSelector) {
                task.perform(launchSelector)
                task.perform(waitUntilExitSelector)
                
                let status = task.value(forKey: "terminationStatus") as? Int32 ?? -1
                
                if status == 0 {
                    if let handle = dlopen(dylibFile, RTLD_NOW),
                       let sym = dlsym(handle, "makeUserView") {
                        let f = unsafeBitCast(sym, to: (@convention(c) () -> UnsafeMutableRawPointer).self)
                        let ptr = f()
                        
                        DispatchQueue.main.async {
                            let vc = Unmanaged<UIViewController>.fromOpaque(ptr).takeRetainedValue()
                            self.cache.setObject(CachedVC(vc), forKey: hash as NSString)
                            self.remoteVC = vc
                            self.compilationID = UUID()
                            self.errorMessage = ""
                            self.isCompiling = false
                            self.isTaskRunning = false
                        }
                    }
                } else {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    DispatchQueue.main.async {
                        self.errorMessage = errStr
                        self.isCompiling = false
                        self.isTaskRunning = false
                    }
                }
            }
        }
    }
}

//import Runestone
//
//struct TextViewRepresentable: UIViewRepresentable {
//    func updateUIView(_ uiView: UIViewType, context: Context) {
//        
//    }
//    
//    
//    func makeUIView(context: Context) -> some UIView {
//        let tv = TextView()
//        setCustomization(on: tv)
//        return tv
//    }
//    
//    private func setCustomization(on textView: TextView) {
//        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
//        textView.showLineNumbers = true
//        textView.lineHeightMultiplier = 1.2
//        textView.kern = 0.3
//        textView.showSpaces = true
//        textView.showNonBreakingSpaces = true
//        textView.showTabs = true
//        textView.showLineBreaks = true
//        textView.showSoftLineBreaks = true
//        textView.isLineWrappingEnabled = false
//        textView.showPageGuide = true
//        textView.pageGuideColumn = 80
//        textView.autocorrectionType = .no
//        textView.autocapitalizationType = .none
//        textView.smartQuotesType = .no
//        textView.smartDashesType = .no
//    }
//    
//    
//    
//}
