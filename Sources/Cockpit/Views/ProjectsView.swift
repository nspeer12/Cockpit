import SwiftUI
import Foundation

struct ProjectsView: View {
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    let projectsPath = ProjectScanner.defaultProjectsPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 16 : 24) {
            // Header
            HStack {
                Text("PROJECTS")
                    .font(.system(size: horizontalSizeClass == .compact ? 24 : 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action: refreshProjects) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 40)
            .padding(.top, horizontalSizeClass == .compact ? 20 : 30)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // Adaptive grid: 1 column in compact, 2+ columns in regular
                    let columns: [GridItem] = horizontalSizeClass == .compact ?
                        [GridItem(.flexible())] :
                        [GridItem(.adaptive(minimum: 320), spacing: 20)]
                    
                    LazyVGrid(columns: columns, spacing: horizontalSizeClass == .compact ? 16 : 20) {
                        ForEach(projects) { project in
                            ProjectCard(project: project)
                        }
                    }
                    .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 40)
                }
            }
            
            Spacer()
        }
        .onAppear(perform: loadProjects)
    }
    
    private func loadProjects() {
        isLoading = true
        let rootPath = projectsPath
        
        Task.detached(priority: .userInitiated) {
            let loadedProjects = ProjectScanner.scanProjects(at: rootPath)
            await MainActor.run {
                self.projects = loadedProjects
                self.isLoading = false
            }
        }
    }
    
    private func refreshProjects() {
        loadProjects()
    }
}

struct ProjectCard: View {
    let project: Project
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 8 : 12) {
            HStack {
                Text(project.name)
                    .font(.system(size: horizontalSizeClass == .compact ? 16 : 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                StatusBadge(status: project.status)
            }
            
            Text(project.path)
                .font(.system(size: horizontalSizeClass == .compact ? 9 : 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack {
                Text("Last modified")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(project.lastModified, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: horizontalSizeClass == .compact ? 6 : 12) {
                Button("Open") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                }
                .buttonStyle(GlassButtonStyle())
                
                Button("Terminal") {
                    openInTerminal(path: project.path)
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(horizontalSizeClass == .compact ? 12 : 20)
        .background(.ultraThinMaterial)
        .cornerRadius(horizontalSizeClass == .compact ? 12 : 16)
        .overlay(
            RoundedRectangle(cornerRadius: horizontalSizeClass == .compact ? 12 : 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func openInTerminal(path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]
        try? process.run()
    }
}

struct StatusBadge: View {
    let status: String
    
    var color: Color {
        switch status {
        case "Clean": return .green
        case "Modified": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        Text(status)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}