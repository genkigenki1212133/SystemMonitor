import Cocoa
import IOKit
import ServiceManagement

private enum Constants {
    /// タイマーの更新間隔（秒）
    static let timerInterval: TimeInterval = 1.0
    /// メニューバーのフォントサイズ
    static let menuBarFontSize: CGFloat = 12
    /// ミリワットからワットへの変換係数
    static let milliwattsPerWatt: Int = 1000
    /// 高負荷の閾値（%）
    static let highLoadThreshold: Double = 80
    /// 中負荷の閾値（%）
    static let mediumLoadThreshold: Double = 50
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?

    // 表示設定のキー
    let showCPUKey = "showCPU"
    let showMemoryKey = "showMemory"
    let showGPUKey = "showGPU"
    let showPowerKey = "showPower"
    let showNetworkKey = "showNetwork"

    // メニュー項目
    var cpuMenuItem: NSMenuItem!
    var memoryMenuItem: NSMenuItem!
    var gpuMenuItem: NSMenuItem!
    var powerMenuItem: NSMenuItem!
    var networkMenuItem: NSMenuItem!
    var launchAtLoginMenuItem: NSMenuItem!

    // ネットワーク速度計算用
    var prevNetworkBytes: (sent: UInt64, received: UInt64) = (0, 0)
    var prevNetworkTime: Date?

    // CPU使用率計算用（前回の値を保存）
    var prevCPUInfo: [Int64] = []

    // バッテリーの有無（キャッシュ）
    lazy var deviceHasBattery: Bool = hasBattery()

