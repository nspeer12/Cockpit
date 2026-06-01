import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            HolographicView()

            VStack {
                // Top bar
                HStack {
                    Text("COCKPIT")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.leading, 40)

                    Spacer()

                    RemoteModelsStatusView()
                        .frame(width: 280)
                        .padding(.trailing, 40)
                }
                .padding(.top, 30)

                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}