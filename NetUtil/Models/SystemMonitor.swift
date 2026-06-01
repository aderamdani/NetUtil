import Foundation
import Darwin
import Combine
import Observation

@MainActor
@Observable
final class SystemMonitor {
    var cpuUsage: Double = 0.0
    var memoryPressure: String = "Normal"
    var memoryColor: String = "green"
    var ramUsedGB: Double = 0
    let ramTotalGB: Double

    private var timer: Timer?
    @ObservationIgnored private var lastCpuInfo: processor_info_array_t?
    @ObservationIgnored private var lastCpuInfoCount: mach_msg_type_number_t = 0

    init() {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        ramTotalGB = Double(size) / (1024 * 1024 * 1024)
        start()
    }
    
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStats()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        freeLastCpuInfo()
    }

    private func freeLastCpuInfo() {
        guard let info = lastCpuInfo else { return }
        vm_deallocate(mach_task_self_,
                      vm_address_t(bitPattern: info),
                      vm_size_t(lastCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        lastCpuInfo = nil
        lastCpuInfoCount = 0
    }
    
    private func updateStats() {
        updateCPU()
        updateMemory()
    }
    
    private func updateCPU() {
        var numCPUs: UInt32 = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &cpuInfoCount)
        
        if result == KERN_SUCCESS, let cpuInfo = cpuInfo {
            if let lastInfo = lastCpuInfo {
                var totalUsage: Double = 0
                for i in 0..<Int(numCPUs) {
                    let user = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)] - lastInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)])
                    let system = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)] - lastInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)])
                    let idle = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)] - lastInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)])
                    let nice = Double(cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)] - lastInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)])
                    
                    let used = user + system + nice
                    let total = used + idle
                    if total > 0 {
                        totalUsage += (used / total)
                    }
                }
                self.cpuUsage = (totalUsage / Double(numCPUs)) * 100.0
                
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: lastInfo), vm_size_t(lastCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
            }
            
            lastCpuInfo = cpuInfo
            lastCpuInfoCount = cpuInfoCount
        }
    }
    
    private func updateMemory() {
        var pressure: Int32 = 0
        var size = MemoryLayout<Int32>.size
        
        // Use sysctl to get memory pressure
        if sysctlbyname("kern.memorystatus_level", &pressure, &size, nil, 0) == 0 {
            // macOS 0-100 scale where lower is more pressure (usually)
            // or use HOST_VM_INFO
        }
        
        // Simplified fallback using host_statistics
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let total = Double(stats.free_count + stats.active_count + stats.inactive_count + stats.wire_count)
            let used = Double(stats.active_count + stats.wire_count + stats.compressor_page_count)
            let ratio = used / total

            let pageSize = Double(vm_kernel_page_size)
            ramUsedGB = used * pageSize / (1024 * 1024 * 1024)

            if ratio > 0.9 {
                memoryPressure = "Critical"
                memoryColor = "red"
            } else if ratio > 0.7 {
                memoryPressure = "High"
                memoryColor = "orange"
            } else {
                memoryPressure = "Normal"
                memoryColor = "green"
            }
        }
    }
}
