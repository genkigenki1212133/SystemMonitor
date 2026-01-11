import Cocoa
import IOKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // メニューバーアイテムを作成
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // メニューを設定
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        // 1秒ごとに更新
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        timer?.fire()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func updateStatus() {
        let cpu = getCPUUsage()
        let memory = getMemoryUsage()
        let gpu = getGPUUsage()

        if let button = statusItem.button {
            if let gpu = gpu {
                button.title = String(format: "CPU:%.0f%% MEM:%.0f%% GPU:%.0f%%", cpu, memory, gpu)
            } else {
                button.title = String(format: "CPU:%.0f%% MEM:%.0f%% GPU:--", cpu, memory)
            }
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
    }

    // CPU使用率を取得
    func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let err = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCPUs,
                                       &cpuInfo,
                                       &numCpuInfo)

        guard err == KERN_SUCCESS, let cpuInfo = cpuInfo else {
            return 0.0
        }

        var totalUsage: Double = 0.0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])
            let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])

            let total = user + system + nice + idle
            let used = user + system + nice

            if total > 0 {
                totalUsage += (used / total) * 100.0
            }
        }

        // メモリ解放
        let cpuInfoSize = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), cpuInfoSize)

        return totalUsage / Double(numCPUs)
    }

    // メモリ使用率を取得
    func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0.0
        }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize

        // 物理メモリ総量を取得
        var size = MemoryLayout<UInt64>.size
        var totalMemory: UInt64 = 0
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)

        let used = active + wired + compressed
        let total = Double(totalMemory)

        return (used / total) * 100.0
    }

    // GPU使用率を取得 (Apple Silicon)
    func getGPUUsage() -> Double? {
        let matchingDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return nil
        }

        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // PerformanceStatisticsからDevice Utilization %を取得
            if let perfStats = props["PerformanceStatistics"] as? [String: Any],
               let utilization = perfStats["Device Utilization %"] as? Int {
                return Double(utilization)
            }
        }

        return nil
    }
}

// アプリを起動
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // Dockに表示しない
app.run()
