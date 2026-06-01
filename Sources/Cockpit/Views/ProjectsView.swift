import SwiftUI

struct ProjectsView: View {
    let projects = [
        Project(name: "Cockpit", path: "~/Desktop/Hermes-Projects/Cockpit", status: "Active"),
        Project(name: "Ndex", path: "~/Desktop/Hermes-Projects/Ndex", status: "Research")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Projects")
                .font(.title2.bold())
                .foregroundStyle(.white)

            ForEach(projects) { project in
                HStack {
                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.headline)
                        Text(project.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(project.status)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct Project: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let status: String
}