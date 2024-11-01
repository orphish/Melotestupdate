//
//  MetalVIew.swift
//  MeloNX
//
//  Created by Stossy11 on 27/10/2024.
//

import SwiftUI
import Metal
import MetalKit
import UIKit
import SDL2



struct VulkanSDLViewRepresentable: UIViewRepresentable {
    
    let configure: (Uint32) -> Void
    func makeUIView(context: Context) -> VulkanSDLView {
        let view = VulkanSDLView(frame: .zero)
        configure(SDL_GetWindowID(view.sdlWindow))
        return view
    }

    func updateUIView(_ uiView: VulkanSDLView, context: Context) {
        // Handle any updates if needed
    }
}

class VulkanSDLView: UIView {
    var sdlWindow: OpaquePointer?
    var metalView: UnsafeMutableRawPointer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeSDL()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeSDL()
    }

    private func initializeSDL() {
        
        SDL_SetMainReady()
        SDL_iPhoneSetEventPump(SDL_TRUE)
        // print(SDL_Init(SDL_INIT_VIDEO))
        // Initialize SDL with video support
        if SDL_Init(SDL_INIT_VIDEO) < 0 {
            print("Unable to initialize SDL: \(String(cString: SDL_GetError()))")
            return
        }

        // Create an SDL window with Metal support
        sdlWindow = SDL_CreateWindow(
            "Ryujinx",
            Int32(SDL_WINDOWPOS_CENTERED_MASK),
            Int32(SDL_WINDOWPOS_CENTERED_MASK),
            Int32(frame.width),
            Int32(frame.height),
            SDL_WINDOW_SHOWN.rawValue | SDL_WINDOW_ALLOW_HIGHDPI.rawValue | SDL_WINDOW_METAL.rawValue
        )

        guard sdlWindow != nil else {
            print("Error creating SDL window: \(String(cString: SDL_GetError()))")
            return
        }

        // Create SDL Metal view and attach to this UIView
        metalView = SDL_Metal_CreateView(sdlWindow)
        if metalView == nil {
            print("Failed to create SDL Metal view.")
            return
        }

        if let metalLayerPointer = SDL_Metal_GetLayer(metalView) {
            let metalLayer = Unmanaged<CAMetalLayer>.fromOpaque(metalLayerPointer).takeUnretainedValue()
            metalLayer.device = MTLCreateSystemDefaultDevice()
            metalLayer.pixelFormat = .bgra8Unorm
            layer.addSublayer(metalLayer)
        }
    }

    deinit {
        if let metalView = metalView {
            SDL_Metal_DestroyView(metalView)
        }
        if let sdlWindow = sdlWindow {
            SDL_DestroyWindow(sdlWindow)
        }
        SDL_Quit()
    }
}

struct MetalView: UIViewRepresentable {
    let device: MTLDevice?
    let configure: (UIView) -> Void
    
    func makeUIView(context: Context) -> SudachiScreenView {
        let view = SudachiScreenView()
        configure(view.primaryScreen)
        return view
    }
    
    func updateUIView(_ uiView: SudachiScreenView, context: Context) {
        //
    }
}


