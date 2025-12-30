import SwiftUI
import Foundation
import AppKit

// MARK: - Models
struct RedmineIssue: Codable, Identifiable {
    let id: Int
    let subject: String
    let status: Status
    let project: Project
    let priority: Priority?

    struct Status: Codable {
        let name: String
    }

    struct Project: Codable {
        let name: String
    }
    
    struct Priority: Codable {
        let name: String
    }
}

struct RedmineResponse: Codable {
    let issues: [RedmineIssue]
}

struct RedmineIssueDetail: Codable {
    let issue: Issue

    struct Issue: Codable {
        let id: Int
        let subject: String
        let description: String?
        let status: RedmineIssue.Status
        let project: RedmineIssue.Project
    }
}

// MARK: - Filter Options
struct IssueFilters {
    var selectedStatuses: Set<String> = []
    var selectedPriorities: Set<String> = []
    
    func matches(issue: RedmineIssue) -> Bool {
        // Status filter
        if !selectedStatuses.isEmpty && !selectedStatuses.contains(issue.status.name) {
            return false
        }
        
        // Priority filter
        if !selectedPriorities.isEmpty {
            if let priority = issue.priority {
                if !selectedPriorities.contains(priority.name) {
                    return false
                }
            } else {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Settings
class AppSettings: ObservableObject {
    @AppStorage("serverName") var serverName: String = "My Redmine Server"
    @AppStorage("serverURL") var serverURL: String = ""
    @AppStorage("serverAPIKey") var serverAPIKey: String = ""
}

// MARK: - Custom Toggle Button Style
struct FilterToggleStyle: ToggleStyle {
    let selectedColor: Color
    let unselectedColor: Color
    
    init(selectedColor: Color = .blue, unselectedColor: Color = .gray) {
        self.selectedColor = selectedColor
        self.unselectedColor = unselectedColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isOn ? selectedColor.opacity(0.2) : unselectedColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        configuration.isOn ? selectedColor : unselectedColor.opacity(0.5),
                        lineWidth: configuration.isOn ? 2 : 1
                    )
            )
            .scaleEffect(configuration.isOn ? 1.0 : 0.95)
            .animation(.easeInOut(duration: 0.1), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
    }
}

// MARK: - Main App
@main
struct RedmineApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup("My Redmine Tasks") {
            ServerIssuesView()
                .environmentObject(settings)
                .frame(minWidth: 700, minHeight: 500)
        }
        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

// MARK: - Server Issues View
struct ServerIssuesView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var issues: [RedmineIssue] = []
    @State private var filteredIssues: [RedmineIssue] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var showingFilters = false
    @State private var filters = IssueFilters()
    @State private var availableStatuses: Set<String> = []
    @State private var availablePriorities: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button("Load Issues") { fetchIssues() }
                    .buttonStyle(.borderedProminent)
                
                Button(action: { showingSettings.toggle() }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { showingFilters.toggle() }) {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filters")
                    }
                }
                .buttonStyle(.bordered)

                Spacer()
                
                if !filteredIssues.isEmpty {
                    Text("\(filteredIssues.count) issues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Divider()
            
            // Filters Panel
            if showingFilters {
                FiltersPanel(
                    filters: $filters,
                    availableStatuses: availableStatuses,
                    availablePriorities: availablePriorities,
                    onApply: { applyFilters() }
                )
                .padding(.horizontal)
                .transition(.slide)
            }

            if isLoading {
                Spacer()
                ProgressView("Loading tasks…")
                    .padding()
                Spacer()
            } else if let errorMessage = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("⚠️ \(errorMessage)")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") { fetchIssues() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else if filteredIssues.isEmpty && !issues.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No issues match the current filters")
                        .foregroundColor(.secondary)
                    Button("Clear Filters") {
                        filters = IssueFilters()
                        applyFilters()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else if issues.isEmpty {
                Spacer()
                Text("No tasks to display.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredIssues) { issue in
                            IssueCard(issue: issue,
                                      baseURL: settings.serverURL,
                                      apiKey: settings.serverAPIKey)
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .animation(.easeInOut(duration: 0.3), value: showingFilters)
        .onAppear { fetchIssues() }
    }
    
    private func applyFilters() {
        filteredIssues = issues.filter { filters.matches(issue: $0) }
    }
    
    private func updateAvailableOptions() {
        availableStatuses = Set(issues.map { $0.status.name })
        availablePriorities = Set(issues.compactMap { $0.priority?.name })
    }

    private func fetchIssues() {
        guard !settings.serverURL.isEmpty, !settings.serverAPIKey.isEmpty else {
            errorMessage = "URL and API key are required"
            return
        }

        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(settings.serverURL)/issues.json?assigned_to_id=me&status_id=open&limit=50") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(settings.serverAPIKey, forHTTPHeaderField: "X-Redmine-API-Key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    errorMessage = "HTTP error \(httpResponse.statusCode)"
                    return
                }
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(RedmineResponse.self, from: data)
                    issues = decoded.issues
                    updateAvailableOptions()
                    applyFilters()
                } catch {
                    errorMessage = "Failed to parse Redmine response: \(error)"
                }
            }
        }.resume()
    }
}

