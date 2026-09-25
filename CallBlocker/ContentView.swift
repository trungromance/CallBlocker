import SwiftUI
import CallKit

struct ContentView: View {
    @State private var isMasterEnabled: Bool = BlockListManager.shared.isMasterEnabled
    @State private var rules: [BlockPrefixRule] = []
    @State private var blockedCalls: [BlockedCallRecord] = []
    
    // Form Input
    @State private var newPrefix: String = ""
    @State private var newNote: String = ""
    @State private var countryCode: String = "84"
    @State private var totalDigits: Int = 10
    
    // Status & UI State
    @State private var extensionStatusText: String = "Đang kiểm tra..."
    @State private var isExtensionEnabledInSettings: Bool = false
    @State private var isReloading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showHistorySheet: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - 1. HEADER & COMPACT SWITCH (THU NHỎ 1 NỬA)
                    VStack(spacing: 12) {
                        Text("Chặn số rác")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isMasterEnabled ? Color.orange : Color.secondary)
                            .padding(.top, 10)
                        
                        // Nút Switch thu nhỏ 1 nửa căn giữa
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isMasterEnabled.toggle()
                                BlockListManager.shared.isMasterEnabled = isMasterEnabled
                                syncWithCallKitSilently()
                            }
                        }) {
                            ZStack(alignment: isMasterEnabled ? .trailing : .leading) {
                                Capsule()
                                    .fill(
                                        isMasterEnabled
                                        ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray5)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: 76, height: 42)
                                    .shadow(color: isMasterEnabled ? Color.orange.opacity(0.35) : Color.clear, radius: 6, x: 0, y: 3)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 34, height: 34)
                                    .padding(4)
                                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(isMasterEnabled ? "Đang tự động chặn các cuộc gọi từ đầu số đã thêm" : "Đã tạm dừng bảo vệ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 2. HEATMAP TẦN SUẤT CHẶN (BẤM VÀO MỞ DANH SÁCH 30 NGÀY)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TẦN SUẤT CHẶN CUỘC GỌI")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 2) {
                                Text("Xem 30 ngày")
                                    .font(.caption2)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 4)
                        
                        // Bấm vào Heatmap để mở chi tiết lịch sử 30 ngày
                        Button(action: {
                            showHistorySheet = true
                        }) {
                            CallBlockingHeatmapView(blockedCalls: blockedCalls)
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 3. KHUNG THÊM ĐẦU SỐ MỚI
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THÊM ĐẦU SỐ CẦN CHẶN")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("+84")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                                
                                TextField("Ví dụ: 059 hoặc 0592*", text: $newPrefix)
                                    .keyboardType(.numberPad)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            }
                            
                            TextField("Ghi chú (Ví dụ: Spam tài chính, Telesale)", text: $newNote)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .font(.footnote)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            
                            Button(action: addPrefix) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                    Text("Thêm Vào Danh Sách Chặn")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .background(
                                    newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.gray.opacity(0.3)
                                    : Color.orange
                                )
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 4. DANH SÁCH ĐẦU SỐ ĐANG CHẶN
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("QUY TẮC ĐẦU SỐ (\(rules.count))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if isReloading {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        ForEach(rules) { rule in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("\(rule.prefix)*")
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                        
                                        Text("(\(rule.totalDigits) số)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if !rule.note.isEmpty {
                                        Text(rule.note)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { rule.isEnabled },
                                    set: { _ in
                                        BlockListManager.shared.toggleRule(id: rule.id)
                                        loadRules()
                                        syncWithCallKitSilently()
                                    }
                                ))
                                .labelsHidden()
                                
                                Button(action: {
                                    deleteRule(rule: rule)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(6)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showHistorySheet) {
                BlockedCallsHistorySheet(blockedCalls: $blockedCalls)
            }
            .onAppear {
                loadRules()
                loadBlockedCalls()
                checkExtensionStatus()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Lưu ý"), message: Text(alertMessage), dismissButton: .default(Text("Đã hiểu")))
            }
        }
    }
    
    private func loadRules() {
        self.rules = BlockListManager.shared.getRules()
    }
    
    private func loadBlockedCalls() {
        self.blockedCalls = BlockListManager.shared.getBlockedCallsHistory()
    }
    
    private func addPrefix() {
        let clean = newPrefix.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        BlockListManager.shared.addRule(prefix: clean, totalDigits: totalDigits, countryCode: countryCode, note: newNote)
        newPrefix = ""
        newNote = ""
        loadRules()
        syncWithCallKitSilently()
    }
    
    private func deleteRule(rule: BlockPrefixRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            BlockListManager.shared.removeRule(at: IndexSet(integer: index))
            loadRules()
            syncWithCallKitSilently()
        }
    }
    
    private func checkExtensionStatus() {
        BlockListManager.shared.checkExtensionStatus { status, error in
            if let error = error {
                self.extensionStatusText = "Không thể kiểm tra"
                self.isExtensionEnabledInSettings = false
                return
            }
            switch status {
            case .enabled:
                self.extensionStatusText = "Đã kích hoạt"
                self.isExtensionEnabledInSettings = true
            case .disabled:
                self.extensionStatusText = "Chưa bật quyền"
                self.isExtensionEnabledInSettings = false
            case .unknown:
                self.extensionStatusText = "Chưa xác định"
                self.isExtensionEnabledInSettings = false
            @unknown default:
                self.extensionStatusText = "Không xác định"
                self.isExtensionEnabledInSettings = false
            }
        }
    }
    
    private func syncWithCallKitSilently() {
        isReloading = true
        BlockListManager.shared.reloadExtension { error in
            isReloading = false
            if let error = error {
                self.alertMessage = "Chưa đồng bộ được: \(error.localizedDescription).\n\nVui lòng vào Cài đặt -> Điện thoại -> Chặn & Nhận dạng cuộc gọi để bật ứng dụng."
                self.showAlert = true
            } else {
                checkExtensionStatus()
            }
        }
    }
}

