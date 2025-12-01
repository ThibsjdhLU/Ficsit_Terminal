import SwiftUI

struct ProjectManagerView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @Binding var isPresented: Bool
    @State private var projects: [ProjectData] = []
    @State private var showingSaveAlert = false
    @State private var saveName: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                VStack {
                    if projects.isEmpty {
                        VStack(spacing: 20) { Image(systemName: "folder.badge.questionmark").font(.system(size: 50)).foregroundColor(.gray); Text("No saved projects").foregroundColor(.gray) }.frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(projects) { project in
                                Button(action: { viewModel.loadProject(project); isPresented = false }) {
                                    HStack {
                                        VStack(alignment: .leading) { Text(project.name).font(.headline).foregroundColor(.white); Text("Last modified: \(project.date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundColor(.gray) }
                                        Spacer()
                                        if project.id == viewModel.currentProjectId { Image(systemName: "checkmark.circle.fill").foregroundColor(.ficsitOrange) }
                                    }
                                }.listRowBackground(Color.ficsitGray.opacity(0.3))
                            }.onDelete(perform: deleteProject)
                        }.listStyle(InsetGroupedListStyle())
                    }
                    VStack(spacing: 15) {
                        Button(action: { saveName = viewModel.currentProjectName; showingSaveAlert = true }) { HStack { Image(systemName: "square.and.arrow.down.fill"); Text("SAVE CURRENT PROJECT") }.font(.headline).frame(maxWidth: .infinity).padding().background(Color.ficsitOrange).foregroundColor(.black).cornerRadius(10) }
                        Button(action: { viewModel.createNewProject(); isPresented = false }) { HStack { Image(systemName: "plus.square.dashed"); Text("NEW EMPTY PROJECT") }.font(.headline).frame(maxWidth: .infinity).padding().background(Color.gray.opacity(0.3)).foregroundColor(.white).cornerRadius(10) }
                    }.padding()
                }
            }
            .navigationBarTitle("Project Manager", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") { isPresented = false })
            .onAppear(perform: loadProjects)
            .alert("Save Project", isPresented: $showingSaveAlert) {
                TextField("Project Name", text: $saveName)
                Button("Cancel", role: .cancel) { }
                Button("Save") { viewModel.saveCurrentProject(name: saveName); loadProjects() }
            } message: { Text("Enter a name for your factory.") }
        }.accentColor(.ficsitOrange)
    }
    
    private func loadProjects() { projects = ProjectService.shared.loadAllProjects() }
    private func deleteProject(at offsets: IndexSet) { offsets.forEach { index in let project = projects[index]; ProjectService.shared.deleteProject(project) }; loadProjects() }
}
