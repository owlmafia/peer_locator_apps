import Foundation
import SwiftUI

struct RadarView: View {

    @ObservedObject private var viewModel: MeetingViewModel

    init(viewModel: MeetingViewModel) {
        self.viewModel = viewModel
    }

    @State var items: [RadarItem] = []

    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    ForEach(items, id: \.id) { item in
                        Text(item.text)
                            .position(
                                x: item.loc.x,
                                y: item.loc.y - 20
                            )
                    }
                    ForEach(items, id: \.id) { item in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .position(
                                x: item.loc.x,
                                y: item.loc.y
                            )

                    }
                }.frame(width: geometry.size.width, height: geometry.size.height).onReceive(viewModel.$radarItems) { items in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.items = items
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
