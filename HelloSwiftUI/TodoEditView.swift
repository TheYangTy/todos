import SwiftUI
import MapKit
import CoreLocation
import Combine

struct TodoEditView: View {
    @Binding var todo: TodoItem
    let lists: [TodoList]
    
    // 是否有截止日期（控制 UI）
    @State private var hasDueDate: Bool = false
    // 是否开启提醒
    @State private var hasReminder: Bool = false
    
    // 用于选择清单
    @State private var selectedListId: UUID = UUID()

    // 地点相关状态
    @State private var hasLocation: Bool = false
    @State private var locationName: String = ""
    @State private var locationRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isPresentingLocationPicker: Bool = false
    
    init(todo: Binding<TodoItem>, lists: [TodoList]) {
        self._todo = todo
        self.lists = lists
        
        _hasDueDate = State(initialValue: todo.wrappedValue.dueDate != nil)
        _hasReminder = State(initialValue: todo.wrappedValue.reminderTime != nil)
        _selectedListId = State(initialValue: todo.wrappedValue.listId)
        
        if let loc = todo.wrappedValue.location {
            _hasLocation = State(initialValue: true)
            _locationName = State(initialValue: loc.name)
            _locationRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            _hasLocation = State(initialValue: false)
            _locationName = State(initialValue: "")
        }
    }
    
