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
    @State var gameUrl: URL?
    @State var showFileImporter: Bool = false
    var body: some View {
        VStack {
            Button {
                showFileImporter.toggle()
            } label: {
                Text("Select Game")
            }
            if let gameUrl {
                Button {
                    DispatchQueue.main.async {
                        showVirtualController(url: gameUrl)
                    }
                } label: {
                    Text("Go!")
                }
                .padding(8)
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

func startEmulation(game: URL) {
    
    setenv("DOTNET_EnableDiagnostics", "0", 1)
    setenv("HOME", String(validatingUTF8: getenv("HOME"))! + "/Documents", 1)
    setenv("MVK_CONFIG_LOG_LEVEL", "4", 1)
    
    let config = RyujinxEmulator.Configuration(
        inputPath: game.path,
        enableKeyboard: false,
        graphicsBackend: "Vulkan"
    )
    DispatchQueue.main.async {
        SDL_SetMainReady()
        SDL_iPhoneSetEventPump(SDL_TRUE)
        patchMakeKeyAndVisible()
    }
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
        if #available(iOS 15.0, *) {
            reconnectVirtualController()
        }
    }
}

@available(iOS 15.0, *)
var g_gcVirtualController: GCVirtualController!
@available(iOS 15.0, *)
func showVirtualController(url: URL) {
    print("Showing virtual controller...")
    let config = GCVirtualController.Configuration()
    config.elements = [
        GCInputDirectionalDpad, GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY,
    ]
    g_gcVirtualController = GCVirtualController(configuration: config)
    g_gcVirtualController.connect { err in
        print("Controller connect: \(String(describing: err))")
        startEmulation(game: url)
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
