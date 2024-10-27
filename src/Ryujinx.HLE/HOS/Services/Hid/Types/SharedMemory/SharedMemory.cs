using Ryujinx.Common.Memory;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Common;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.DebugPad;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Keyboard;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Mouse;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Npad;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.TouchScreen;
using System;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory
{
    /// <summary>
    /// Represents the shared memory used for input, shared between applications.
    /// </summary>
    [StructLayout(LayoutKind.Explicit, Size = 0x40000)]
    struct SharedMemory
    {
        // Ensure each struct has a defined size and is properly aligned in memory.

        /// <summary>
        /// Debug controller state (size: approximately 0x400).
        /// </summary>
        [FieldOffset(0)]
        public RingLifo<DebugPadState> DebugPad;

        /// <summary>
        /// Touchscreen state (size: approximately 0x3000).
        /// </summary>
        [FieldOffset(0x400)]
        public RingLifo<TouchScreenState> TouchScreen;

        /// <summary>
        /// Mouse state (size: approximately 0x400).
        /// </summary>
        [FieldOffset(0x3400)]
        public RingLifo<MouseState> Mouse;

        /// <summary>
        /// Keyboard state (size: approximately 0x400).
        /// </summary>
        [FieldOffset(0x3800)]
        public RingLifo<KeyboardState> Keyboard;

        /// <summary>
        /// Nintendo Pads (size: approximately 0x800).
        /// </summary>
        [FieldOffset(0x3C00)]
        public Array10<NpadState> Npads;

        /// <summary>
        /// Creates a SharedMemory instance with each component initialized.
        /// </summary>
        public static SharedMemory Create()
        {
            // Initialize each component separately to avoid potential layout issues.
            SharedMemory result = new SharedMemory();
            
            result.DebugPad = RingLifo<DebugPadState>.Create();
            result.TouchScreen = RingLifo<TouchScreenState>.Create();
            result.Mouse = RingLifo<MouseState>.Create();
            result.Keyboard = RingLifo<KeyboardState>.Create();

            // Initialize each Npad state in a loop
            for (int i = 0; i < result.Npads.Length; i++)
            {
                result.Npads[i] = NpadState.Create();
            }

            return result;
        }
    }
}