    var body: some View {
        Form {
            // 标题
            Section("标题") {
                TextField("请输入待办事项", text: $todo.title)
            }
            
            // 清单
            Section("清单") {
                Picker("所属清单", selection: $selectedListId) {
                    ForEach(lists) { list in
                        Text(list.name).tag(list.id)
                    }
                }
                .onChange(of: selectedListId) { newValue in
                    todo.listId = newValue
                }
            }
            
            // 优先级
            Section("优先级") {
                Picker("优先级", selection: $todo.priority) {
                    ForEach(TodoItem.Priority.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 日期 & 提醒
            Section("日期与提醒") {
                // 截止日期开关
                Toggle("设置截止日期", isOn: $hasDueDate)
                    .onChange(of: hasDueDate) { newValue in
                        if newValue {
                            // 开启截止日期：如果原来没有，就给一个默认今天
                            if todo.dueDate == nil {
                                todo.dueDate = Date()
                            }
                            // 如果已经有提醒，则把提醒的日期部分对齐到当前截止日
                            if let due = todo.dueDate,
                               let currentReminder = todo.reminderTime {
                                todo.reminderTime = normalizeReminderTime(
                                    from: currentReminder,
                                    toDueDate: due
                                )
                            }
                        } else {
                            // 关闭截止日期：清空截止日期 & 提醒
                            todo.dueDate = nil
                            todo.reminderTime = nil
                            hasReminder = false
                        }
                    }
                
                // 截止日期选择
                if hasDueDate {
                    DatePicker(
                        "截止日期",
                        selection: Binding(
                            get: { todo.dueDate ?? Date() },
                            set: { newDate in
                                todo.dueDate = newDate
                                // 如果已经设置了提醒时间，调整其日期部分到新的截止日
                                if let currentReminder = todo.reminderTime {
                                    todo.reminderTime = normalizeReminderTime(
                                        from: currentReminder,
                                        toDueDate: newDate
                                    )
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                }
                
                // 提醒逻辑
                if todo.dueDate == nil {
                    Text("请先设置截止日期才能开启提醒。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Toggle("开启提醒", isOn: $hasReminder)
                        .onChange(of: hasReminder) { newValue in
                            if newValue {
                                // 开启提醒：如果之前没有设置，给一个默认时间（截止日当天 09:00）
                                if todo.reminderTime == nil, let due = todo.dueDate {
                                    todo.reminderTime = defaultReminderDate(for: due)
                                }
                            } else {
                                // 关闭提醒：清空 reminderTime
                                todo.reminderTime = nil
                            }
                        }
                    
                    if hasReminder, let due = todo.dueDate {
                        DatePicker(
                            "提醒时间",
                            selection: Binding(
                                get: {
                                    todo.reminderTime ?? defaultReminderDate(for: due)
                                },
                                set: { newDate in
                                    todo.reminderTime = normalizeReminderTime(
                                        from: newDate,
                                        toDueDate: due
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
            
            // 地点
            Section("地点") {
                Toggle("添加地点", isOn: $hasLocation)
                    .onChange(of: hasLocation) { newValue in
                        if newValue {
                            // 开启地点功能时，如果还没有 location，则创建一个默认的
                            let coord = locationRegion.center
                            if todo.location == nil {
                                todo.location = TodoItem.TodoLocation(
                                    name: locationName.isEmpty ? "" : locationName,
                                    latitude: coord.latitude,
                                    longitude: coord.longitude
                                )
                            }
                        } else {
                            // 关闭地点功能时，清空 location
                            todo.location = nil
                        }
                    }
                
                if hasLocation {
                    // ✅ 用 VStack 把缩略图 + 名称包起来
                    VStack(alignment: .leading, spacing: 4) {
                        // 地图缩略图（只读），点击后进入全屏地图选择
                        ZStack {
                            Map(coordinateRegion: $locationRegion, interactionModes: [])
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onChange(of: locationRegion.center.latitude) { _ in
                                    syncLocationFromRegion()
                                }
                                .onChange(of: locationRegion.center.longitude) { _ in
                                    syncLocationFromRegion()
                                }
                                // 缩略图只作为预览，不处理手势
                                .allowsHitTesting(false)
                            
                            // 缩略图中央的图钉（不拦截手势）
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.red, .white)
                                .allowsHitTesting(false)
                            
                            // 透明覆盖层，专门用来接收点击，弹出全屏地图
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isPresentingLocationPicker = true
                                }
                        }
                        
                        // ✅ 选定地点的名称（有名字时才显示）
                        if !locationName.isEmpty {
                            Text(locationName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    // 当地点名称变化时，同步回 todo.location.name
                    .onChange(of: locationName) { newValue in
                        guard var loc = todo.location else {
                            let coord = locationRegion.center
                            todo.location = TodoItem.TodoLocation(
                                name: newValue,
                                latitude: coord.latitude,
                                longitude: coord.longitude
                            )
                            return
                        }
                        loc.name = newValue
                        todo.location = loc
                    }
                    
                    Button {
                        openInMaps()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                            Text("在地图中打开")
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // 重复
            Section("重复") {
                Picker("重复", selection: $todo.repeatRule) {
                    ForEach(TodoItem.RepeatRule.allCases) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
            }
        }
        .navigationTitle("编辑事项")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingLocationPicker) {
            LocationPickerView(region: $locationRegion, locationName: $locationName)
        }
    }
    
    // MARK: - Helper：默认提醒时间 = 截止日当天 09:00
    
    private func defaultReminderDate(for dueDate: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = 9
        comps.minute = 0
        return cal.date(from: comps) ?? dueDate
    }
    
    /// 将源时间的“时分”投射到指定的截止日（保持日期 = dueDate，时间 = source 的时分）
    private func normalizeReminderTime(from source: Date, toDueDate dueDate: Date) -> Date {
        let cal = Calendar.current
        let time = cal.dateComponents([.hour, .minute], from: source)
        var comps = cal.dateComponents([.year, .month, .day], from: dueDate)
        comps.hour = time.hour
        comps.minute = time.minute
        return cal.date(from: comps) ?? dueDate
    }
    
    /// 将当前 locationRegion 同步回 todo.location 的经纬度
    private func syncLocationFromRegion() {
        guard hasLocation else { return }
        let coord = locationRegion.center
        if var loc = todo.location {
            loc.latitude = coord.latitude
            loc.longitude = coord.longitude
            todo.location = loc
        } else {
            todo.location = TodoItem.TodoLocation(
                name: locationName,
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        }
    }
    
    /// 使用当前任务的地点在 Apple 地图中打开
    private func openInMaps() {
        guard let loc = todo.location else { return }
        let coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = loc.name.isEmpty ? todo.title : loc.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - 全屏地图选择视图（用 UIKit MKMapView 保证交互）

struct LocationPickerView: View {
    @Binding var region: MKCoordinateRegion
    @Binding var locationName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var programmaticUpdateID: UUID = UUID()
    @StateObject private var locationManager = LocationManager()
    @State private var pendingSearchWorkItem: DispatchWorkItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 底层地图
                UIKitMapView(region: $region, programmaticUpdateID: programmaticUpdateID)
                    .ignoresSafeArea(edges: .bottom)
                
                // 中心图钉（不拦截手势）
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.red, .white)
                    .allowsHitTesting(false)
                
                // 顶部搜索框 + 底部候选列表 + 右下角定位按钮
                VStack {
                    // 顶部搜索框，尽量贴近系统地图的样式：圆润、半透明、带放大镜和清空
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("搜索地点或地址", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.search)
                            .onSubmit {
                                triggerSearch(for: searchText)
                            }
                            .onChange(of: searchText) { newValue in
                                triggerSearch(for: newValue)
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    // 底部候选列表卡片，类似地图 App 的下拉面板
                    if !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            // 小手柄
                            Capsule()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 36, height: 4)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(searchResults.indices, id: \.self) { index in
                                        let item = searchResults[index]
                                        Button {
                                            selectSearchResult(item)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.name ?? "未知地点")
                                                    .font(.body)
                                                if let subtitle = item.placemark.title {
                                                    Text(subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if index != searchResults.indices.last {
                                            Divider()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 260)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }
                
                // 右下角当前定位按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            centerOnUserLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .medium))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("选择地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if locationName.isEmpty {
                            locationName = searchText.isEmpty ? "已选择地点" : searchText
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
    }
    
    /// 触发带防抖的搜索逻辑（实时联想）
    private func triggerSearch(for text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 清空时直接清候选
        if trimmed.isEmpty {
            pendingSearchWorkItem?.cancel()
            searchResults = []
            return
        }
        
        // 简单防抖：取消上一次任务，延时 0.3s 执行
        pendingSearchWorkItem?.cancel()
        let workItem = DispatchWorkItem { [trimmed] in
            search(query: trimmed)
        }
        pendingSearchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    /// 实际执行 MKLocalSearch 的方法
    private func search(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let items = response?.mapItems, !items.isEmpty else { return }
            DispatchQueue.main.async {
                // 仅更新候选列表，不立即移动地图；由用户点击列表项时再移动
                searchResults = items
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        // 用户选择候选项时再居中并放大
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        locationName = item.name ?? item.placemark.title ?? searchText
        // 标记这是一次编程触发的区域更新，交给 UIKitMapView 去应用
        programmaticUpdateID = UUID()
        // 选中后清空候选列表
        searchResults = []
    }

    /// 将地图中心移动到当前定位
    private func centerOnUserLocation() {
        guard let coord = locationManager.lastCoordinate else {
            // 如果还没有定位结果，主动请求一次
            locationManager.requestLocation()
            return
        }
        region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        programmaticUpdateID = UUID()
    }
}

// MARK: - UIKit MKMapView 封装，保证地图手势可用

struct UIKitMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var programmaticUpdateID: UUID
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 只有当 programmaticUpdateID 变化时，才认为是来自 SwiftUI 的主动更新
        if context.coordinator.lastProgrammaticUpdateID != programmaticUpdateID {
            context.coordinator.lastProgrammaticUpdateID = programmaticUpdateID
            uiView.setRegion(region, animated: true)
        }
        // 用户手势导致的 region 变化由 MKMapView 自己管理，并通过代理写回绑定
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: UIKitMapView
        var lastProgrammaticUpdateID: UUID?
        
        init(parent: UIKitMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 用户手势改变地图时，将最新区域写回 SwiftUI 绑定
            parent.region = mapView.region
        }
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastCoordinate: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocation() {
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.lastCoordinate = loc.coordinate
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 这里简单忽略错误，实际产品中可以做日志或提示
        print("Location error: \(error.localizedDescription)")
    }
}
