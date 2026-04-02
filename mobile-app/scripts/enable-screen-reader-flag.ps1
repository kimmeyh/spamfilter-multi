# Temporarily enable the screen reader system flag to activate Flutter semantics tree
# This does NOT start an actual screen reader - it just sets the SPI_SETSCREENREADER flag

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ScreenReader {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

    public const uint SPI_SETSCREENREADER = 0x0047;
    public const uint SPI_GETSCREENREADER = 0x0046;
    public const uint SPIF_SENDCHANGE = 0x0002;

    public static bool Enable() {
        return SystemParametersInfo(SPI_SETSCREENREADER, 1, IntPtr.Zero, SPIF_SENDCHANGE);
    }

    public static bool Disable() {
        return SystemParametersInfo(SPI_SETSCREENREADER, 0, IntPtr.Zero, SPIF_SENDCHANGE);
    }

    public static bool IsEnabled() {
        IntPtr result = Marshal.AllocHGlobal(4);
        SystemParametersInfo(SPI_GETSCREENREADER, 0, result, 0);
        bool val = Marshal.ReadInt32(result) != 0;
        Marshal.FreeHGlobal(result);
        return val;
    }
}
"@

$action = if ($args[0]) { $args[0] } else { "enable" }

if ($action -eq "status") {
    $status = [ScreenReader]::IsEnabled()
    Write-Output "Screen reader flag: $status"
} elseif ($action -eq "enable") {
    Write-Output "Before: $([ScreenReader]::IsEnabled())"
    $result = [ScreenReader]::Enable()
    Start-Sleep -Seconds 1
    Write-Output "After: $([ScreenReader]::IsEnabled()) (SystemParametersInfo returned: $result)"
} elseif ($action -eq "disable") {
    $result = [ScreenReader]::Disable()
    Write-Output "Screen reader flag disabled: $([ScreenReader]::IsEnabled())"
}
