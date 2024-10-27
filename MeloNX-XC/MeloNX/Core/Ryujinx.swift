//
//  Ryujinx.swift
//  MeloNX
//
//  Created by Stossy11 on 27/10/2024.
//

import Foundation
import SwiftUI

// Create a bridging header for the C function
private let ryujinxMain: @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int32 = {
    let sym = dlsym(dlopen("Ryujinx.Headless.SDL2.dylib", RTLD_NOW), "main_ryujinx_sdl")
    return unsafeBitCast(sym, to: (@convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int32).self)
}()

enum RyujinxError: Error {
    case libraryLoadError
    case executionError(code: Int32)
    case alreadyRunning
    case notRunning
}

class RyujinxEmulator {
    private var isRunning = false
    private var emulationThread: Thread?
    
    struct Configuration {
        let inputPath: String
        let enableKeyboard: Bool // i don't know why i added this
        let graphicsBackend: String
        var additionalArgs: [String]
        
        init(
            inputPath: String,
            enableKeyboard: Bool = true,
            graphicsBackend: String = "Vulkan",
            additionalArgs: [String] = []
        ) {
            self.inputPath = inputPath
            self.enableKeyboard = enableKeyboard
            self.graphicsBackend = graphicsBackend
            self.additionalArgs = additionalArgs
        }
    }
    
    private static func start(with config: Configuration) throws {
        
        var args: [String] = []
        // Taken from the POC
        /*
        var args: [String] = [
            "--enable-debug-logs", "false", "--enable-trace-logs", "false", "--memory-manager-mode",
            "SoftwarePageTable",
            "--graphics-backend",
            "Vulkan",
            //"--enable-fs-integrity-checks", "false",
            "--input-id-1", "0",
            // "--list-inputs-ids", "true",
            config.inputPath,
        ]
         */
        
        args.append(config.inputPath)
        args.append("--graphics-backend")
        args.append(config.graphicsBackend)
        args.append(contentsOf: ["--memory-manager-mode", "SoftwarePageTable"])
        // args.append(contentsOf: ["--fullscreen", "true"])
        args.append(contentsOf: ["--enable-debug-logs", "true"])
        args.append(contentsOf: ["--enable-trace-logs", "true"])
        // args.append("--input-path")
        
        args.append(contentsOf: config.additionalArgs)
        
        let cArgs = args.map { strdup($0) }
        defer {
            cArgs.forEach { ptr in
                if let ptr = ptr {
                    free(ptr)
                }
            }
        }
        
        var argvPtrs = cArgs
        
        
        let result = ryujinxMain(Int32(args.count), &argvPtrs)
        
        if result != 0 {
            throw RyujinxError.executionError(code: result)
        }
    }
    
    // cray z
    func startWithRunLoop(config: Configuration) throws {
        guard !isRunning else {
            throw RyujinxError.alreadyRunning
        }
        
        isRunning = true
        
        emulationThread = Thread {
            let runLoop = RunLoop.current
            
            let port = Port()
            runLoop.add(port, forMode: .default)
            
            DispatchQueue.main.async {
                do {
                    try Self.start(with: config)
                } catch {
                    Self.log("Emulation failed to start: \(error)")
                    self.isRunning = false
                    return
                }
            }
            
            
            
            while self.isRunning && runLoop.run(mode: .default, before: .distantFuture) {
                autoreleasepool {
                }
            }
            
            
            Self.log("Emulation loop ended")
        }
        
        emulationThread?.name = "RyujinxEmulationThread"
        emulationThread?.qualityOfService = .userInteractive
        emulationThread?.threadPriority = 0.9
        emulationThread?.start()
    }
    
    func quickStart(romPath: String) throws {
        let config = Configuration(inputPath: romPath)
        try startWithRunLoop(config: config)
    }
    
    /// Stops the emulator
    func stop() throws {
        guard isRunning else {
            throw RyujinxError.notRunning
        }
        
        isRunning = false
        emulationThread?.cancel()
        emulationThread = nil
    }
    
    var running: Bool {
        return isRunning
    }
    
    static func log(_ message: String) {
        print("[Ryujinx] \(message)")
    }
}

extension RyujinxEmulator.Configuration {
    var toCommandLineArgs: [String] {
        var args: [String] = []
        
        args.append(inputPath)
        
        if enableKeyboard {
            args.append("--enable-keyboard")
        }
        
        args.append("--graphics-backend")
        args.append(graphicsBackend)
        
        args.append(contentsOf: additionalArgs)
        
        return args
    }
    
    /// Create configuration from command line arguments
    static func fromCommandLineArgs(_ args: [String]) -> RyujinxEmulator.Configuration? {
        var inputPath: String?
        var enableKeyboard = false
        var graphicsBackend = "Vulkan"
        var additionalArgs: [String] = []
        
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--enable-keyboard":
                enableKeyboard = true
            case "--graphics-backend":
                i += 1
                if i < args.count {
                    graphicsBackend = args[i]
                }
            default:
                additionalArgs.append(args[i])
            }
            i += 1
        }
        
        guard let inputPath = inputPath else {
            return nil
        }
        
        return RyujinxEmulator.Configuration(
            inputPath: inputPath,
            enableKeyboard: enableKeyboard,
            graphicsBackend: graphicsBackend,
            additionalArgs: additionalArgs
        )
    }
}

// MARK: - Code Taken from POC
var g_HookMmapReserved4GB: UnsafeMutableRawPointer! = nil
var g_HookMmapReservedJitCache: UnsafeMutableRawPointer! = nil