// MARK: - Filters Panel
struct FiltersPanel: View {
    @Binding var filters: IssueFilters
    let availableStatuses: Set<String>
    let availablePriorities: Set<String>
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filters")
                    .font(.headline)
                Spacer()
                Button("Clear All") {
                    filters = IssueFilters()
                    onApply()
                }
                .buttonStyle(.bordered)
            }

            if !availableStatuses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(Array(availableStatuses).sorted(), id: \.self) { status in
                            Toggle(isOn: Binding(
                                get: { filters.selectedStatuses.contains(status) },
                                set: { isSelected in
                                    if isSelected {
                                        filters.selectedStatuses.insert(status)
                                    } else {
                                        filters.selectedStatuses.remove(status)
                                    }
                                    onApply()
                                }
                            )) {
                                StatusBadge(status: status)
                            }
                            .toggleStyle(FilterToggleStyle(
                                selectedColor: statusColor(status),
                                unselectedColor: .gray
                            ))
                        }
                    }
                }
            }

            if !availablePriorities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(Array(availablePriorities).sorted(), id: \.self) { priority in
                            Toggle(isOn: Binding(
                                get: { filters.selectedPriorities.contains(priority) },
                                set: { isSelected in
                                    if isSelected {
                                        filters.selectedPriorities.insert(priority)
                                    } else {
                                        filters.selectedPriorities.remove(priority)
                                    }
                                    onApply()
                                }
                            )) {
                                PriorityBadge(priority: priority)
                            }
                            .toggleStyle(FilterToggleStyle(
                                selectedColor: priorityColor(priority),
                                unselectedColor: .gray
                            ))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 5)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "new": return .blue
        case "in progress": return .orange
        case "resolved": return .green
        case "closed": return .gray
        default: return .blue
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "low": return .green
        case "normal": return .blue
        case "high": return .orange
        case "urgent": return .red
        case "immediate": return .red
        default: return .blue
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .clipShape(Capsule())
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "new": return .blue
        case "in progress": return .orange
        case "resolved": return .green
        case "closed": return .gray
        default: return .blue
        }
    }
}

// MARK: - Priority Badge
struct PriorityBadge: View {
    let priority: String

    var body: some View {
        Text(priority)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor(priority).opacity(0.2))
            .foregroundColor(priorityColor(priority))
            .clipShape(Capsule())
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "low": return .green
        case "normal": return .blue
        case "high": return .orange
        case "urgent": return .red
        case "immediate": return .red
        default: return .blue
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "gear")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
                
                Text("Redmine Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Configure your Redmine server connection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Server Configuration Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "server.rack")
                                .font(.title2)
                                .foregroundColor(.red)
                            Text("Server Configuration")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(spacing: 12) {
                            SettingsField(
                                icon: "tag",
                                title: "Server Name",
                                placeholder: "My Redmine Server",
                                text: $settings.serverName
                            )
                            
                            SettingsField(
                                icon: "link",
                                title: "Redmine URL",
                                placeholder: "https://myserver.mydomain",
                                text: $settings.serverURL
                            )
                            
                            SettingsField(
                                icon: "key",
                                title: "API Key",
                                placeholder: "Your API key from Redmine profile",
                                text: $settings.serverAPIKey,
                                isSecure: true
                            )
                        }
                        .padding(16)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Help Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                            Text("Help")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HelpItem(
                                icon: "1.circle.fill",
                                title: "Server URL",
                                description: "Enter your Redmine server URL (e.g., https://redmine.example.com)"
                            )
                            
                            HelpItem(
                                icon: "2.circle.fill",
                                title: "API Key",
                                description: "Find your API key in your Redmine profile settings under 'API access key'"
                            )
                            
                            HelpItem(
                                icon: "3.circle.fill",
                                title: "Testing",
                                description: "Click 'Load Issues' to test your connection"
                            )
                        }
                        .padding(16)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(24)
            }
            
            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 520, height: 580)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Settings Field Component
struct SettingsField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.red)
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Help Item Component
struct HelpItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Task Card
struct IssueCard: View {
    let issue: RedmineIssue
    let baseURL: String
    let apiKey: String

    @State private var isHovered = false
    @State private var detail: RedmineIssueDetail.Issue?
    @State private var isLoadingDetail = false

    var body: some View {
        Button(action: openInBrowser) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("#\(issue.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())

                    Text(issue.project.name)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(6)

                    Spacer()
                    
                    if let priority = issue.priority {
                        PriorityBadge(priority: priority.name)
                    }

                    StatusBadge(status: issue.status.name)
                }

                Text(issue.subject)
                    .font(.headline)
                    .multilineTextAlignment(.leading)

                if isHovered {
                    if isLoadingDetail {
                        Text("Loading details…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else if let detail = detail {
                        VStack(alignment: .leading, spacing: 4) {
                            if let desc = detail.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3))
            )
            .shadow(color: .black.opacity(isHovered ? 0.25 : 0.1),
                    radius: isHovered ? 6 : 3, x: 0, y: 1)
            .onHover { inside in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = inside
                    if inside && detail == nil {
                        loadDetail()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadDetail() {
        isLoadingDetail = true
        guard let url = URL(string: "\(baseURL)/issues/\(issue.id).json") else {
            isLoadingDetail = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingDetail = false
                if let data = data, let decoded = try? JSONDecoder().decode(RedmineIssueDetail.self, from: data) {
                    detail = decoded.issue
                }
            }
        }.resume()
    }

    private func openInBrowser() {
        if let url = URL(string: "\(baseURL)/issues/\(issue.id)") {
            NSWorkspace.shared.open(url)
        }
    }
}
