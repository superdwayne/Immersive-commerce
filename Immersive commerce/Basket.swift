import Foundation
import Combine

class Basket: ObservableObject {
    @Published var items: [Model] = []

    func addItem(_ model: Model) {
        items.append(model)
    }
}

