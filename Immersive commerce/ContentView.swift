//
//  ContentView.swift
//  Immersive Commerce
//
//  Created by Dwayne Paisley-Marshall on 17/10/2024.
//

import SwiftUI
import RealityKit
import Combine
import ARKit

// Model structure to decode JSON response from API
struct Model: Codable, Identifiable {
    let id = UUID()
    let name: String
    let usdzUrl: String  // Change from "url" to "fileName"
}

// ViewModel to fetch models and update state
class ModelViewModel: ObservableObject {
    @Published var models: [Model] = []

    init() {
        fetchModels()
    }

    // Function to fetch models from the Vercel API
    func fetchModels() {
        guard let url = URL(string: "https://immersive-commerce.vercel.app/api/models") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to fetch models:", error?.localizedDescription ?? "Unknown error")
                return
            }

            do {
                let models = try JSONDecoder().decode([Model].self, from: data)
                DispatchQueue.main.async {
                    self.models = models
                }
            } catch {
                print("Failed to decode models:", error)
            }
        }.resume()
    }
}

struct ContentView: View {
    @State private var selectedModelName: String?

    var body: some View {
        ZStack {
            NavigationView {
                DashboardView(selectedModelName: $selectedModelName)
            }
            
            if let modelName = selectedModelName {
                ProductDetailView(productName: modelName, productDescription: "Sustainable materials")
                    .background(Color.clear)
                    .onTapGesture {
                        selectedModelName = nil // Dismiss the view when tapped
                    }
            }
        }
        .onDisappear {
            selectedModelName = nil // Reset when the view disappears
        }
    }
}

struct ModelName: Identifiable {
    let id = UUID()
    let name: String
}

struct DashboardView: View {
    @StateObject private var viewModel = ModelViewModel()
    @Binding var selectedModelName: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                headerView
                
                sectionTitle("Top VTO Picks")
                
                horizontalScrollView
                
                sectionTitle("Your Personal Curated Selection Awaits")
                
                arNavigationLink
                
                recentActivitySection
            }
            .padding()
        }
        .navigationBarHidden(true)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.green)
            
            VStack(alignment: .leading) {
                Text("Hi, DPM!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Good to see you again")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
    
    private var horizontalScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(viewModel.models) { model in
                    NavigationLink(destination: ProductDetailView(productName: model.name, productDescription: "Sustainable materials")) {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image("shoe_thumbnail") // Ensure this image exists
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var arNavigationLink: some View {
        NavigationLink(destination: ARViewContainer(selectedModelName: $selectedModelName).edgesIgnoringSafeArea(.all)
            .onDisappear {
                selectedModelName = nil // Reset when navigating back
            }
        ) {
            Text("View your items in AR")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(1...3, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                    Text("Viewed item in AR")
                    Spacer()
                    Text("2h ago")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct ARViewContainer: UIViewControllerRepresentable {
    @Binding var selectedModelName: String?

    func makeUIViewController(context: Context) -> ARViewController {
        let viewController = ARViewController()
        viewController.onModelTapped = { modelName in
            selectedModelName = modelName
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: ARViewContainer

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
    }
}

class ARViewController: UIViewController {
    var arView: ARView!
    let assetNames = ["dior", "gucci", "fila", "goose"]
    var onModelTapped: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

        loadModels()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
    }

    func loadModels() {
        let spacing: Float = 0.5
        let rows = 3
        let columns = 3

        for (index, assetName) in assetNames.enumerated() {
            let modelName = "\(assetName).usdz"
            guard let modelEntity = try? ModelEntity.loadModel(named: modelName) else {
                print("Failed to load model: \(modelName)")
                continue
            }

            modelEntity.name = modelName // Set the name for later identification
            modelEntity.scale = SIMD3<Float>(0.5, 0.5, 0.5)

            // Add collision component for hit detection
            modelEntity.generateCollisionShapes(recursive: true)

            let row = index / columns
            let column = index % columns
            let xPosition = Float(column) * spacing - (Float(columns) * spacing) / 2 + spacing / 2
            let zPosition = Float(row) * spacing - (Float(rows) * spacing) / 2 + spacing / 2

            let anchor = AnchorEntity(plane: .horizontal)
            modelEntity.position = SIMD3<Float>(xPosition, 0, zPosition)
            anchor.addChild(modelEntity)

            arView.scene.addAnchor(anchor)
        }
    }

    @objc func handleTap(gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)

        if let tappedEntity = arView.entity(at: location) as? ModelEntity {
            print("Tapped on model: \(tappedEntity.name)")
            moveToCameraFocalPoint(entity: tappedEntity)
            
            // Extract the model name from the entity name (remove the .usdz extension)
            let modelName = tappedEntity.name.replacingOccurrences(of: ".usdz", with: "")
            
            // Call the onModelTapped closure to show the ProductDetailView
            onModelTapped?(modelName)
        } else {
            print("No model entity was tapped.")
        }
    }

    func moveToCameraFocalPoint(entity: ModelEntity) {
        // Get the current camera transform (position and rotation)
        let cameraTransform = arView.cameraTransform

        // Calculate the new position 1 meter in front of the camera
        let cameraForward = cameraTransform.matrix.columns.2
        let cameraPosition = cameraTransform.translation
        let newPosition = cameraPosition - SIMD3<Float>(cameraForward.x, cameraForward.y, cameraForward.z) * 1.0

        // Use the camera's rotation to align the entity to face the camera
        let lookAtCameraRotation = cameraTransform.rotation

        // Animate the entity's movement and rotation
        entity.move(to: Transform(scale: entity.transform.scale, rotation: lookAtCameraRotation, translation: newPosition), relativeTo: nil, duration: 0.5)
    }
}






#Preview {
    ContentView()
}