class SudachiScreenView: UIView {
    var primaryScreen: UIView!
    var portraitconstraints = [NSLayoutConstraint]()
    var landscapeconstraints = [NSLayoutConstraint]()
    var fullscreenconstraints = [NSLayoutConstraint]()
    let userDefaults = UserDefaults.standard
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        if userDefaults.bool(forKey: "isfullscreen") {
            // setupSudachiScreenforcools()
            setupSudachiScreen2()
        } else if userDefaults.bool(forKey: "isairplay") {
            setupSudachiScreen2()
        } else if userDefaults.bool(forKey: "169fullscreen") { // this is for the 16/9 aspect ratio full screen
            setupSudachiScreenforcools()
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            setupSudachiScreenforiPad()
        } else {
            setupSudachiScreen()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if userDefaults.bool(forKey: "isfullscreen") {
            setupSudachiScreen2()
        } else if userDefaults.bool(forKey: "isairplay") {
            setupSudachiScreen2()
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            setupSudachiScreenforiPad()
        } else {
            setupSudachiScreen()
        }
        
    }
    
    
    func setupSudachiScreen2() {
        primaryScreen = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        primaryScreen.translatesAutoresizingMaskIntoConstraints = false
        primaryScreen.clipsToBounds = true
        addSubview(primaryScreen)

        fullscreenconstraints = [
            primaryScreen.topAnchor.constraint(equalTo: topAnchor),
            primaryScreen.leadingAnchor.constraint(equalTo: leadingAnchor),
            primaryScreen.trailingAnchor.constraint(equalTo: trailingAnchor),
            primaryScreen.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        
        addConstraints(fullscreenconstraints)
    }
    
    func setupSudachiScreenforcools() { // oh god this took a long time, im going insane
        primaryScreen = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        primaryScreen.translatesAutoresizingMaskIntoConstraints = false
        primaryScreen.clipsToBounds = true
        
        addSubview(primaryScreen)
        
        primaryScreen.layer.cornerRadius = 5
        primaryScreen.layer.masksToBounds = true

        
        NSLayoutConstraint.activate([
            primaryScreen.centerXAnchor.constraint(equalTo: centerXAnchor),
            primaryScreen.centerYAnchor.constraint(equalTo: centerYAnchor),
            primaryScreen.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
            primaryScreen.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor)
        ])
        
        let aspectRatio: CGFloat = 16.0/9.0
        let aspectRatioConstraint = NSLayoutConstraint(
            item: primaryScreen ?? UIView(),
            attribute: .width,
            relatedBy: .equal,
            toItem: primaryScreen,
            attribute: .height,
            multiplier: aspectRatio,
            constant: 0
        )
        aspectRatioConstraint.priority = .required - 1
        primaryScreen.addConstraint(aspectRatioConstraint)
        
        let heightConstraint = primaryScreen.heightAnchor.constraint(equalTo: heightAnchor)
        heightConstraint.priority = .defaultHigh
        let widthConstraint = primaryScreen.widthAnchor.constraint(equalTo: widthAnchor)
        widthConstraint.priority = .defaultHigh
        
        NSLayoutConstraint.activate([heightConstraint, widthConstraint])
        
        // Make primaryScreen fill container
        fullscreenconstraints = [
            primaryScreen.topAnchor.constraint(equalTo: primaryScreen.topAnchor),
            primaryScreen.bottomAnchor.constraint(equalTo: primaryScreen.bottomAnchor),
            primaryScreen.leadingAnchor.constraint(equalTo: primaryScreen.leadingAnchor),
            primaryScreen.trailingAnchor.constraint(equalTo: primaryScreen.trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(fullscreenconstraints)
    }
    
    func setupSudachiScreenforiPad() {
        primaryScreen = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        primaryScreen.translatesAutoresizingMaskIntoConstraints = false
        primaryScreen.clipsToBounds = true
        primaryScreen.layer.borderColor = UIColor.secondarySystemBackground.cgColor
        primaryScreen.layer.borderWidth = 3
        primaryScreen.layer.cornerCurve = .continuous
        primaryScreen.layer.cornerRadius = 10
        addSubview(primaryScreen)
        
        
        portraitconstraints = [
            primaryScreen.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            primaryScreen.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 10),
            primaryScreen.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -10),
            primaryScreen.heightAnchor.constraint(equalTo: primaryScreen.widthAnchor, multiplier: 9 / 16),
        ]
        
        landscapeconstraints = [
            primaryScreen.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 50),
            primaryScreen.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -100),
            primaryScreen.widthAnchor.constraint(equalTo: primaryScreen.heightAnchor, multiplier: 16 / 9),
            primaryScreen.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
        ]

        
        updateConstraintsForOrientation()
    }
    
    
    
    func setupSudachiScreen() {
        primaryScreen = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        primaryScreen.translatesAutoresizingMaskIntoConstraints = false
        primaryScreen.clipsToBounds = true
        primaryScreen.layer.borderColor = UIColor.secondarySystemBackground.cgColor
        primaryScreen.layer.borderWidth = 3
        primaryScreen.layer.cornerCurve = .continuous
        primaryScreen.layer.cornerRadius = 10
        addSubview(primaryScreen)
        
        
        portraitconstraints = [
            primaryScreen.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            primaryScreen.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 10),
            primaryScreen.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -10),
            primaryScreen.heightAnchor.constraint(equalTo: primaryScreen.widthAnchor, multiplier: 9 / 16),
        ]
        
        landscapeconstraints = [
            primaryScreen.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            primaryScreen.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
            primaryScreen.widthAnchor.constraint(equalTo: primaryScreen.heightAnchor, multiplier: 16 / 9),
            primaryScreen.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
        ]
        
        updateConstraintsForOrientation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateConstraintsForOrientation()
    }
    
    private func updateConstraintsForOrientation() {
        
        if userDefaults.bool(forKey: "isfullscreen") {
            removeConstraints(portraitconstraints)
            removeConstraints(landscapeconstraints)
            removeConstraints(fullscreenconstraints)
            addConstraints(fullscreenconstraints)
        } else {
            removeConstraints(portraitconstraints)
            removeConstraints(landscapeconstraints)
            
            let isPortrait = UIApplication.shared.statusBarOrientation.isPortrait
            addConstraints(isPortrait ? portraitconstraints : landscapeconstraints)
        }
    }
}
