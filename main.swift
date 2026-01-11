import Cocoa
import IOKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?

    // 表示設定のキー
    let showCPUKey = "showCPU"
    let showMemoryKey = "showMemory"
    let showGPUKey = "showGPU"
    let showPowerKey = "showPower"

    // メニュー項目
    var cpuMenuItem: NSMenuItem!
    var memoryMenuItem: NSMenuItem!
    var gpuMenuItem: NSMenuItem!
    var powerMenuItem: NSMenuItem!

    // CPU使用率計算用（前回の値を保存）
    var prevCPUInfo: [Int64] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // デフォルト値を設定（初回起動時は全て表示）
        registerDefaults()

        // メニューバーアイテムを作成
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // メニューを設定
        setupMenu()

        // 1秒ごとに更新
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        timer?.fire()
    }

    func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showCPUKey: true,
            showMemoryKey: true,
            showGPUKey: true,
            showPowerKey: true
        ])
    }

    func setupMenu() {
        let menu = NSMenu()

        // 表示項目の設定
        cpuMenuItem = NSMenuItem(title: "CPU", action: #selector(toggleCPU), keyEquivalent: "")
        cpuMenuItem.state = UserDefaults.standard.bool(forKey: showCPUKey) ? .on : .off
        menu.addItem(cpuMenuItem)

        memoryMenuItem = NSMenuItem(title: "Memory", action: #selector(toggleMemory), keyEquivalent: "")
        memoryMenuItem.state = UserDefaults.standard.bool(forKey: showMemoryKey) ? .on : .off
        menu.addItem(memoryMenuItem)

        gpuMenuItem = NSMenuItem(title: "GPU", action: #selector(toggleGPU), keyEquivalent: "")
        gpuMenuItem.state = UserDefaults.standard.bool(forKey: showGPUKey) ? .on : .off
        menu.addItem(gpuMenuItem)

        powerMenuItem = NSMenuItem(title: "Power (W)", action: #selector(togglePower), keyEquivalent: "")
        powerMenuItem.state = UserDefaults.standard.bool(forKey: showPowerKey) ? .on : .off
        menu.addItem(powerMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Donate", action: #selector(openDonate), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func toggleCPU() {
        let current = UserDefaults.standard.bool(forKey: showCPUKey)
        UserDefaults.standard.set(!current, forKey: showCPUKey)
        cpuMenuItem.state = !current ? .on : .off
        updateStatus()
    }

    @objc func toggleMemory() {
        let current = UserDefaults.standard.bool(forKey: showMemoryKey)
        UserDefaults.standard.set(!current, forKey: showMemoryKey)
        memoryMenuItem.state = !current ? .on : .off
        updateStatus()
    }

    @objc func toggleGPU() {
        let current = UserDefaults.standard.bool(forKey: showGPUKey)
        UserDefaults.standard.set(!current, forKey: showGPUKey)
        gpuMenuItem.state = !current ? .on : .off
        updateStatus()
    }

    @objc func togglePower() {
        let current = UserDefaults.standard.bool(forKey: showPowerKey)
        UserDefaults.standard.set(!current, forKey: showPowerKey)
        powerMenuItem.state = !current ? .on : .off
        updateStatus()
    }

    @objc func openDonate() {
        if let url = URL(string: "https://github.com/sponsors/genkigenki1212133") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func updateStatus() {
        var parts: [String] = []

        if UserDefaults.standard.bool(forKey: showCPUKey) {
            let cpu = getCPUUsage()
            parts.append(String(format: "CPU:%.0f%%", cpu))
        }

        if UserDefaults.standard.bool(forKey: showMemoryKey) {
            let memory = getMemoryUsage()
            parts.append(String(format: "MEM:%.0f%%", memory))
        }

        if UserDefaults.standard.bool(forKey: showGPUKey) {
            if let gpu = getGPUUsage() {
                parts.append(String(format: "GPU:%.0f%%", gpu))
            }
        }

        if UserDefaults.standard.bool(forKey: showPowerKey) {
            if let power = getPowerWatts() {
                parts.append(String(format: "%dW", power))
            } else {
                parts.append("--W")
            }
        }

        if let button = statusItem.button {
            button.title = parts.isEmpty ? "---" : parts.joined(separator: " ")
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
    }

    // CPU使用率を取得（差分計算）
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

        let statesPerCPU = Int(CPU_STATE_MAX)
        let totalStates = Int(numCPUs) * statesPerCPU

        // 現在の値を配列に変換
        var currentInfo: [Int64] = []
        for i in 0..<totalStates {
            currentInfo.append(Int64(cpuInfo[i]))
        }

        // メモリ解放
        let cpuInfoSize = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), cpuInfoSize)

        // 前回の値がない、またはサイズが異なる場合は保存して0を返す
        if prevCPUInfo.isEmpty || prevCPUInfo.count != currentInfo.count {
            prevCPUInfo = currentInfo
            return 0.0
        }

        var totalUsage: Double = 0.0

        for i in 0..<Int(numCPUs) {
            let offset = statesPerCPU * i

            // 差分を計算
            let userDiff = currentInfo[offset + Int(CPU_STATE_USER)] - prevCPUInfo[offset + Int(CPU_STATE_USER)]
            let systemDiff = currentInfo[offset + Int(CPU_STATE_SYSTEM)] - prevCPUInfo[offset + Int(CPU_STATE_SYSTEM)]
            let niceDiff = currentInfo[offset + Int(CPU_STATE_NICE)] - prevCPUInfo[offset + Int(CPU_STATE_NICE)]
            let idleDiff = currentInfo[offset + Int(CPU_STATE_IDLE)] - prevCPUInfo[offset + Int(CPU_STATE_IDLE)]

            let totalDiff = userDiff + systemDiff + niceDiff + idleDiff
            let usedDiff = userDiff + systemDiff + niceDiff

            if totalDiff > 0 {
                totalUsage += (Double(usedDiff) / Double(totalDiff)) * 100.0
            }
        }

        // 現在の値を保存
        prevCPUInfo = currentInfo

        return totalUsage / Double(numCPUs)
    }

    // メモリ使用率を取得（Activity Monitor準拠）
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

        // 物理メモリ総量を取得
        var size = MemoryLayout<UInt64>.size
        var totalMemory: UInt64 = 0
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)

        let pageSize = Double(vm_kernel_page_size)
        let totalPages = Double(totalMemory) / pageSize

        // 空きメモリ = free + inactive + purgeable + speculative
        let free = Double(stats.free_count)
        let inactive = Double(stats.inactive_count)
        let purgeable = Double(stats.purgeable_count)
        let speculative = Double(stats.speculative_count)

        let freePages = free + inactive + purgeable + speculative
        let usedPages = totalPages - freePages

        return (usedPages / totalPages) * 100.0
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

    // 現在の消費電力を取得 (mW -> W)
    func getPowerWatts() -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        // PowerTelemetryDataから実際の消費電力を取得
        if let telemetry = props["PowerTelemetryData"] as? [String: Any],
           let powerMw = telemetry["SystemPowerIn"] as? Int {
            return powerMw / 1000  // mW -> W
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
