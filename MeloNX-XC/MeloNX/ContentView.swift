//
//  ContentView.swift
//  MeloNX
//
//  Created by Stossy11 on 27/10/2024.
//

import SwiftUI
import SDL2
import GameController

var theWindow: UIWindow? = nil

struct ContentView: View {
    @State var device: MTLDevice? = MTLCreateSystemDefaultDevice()
    @State var gameUrl: URL?
    @State var showFileImporter: Bool = false
    @State var emulationStarted: Bool = false
    @State var mainThread: Bool = false
    
    @State var debugmode: Int = 0
    
    var body: some View {
        ZStack {
            if let gameUrl, emulationStarted {
                VulkanSDLViewRepresentable { displayid in
                    gameUrl.startAccessingSecurityScopedResource()
                    
                    let config = RyujinxEmulator.Configuration(
                        inputPath: gameUrl.path,
                        mainThread: mainThread,
                        graphicsBackend: "Vulkan",
                        additionalArgs: ["--display-id", String(displayid)]
                    )
                    
                    
                    
                    showVirtualController(url: gameUrl, ryuconfig: config)
                }
            }
            
            VStack {
                Text("NX iOS")
                    .font(.largeTitle)
                    .onTapGesture {
                        debugmode += 1
                    }
                    .padding()
                
                if debugmode > 9 {
                    Text("Debug Mode:")
                        .font(.title)
                    Text("Is on Main Thread?: \(mainThread)")
                        .font(.title2)
                    Toggle(isOn: $mainThread) {
                        Text("Use Main Thread")
                    }
                }
                
                Button {
                    showFileImporter.toggle()
                } label: {
                    Text("Select Game")
                }
                if let gameUrl {
                    Button {
                        emulationStarted = true
                    } label: {
                        Text("Go!")
                    }
                    .padding(8)
                }
            }
        }
        .padding()
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url):
                gameUrl = url
            case .failure(let err):
                print(err.localizedDescription)
            }
        }
    }
}

func startEmulation(game: URL, config: RyujinxEmulator.Configuration) {
    setenv("DOTNET_EnableDiagnostics", "0", 1)
    setenv("HOME", String(validatingUTF8: getenv("HOME"))! + "/Documents", 1)
    setenv("MVK_CONFIG_LOG_LEVEL", "4", 1)
    
    let config = config
    
    // patchMakeKeyAndVisible()
    
    let window = SDL_CreateWindow("Ryujinx", Int32(SDL_WINDOWPOS_CENTERED_MASK), Int32(SDL_WINDOWPOS_CENTERED_MASK), 640, 480, SDL_WINDOW_SHOWN.rawValue | SDL_WINDOW_ALLOW_HIGHDPI.rawValue)
    if window == nil {
        print("Error creating SDL window: \(String(cString: SDL_GetError()))")
    } else {
        print("SDL Window created successfully!")
    }
    
    // SDL_Init(SDL_INIT_VIDEO)
    
    let emulator = RyujinxEmulator()
    do {
        try emulator.startWithRunLoop(config: config)
    } catch {
        print(error)
    }
}

func patchMakeKeyAndVisible() {
  let uiwindowClass = UIWindow.self
  let m1 = class_getInstanceMethod(uiwindowClass, #selector(UIWindow.makeKeyAndVisible))!
  let m2 = class_getInstanceMethod(uiwindowClass, #selector(UIWindow.wdb_makeKeyAndVisible))!
  method_exchangeImplementations(m1, m2)
}

extension UIWindow {
    @objc func wdb_makeKeyAndVisible() {
        print("Making window key and visible...")
        if #available(iOS 13.0, *) {
            self.windowScene = (UIApplication.shared.connectedScenes.first! as! UIWindowScene)
        }
        self.wdb_makeKeyAndVisible()
        theWindow = self
    }
}

@available(iOS 15.0, *)
var g_gcVirtualController: GCVirtualController!
@available(iOS 15.0, *)
func showVirtualController(url: URL, ryuconfig: RyujinxEmulator.Configuration) {
    print("Showing virtual controller...")
    let config = GCVirtualController.Configuration()
    config.elements = [
        GCInputDirectionalDpad, GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY,
    ]
    g_gcVirtualController = GCVirtualController(configuration: config)
    g_gcVirtualController.connect { err in
        print("Controller connect: \(String(describing: err))")
        startEmulation(game: url, config: ryuconfig)
    }
}

@available(iOS 15.0, *)
func reconnectVirtualController() {
    print("Reconnecting virtual controller...")
    g_gcVirtualController.disconnect()
    DispatchQueue.main.async {
        g_gcVirtualController.connect { err in
            print("Reconnected: err \(String(describing: err))")
        }
    }
}