func initHookMmap() -> Bool {
    // Hack: if out of memory, you can reserve less (e.g. around 0xc000_0000 or even 0x8000_0000) but it'll crash later
    let reserve4GBSize = 0x1_0000_0000
    g_HookMmapReserved4GB = mmap(
        nil, reserve4GBSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    if g_HookMmapReserved4GB == MAP_FAILED {
        print("can't allocate 4gb")
        return false
    }
    let reserveJitCacheSize = 0x8000_0000
    g_HookMmapReservedJitCache = mmap(
        nil, reserveJitCacheSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)
    if g_HookMmapReservedJitCache == MAP_FAILED {
        print("can't allocate jit cache")
        return false
    }
    if !reallocateAreaWithOwnership(address: g_HookMmapReserved4GB, size: reserve4GBSize) {
        print("can't reallocate area with ownership for 4gb")
        return false
    }
    if !reallocateAreaWithOwnership(address: g_HookMmapReservedJitCache, size: reserveJitCacheSize) {
        print("can't reallocate area with ownership for jitcache")
        return false
    }
    
    print("Allocated Needed Ram")
    
    return true
}

func hookMmap(
  addr: UnsafeMutableRawPointer?, len: Int, prot: Int32, flags: Int32, fd: Int32, offset: off_t
) -> UnsafeMutableRawPointer! {
  print("mmap hook! \(String(describing: addr)) \(len) \(prot) \(flags)")
  // TODO(zhuowei): threads?
  if g_HookMmapReserved4GB != nil && len == 0x1_0000_0000 {
    let ret = g_HookMmapReserved4GB
    g_HookMmapReserved4GB = nil
    print("returning 4gb: \(ret!)")
    return ret
  }
  if g_HookMmapReservedJitCache != nil && len == 0x7ff0_0000 {
    // Hack: it wants 2GB; give it smaller
    let ret = g_HookMmapReservedJitCache
    g_HookMmapReservedJitCache = nil
    print("returning jitcache: \(ret!)")
    return ret
  }
  return mmap(addr, len, prot, flags, fd, offset)
}

func reallocateAreaWithOwnership(address: UnsafeMutableRawPointer, size: Int) -> Bool {
  let addressBase: mach_vm_address_t = mach_vm_address_t(UInt(bitPattern: address))
  let mapChunkSize = 128 * 1024 * 1024
  for off in stride(from: 0, to: size, by: mapChunkSize) {
    let targetSize = memory_object_size_t(min(mapChunkSize, size - off))
    var memoryObjectSize = targetSize
    var memoryObjectPort: mach_port_t = 0
    let err = mach_make_memory_entry_64(
      mach_task_self_, &memoryObjectSize, 0,
      MAP_MEM_NAMED_CREATE | MAP_MEM_LEDGER_TAGGED | VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE,
      &memoryObjectPort, /*parent_entry=*/ 0)
    if err != 0 {
      print("mach_make_memory_entry_64 returned error: \(String(cString: mach_error_string(err)!))")
      return false
    }
    defer { mach_port_deallocate(mach_task_self_, memoryObjectPort) }
    if memoryObjectSize != targetSize {
      print("size is wrong?! \(memoryObjectSize) \(targetSize)")
      return false
    }
    let err2 = mach_memory_entry_ownership(
      memoryObjectPort, TASK_NULL, VM_LEDGER_TAG_DEFAULT, VM_LEDGER_FLAG_NO_FOOTPRINT)
    if err2 != 0 {
      print(
        "mach_memory_entry_ownership returned error: \(String(cString: mach_error_string(err2)!))")
      return false
    }
    let targetMapAddress: vm_address_t = vm_address_t(addressBase) + vm_address_t(off)
    var mapAddress = targetMapAddress
    let err3 = vm_map(
      mach_task_self_, &mapAddress, vm_size_t(memoryObjectSize), /*mask=*/ 0, /*flags=*/
      VM_FLAGS_OVERWRITE,
      memoryObjectPort, /*offset=*/ 0, /*copy=*/ 0, VM_PROT_READ | VM_PROT_WRITE,
      VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE, VM_INHERIT_COPY)
    if err3 != 0 {
      print("vm_map returned error: \(String(cString: mach_error_string(err3)!))")
      return false
    }
    if mapAddress != targetMapAddress {
      print("map address wrong")
      return false
    }
  }
  return true
}

typealias SystemNative_Open_Type = @convention(c) (
  _ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: Int32
) -> Int

var real_SystemNative_Open: SystemNative_Open_Type!
func hook_SystemNative_Open(path: UnsafePointer<CChar>, flags: Int32, mode: Int32) -> Int {
  let fileName = String(cString: path)
  print("opening \(fileName)")
  return real_SystemNative_Open(path, flags, mode)
}


func pInvokeOverride(libraryName: UnsafePointer<CChar>!, entrypointName: UnsafePointer<CChar>!)
  -> UnsafeRawPointer?
{
  let libraryName = String(cString: libraryName)
  let entrypointName = String(cString: entrypointName)
  // print(libraryName, entrypointName)
  if entrypointName == "mmap" {
    typealias MmapType = @convention(c) (
      _: UnsafeMutableRawPointer?, _: Int, _: Int32, _: Int32, _: Int32, _: off_t
    ) -> UnsafeMutableRawPointer?
    return unsafeBitCast(hookMmap as MmapType, to: UnsafeRawPointer.self)
  } else if entrypointName == "SystemNative_Open" {
    let handle = dlopen("libSystem.Native.dylib", RTLD_LOCAL | RTLD_LAZY)
    real_SystemNative_Open = unsafeBitCast(
      dlsym(handle, "SystemNative_Open"), to: SystemNative_Open_Type.self)
    return unsafeBitCast(
      hook_SystemNative_Open as SystemNative_Open_Type, to: UnsafeRawPointer.self)
  }
  return nil
}