    /// バッテリーの有無を確認する
    /// デスクトップMac（iMac, Mac mini, Mac Studio, Mac Pro）にはバッテリーがないため、
    /// AppleSmartBatteryサービスの存在で判定する
    func hasBattery() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            IOObjectRelease(service)
            return true
        }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // デフォルト値を設定（初回起動時は全て表示）
        registerDefaults()

        // メニューバーアイテムを作成
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // メニューを設定
        setupMenu()

        // 1秒ごとに更新
        timer = Timer.scheduledTimer(withTimeInterval: Constants.timerInterval, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        timer?.fire()
    }

    func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showCPUKey: true,
            showMemoryKey: true,
            showGPUKey: true,
            showPowerKey: true,
            showNetworkKey: true
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

        // バッテリーがある場合のみ電力メニュー項目を追加
        if deviceHasBattery {
            powerMenuItem = NSMenuItem(title: "Power (W)", action: #selector(togglePower), keyEquivalent: "")
            powerMenuItem.state = UserDefaults.standard.bool(forKey: showPowerKey) ? .on : .off
            menu.addItem(powerMenuItem)
        }

        networkMenuItem = NSMenuItem(title: "Network", action: #selector(toggleNetwork), keyEquivalent: "")
        networkMenuItem.state = UserDefaults.standard.bool(forKey: showNetworkKey) ? .on : .off
        menu.addItem(networkMenuItem)

        menu.addItem(NSMenuItem.separator())

        launchAtLoginMenuItem = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Donate", action: #selector(openDonate), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    /// 汎用トグル関数: UserDefaultsの値を反転し、メニュー項目の状態を更新
    private func toggle(key: String, menuItem: NSMenuItem) {
        let current = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(!current, forKey: key)
        menuItem.state = !current ? .on : .off
        updateStatus()
    }

    @objc func toggleCPU() {
        toggle(key: showCPUKey, menuItem: cpuMenuItem)
    }

    @objc func toggleMemory() {
        toggle(key: showMemoryKey, menuItem: memoryMenuItem)
    }

    @objc func toggleGPU() {
        toggle(key: showGPUKey, menuItem: gpuMenuItem)
    }

    @objc func togglePower() {
        toggle(key: showPowerKey, menuItem: powerMenuItem)
    }

    @objc func toggleNetwork() {
        toggle(key: showNetworkKey, menuItem: networkMenuItem)
    }

    @objc func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                    launchAtLoginMenuItem.state = .off
                } else {
                    try service.register()
                    launchAtLoginMenuItem.state = .on
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc func openDonate() {
        if let url = URL(string: "https://github.com/sponsors/genkigenki1212133") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// 負荷レベルに応じた色を返す
    /// - Parameter percentage: 負荷のパーセンテージ（0-100）
    /// - Returns: 負荷レベルに対応するNSColor
    func colorForLoad(_ percentage: Double) -> NSColor {
        if percentage >= Constants.highLoadThreshold {
            return .systemRed
        } else if percentage >= Constants.mediumLoadThreshold {
            return .systemOrange
        } else {
            return .labelColor
        }
    }

    func updateStatus() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: Constants.menuBarFontSize, weight: .regular)
        let attributedString = NSMutableAttributedString()

        /// 区切りのスペースを追加するヘルパー関数
        func appendSeparatorIfNeeded() {
            if attributedString.length > 0 {
                attributedString.append(NSAttributedString(string: " ", attributes: [.font: font]))
            }
        }

        if UserDefaults.standard.bool(forKey: showCPUKey) {
            let cpu = getCPUUsage()
            let text = String(format: "CPU:%.0f%%", cpu)
            let color = colorForLoad(cpu)
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: font
            ]
            appendSeparatorIfNeeded()
            attributedString.append(NSAttributedString(string: text, attributes: attributes))
        }

        if UserDefaults.standard.bool(forKey: showMemoryKey) {
            let memory = getMemoryUsage()
            let text = String(format: "MEM:%.0f%%", memory)
            let color = colorForLoad(memory)
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: font
            ]
            appendSeparatorIfNeeded()
            attributedString.append(NSAttributedString(string: text, attributes: attributes))
        }

        if UserDefaults.standard.bool(forKey: showGPUKey) {
            if let gpu = getGPUUsage() {
                let text = String(format: "GPU:%.0f%%", gpu)
                let color = colorForLoad(gpu)
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: color,
                    .font: font
                ]
                appendSeparatorIfNeeded()
                attributedString.append(NSAttributedString(string: text, attributes: attributes))
            }
        }

        // バッテリーがある場合のみ電力を表示（色変更なし）
        if deviceHasBattery && UserDefaults.standard.bool(forKey: showPowerKey) {
            let text: String
            if let power = getPowerWatts() {
                text = String(format: "%dW", power)
            } else {
                text = "--W"
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.labelColor,
                .font: font
            ]
            appendSeparatorIfNeeded()
            attributedString.append(NSAttributedString(string: text, attributes: attributes))
        }

        // ネットワーク速度を表示
        if UserDefaults.standard.bool(forKey: showNetworkKey) {
            if let speed = getNetworkSpeed() {
                let upText = formatSpeed(speed.up)
                let downText = formatSpeed(speed.down)
                let text = "\u{2191}\(upText) \u{2193}\(downText)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.labelColor,
                    .font: font
                ]
                appendSeparatorIfNeeded()
                attributedString.append(NSAttributedString(string: text, attributes: attributes))
            }
        }

        if let button = statusItem.button {
            if attributedString.length == 0 {
                button.attributedTitle = NSAttributedString(string: "---", attributes: [.font: font])
            } else {
                button.attributedTitle = attributedString
            }
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
            return powerMw / Constants.milliwattsPerWatt  // mW -> W
        }

        return nil
    }

    // ネットワークの送受信バイト数を取得
    func getNetworkBytes() -> (sent: UInt64, received: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }

        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            // アクティブな非ループバックインターフェースのみ
            if isUp && isRunning && !isLoopback {
                if ptr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    if let data = ptr.pointee.ifa_data {
                        let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                        totalSent += UInt64(ifData.ifi_obytes)
                        totalReceived += UInt64(ifData.ifi_ibytes)
                    }
                }
            }

            if let next = ptr.pointee.ifa_next {
                ptr = next
            } else {
                break
            }
        }

        return (totalSent, totalReceived)
    }

    // ネットワーク速度を計算（bytes per second）
    func getNetworkSpeed() -> (up: Double, down: Double)? {
        let currentBytes = getNetworkBytes()
        let currentTime = Date()

        defer {
            prevNetworkBytes = currentBytes
            prevNetworkTime = currentTime
        }

        guard let prevTime = prevNetworkTime else {
            return nil
        }

        let timeDiff = currentTime.timeIntervalSince(prevTime)
        guard timeDiff > 0 else {
            return nil
        }

        let sentDiff = currentBytes.sent >= prevNetworkBytes.sent
            ? currentBytes.sent - prevNetworkBytes.sent
            : currentBytes.sent  // オーバーフロー対策
        let receivedDiff = currentBytes.received >= prevNetworkBytes.received
            ? currentBytes.received - prevNetworkBytes.received
            : currentBytes.received  // オーバーフロー対策

        let upSpeed = Double(sentDiff) / timeDiff
        let downSpeed = Double(receivedDiff) / timeDiff

        return (upSpeed, downSpeed)
    }

    // 速度を適切な単位でフォーマット
    func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kbPerSecond = bytesPerSecond / 1024.0
        if kbPerSecond >= 1024.0 {
            let mbPerSecond = kbPerSecond / 1024.0
            return String(format: "%.1fMB/s", mbPerSecond)
        } else {
            return String(format: "%.0fKB/s", kbPerSecond)
        }
    }
}

// アプリを起動
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // Dockに表示しない
app.run()
