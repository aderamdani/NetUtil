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
    
    nonisolated(unsafe) private var timer: Timer?
    nonisolated(unsafe) private var lastCpuInfo: processor_info_array_t?
    nonisolated(unsafe) private var lastCpuInfoCount: mach_msg_type_number_t = 0
    
    init() {
        start()
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        freeLastCpuInfo()
    }

    deinit {
        timer?.invalidate()
        if let info = lastCpuInfo {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(lastCpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
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
        if sysctlbyname("kern.memo_status_level", &pressure, &size, nil, 0) == 0 {
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
            
            if ratio > 0.9 {
                memoryPressure = "Critical"
                memoryColor = "red"
            } else if ratio > 0.7 {
                memoryPressure = "High"
                memoryColor = "orange"
            } else {
                memoryPressure = "Healthy"
                memoryColor = "blue"
            }
        }
    }
}
