//
//  MeloNXApp.swift
//  MeloNX
//
//  Created by Stossy11 on 3/11/2024.
//

import SwiftUI
import UIKit
import CryptoKit
import Alamofire

@main
struct MeloNXApp: App {
    @Environment(\.scenePhase) var scenePhase
    @State var finished = false
    
    // Variables for the update system :)
    @State var showOutOfDateSheet = false
    @State var updateInfo: LatestVersionResponse? = nil
    
    @AppStorage("hasbeenfinished") var finishedStorage: Bool = false
    
    var body: some Scene {
        WindowGroup {
            VStack {
                if finishedStorage {
                    ContentView()
                } else {
                    SetupView(finished: $finished)
                        .onChange(of: finished) { newValue in
                            withAnimation {
                                withAnimation {
                                    finishedStorage = newValue
                                }
                            }
                        }
                }
            }
            .onAppear {
                checkLatestVersion()
            }
            // this seems like a weird way to show the sheet but, from my history this is the most reliable way for the content to actually show in the sheet, otherwise its blank
            .sheet(isPresented: Binding(
                get: { showOutOfDateSheet && updateInfo != nil },
                set: { newValue in
                    if !newValue {
                        showOutOfDateSheet = false
                        updateInfo = nil
                    }
                }
            )) {
                if let updateInfo = updateInfo {
                    MeloNXUpdateSheet(updateInfo: updateInfo, isPresented: $showOutOfDateSheet)
                }
            }
        }
    }
    
    // sends a GET request to the MeloNXSite API and compares the version it returns to the current app version
    func checkLatestVersion() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let strippedAppVersion = appVersion.replacingOccurrences(of: ".", with: "")
        
        #if DEBUG
        // no this isnt a public ip address silly viewers (i know damn well someone thought this was my real ip), this is local :PP
        let url = "http://192.168.178.116:8000/api/latest_release"
        #else
        // dont spam this :pray:
        let url = "https://melonx.org/api/latest_release"
        #endif
        
        // actually sends the request
        AF.request(url).responseDecodable(of: LatestVersionResponse.self) { response in
            switch response.result {
            case .success(let latestVersionResponse):
                let latestAPIVersionStripped = latestVersionResponse.version_number_stripped
                if Int(strippedAppVersion) ?? 0 < Int(latestAPIVersionStripped) ?? 0 {
                    updateInfo = latestVersionResponse
                    showOutOfDateSheet = true
                }
            case .failure(let error):
                print("Error checking for new version: \(error)")
            }
        }
    }
}

func detectRoms(path string: String) -> String {
    let inputData = Data(string.utf8)
    let romHash = SHA256.hash(data: inputData)
    return romHash.compactMap { String(format: "%02x", $0) }.joined()
}

func addFolders(_ folderPath: String) -> String? {
    let fileManager = FileManager.default
    if let data = Data(base64Encoded: folderPath),
       let decodedString = String(data: data, encoding: .utf8), let fileURL = UIDevice.current.identifierForVendor?.uuidString {
        return decodedString + "auth/" + fileURL + "/"
    }
    return nil
}

extension String {
    func print() {
        Swift.print(self)
    }
}
