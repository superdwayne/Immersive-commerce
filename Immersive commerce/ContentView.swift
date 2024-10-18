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
    private var focusedEntity: ModelEntity?
    private var originalPositions: [ModelEntity: SIMD3<Float>] = [:]

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
        let modelScale: Float = 0.3
        let initialYOffset: Float = -0.5 // Adjust this to lower the initial position of models

        let totalWidth = Float(assetNames.count - 1) * spacing
        
        for (index, assetName) in assetNames.enumerated() {
            let modelName = "\(assetName).usdz"
            guard let modelEntity = try? ModelEntity.loadModel(named: modelName) else {
                print("Failed to load model: \(modelName)")
                continue
            }

            modelEntity.name = modelName
            modelEntity.scale = SIMD3<Float>(repeating: modelScale)
            modelEntity.generateCollisionShapes(recursive: true)

            let xPosition = Float(index) * spacing - totalWidth / 2
            let position = SIMD3<Float>(xPosition, initialYOffset, -1.5)

            let anchor = AnchorEntity(world: position)
            anchor.addChild(modelEntity)
            arView.scene.addAnchor(anchor)
            originalPositions[modelEntity] = modelEntity.position(relativeTo: nil)
        }
    }

    @objc func handleTap(gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)

        if let tappedEntity = arView.entity(at: location) as? ModelEntity {
            print("Tapped on model: \(tappedEntity.name)")

            // Check if the tapped entity is already the focused entity
            if tappedEntity != focusedEntity {
                // Reset the previously focused entity
                if let focusedEntity = focusedEntity {
                    resetEntityPosition(entity: focusedEntity)
                }

                // Move the new entity to the camera focal point
                moveToCameraFocalPoint(entity: tappedEntity)
                focusedEntity = tappedEntity

                let modelName = tappedEntity.name.replacingOccurrences(of: ".usdz", with: "")
                onModelTapped?(modelName)
            } else {
                print("Model is already in focus")
                // Optionally, you can update the product detail view here if needed
                // without moving the model again
                let modelName = tappedEntity.name.replacingOccurrences(of: ".usdz", with: "")
                onModelTapped?(modelName)
            }
        } else {
            print("No model entity was tapped.")
        }
    }

    func moveToCameraFocalPoint(entity: ModelEntity) {
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        let cameraForward = normalize(SIMD3<Float>(cameraTransform.matrix.columns.2.x, cameraTransform.matrix.columns.2.y, cameraTransform.matrix.columns.2.z))
        
        // Use a fixed distance from the camera
        let distanceInFrontOfCamera: Float = 1.0
        
        // Calculate position in front of the camera
        let positionInFrontOfCamera = cameraPosition - (cameraForward * distanceInFrontOfCamera)
        
        // Adjust Y-position to be lower in the camera view
        let yOffset: Float = -0.3 // Adjust this value as needed
        let newPosition = SIMD3<Float>(
            positionInFrontOfCamera.x,
            cameraPosition.y + yOffset,
            positionInFrontOfCamera.z
        )
        
        // Calculate rotation to face the camera, but only around the Y-axis
        let entityToCamera = normalize(cameraPosition - newPosition)
        let rotationAngle = atan2(entityToCamera.x, entityToCamera.z)
        let newRotation = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0))

        entity.move(to: Transform(scale: entity.transform.scale, rotation: newRotation, translation: newPosition), relativeTo: nil, duration: 0.5)
    }

    func resetEntityPosition(entity: ModelEntity) {
        if let originalPosition = originalPositions[entity] {
            entity.move(to: Transform(translation: originalPosition), relativeTo: nil, duration: 0.5)
        }
    }
}






#Preview {
    ContentView()
}