// MARK: - HEATMAP COMPONENT (HỖ TRỢ DARK MODE & DỮ LIỆU THỰC TẾ 100%)
struct CallBlockingHeatmapView: View {
    let blockedCalls: [BlockedCallRecord]
    
    let days = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
    let timeSlots = [
        "12:00 AM",
        "02:00 AM",
        "04:00 AM",
        "06:00 AM",
        "08:00 AM",
        "10:00 AM",
        "12:00 PM",
        "02:00 PM",
        "04:00 PM",
        "06:00 PM",
        "08:00 PM",
        "10:00 PM"
    ]
    
    // Tính toán 100% dữ liệu thực tế từ danh sách cuộc gọi đã chặn
    var gridMatrix: [[Int]] {
        var matrix = Array(repeating: Array(repeating: 0, count: 7), count: 12)
        let calendar = Calendar.current
        
        for call in blockedCalls {
            let weekday = calendar.component(.weekday, from: call.timestamp) - 1 // 0 (CN) .. 6 (T7)
            let hour = calendar.component(.hour, from: call.timestamp)
            let row = min(hour / 2, 11)
            if weekday >= 0 && weekday < 7 && row >= 0 && row < 12 {
                matrix[row][weekday] += 1
            }
        }
        return matrix
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header các thứ trong tuần
            HStack(spacing: 4) {
                Text("")
                    .frame(width: 54, alignment: .leading)
                
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Lưới Heatmap 12 khung giờ x 7 ngày
            VStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { row in
                    HStack(spacing: 4) {
                        // Nhãn giờ (12 AM, 6 AM, 12 PM, 6 PM)
                        if row == 0 || row == 3 || row == 6 || row == 9 {
                            Text(timeSlots[row])
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .frame(width: 54, alignment: .leading)
                        } else {
                            Text("")
                                .font(.system(size: 9))
                                .frame(width: 54, alignment: .leading)
                        }
                        
                        // 7 ô hình chữ nhật bo góc tương thích Dark Mode & Light Mode
                        ForEach(0..<7, id: \.self) { col in
                            let count = gridMatrix[row][col]
                            HeatmapCellView(count: count)
                        }
                    }
                }
            }
            
            // Chú giải mức độ tông cam
            HStack(spacing: 6) {
                Spacer()
                Text("Ít")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                HeatmapCellView(count: 0)
                    .frame(width: 14, height: 10)
                
                HeatmapCellView(count: 1)
                    .frame(width: 14, height: 10)
                
                HeatmapCellView(count: 2)
                    .frame(width: 14, height: 10)
                
                HeatmapCellView(count: 3)
                    .frame(width: 14, height: 10)
                
                HeatmapCellView(count: 4)
                    .frame(width: 14, height: 10)
                
                Text("Nhiều")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
}

// Cell Heatmap tương thích chuẩn Dark Mode
struct HeatmapCellView: View {
    @Environment(\.colorScheme) var colorScheme
    let count: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(cellColor)
            .frame(height: 11)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(borderColor, lineWidth: 0.5)
            )
    }
    
    private var cellColor: Color {
        if count == 0 {
            return colorScheme == .dark
                ? Color(white: 0.18)
                : Color(white: 0.94)
        } else if count == 1 {
            return Color.orange.opacity(0.35)
        } else if count == 2 {
            return Color.orange.opacity(0.60)
        } else if count == 3 {
            return Color.orange.opacity(0.85)
        } else {
            return Color.orange
        }
    }
    
    private var borderColor: Color {
        if count == 0 {
            return colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.04)
        } else {
            return Color.orange.opacity(0.3)
        }
    }
}

// MARK: - SHEET DANH SÁCH LỊCH SỬ CHẶN 30 NGÀY
struct BlockedCallsHistorySheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var blockedCalls: [BlockedCallRecord]
    
    var body: some View {
        NavigationView {
            List {
                if blockedCalls.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.badge.checkmark")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Chưa có cuộc gọi rác nào trong 30 ngày qua.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    Section(header: Text("DANH SÁCH CUỘC GỌI ĐÃ CHẶN (\(blockedCalls.count))")) {
                        ForEach(blockedCalls) { record in
                            HStack(spacing: 12) {
                                Image(systemName: "phone.down.fill")
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(record.phoneNumber)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(record.prefix)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(record.note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Lịch Sử 30 Ngày")
            .navigationBarItems(
                leading: Button("Xoá tất cả") {
                    BlockListManager.shared.clearBlockedCallsHistory()
                    blockedCalls = []
                }
                .foregroundColor(.red)
                .disabled(blockedCalls.isEmpty),
                trailing: Button("Đóng") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.orange)
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
