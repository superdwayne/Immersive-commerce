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



struct DashboardView: View {
    @StateObject private var viewModel = ModelViewModel()
    @Binding var selectedModelName: String?
    @State private var isARViewActive = false

    var body: some View {
        ZStack {
            // Background Color
            Color.gray.opacity(0.1)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                headerView
                
                Spacer()
                
                mainCardView
                
                Spacer()
              
            }
            .padding()
        }
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: ARViewWithOverlay(selectedModelName: $selectedModelName)
                    .edgesIgnoringSafeArea(.all),
                isActive: $isARViewActive,
                label: { EmptyView() }
            )
        )
    }
    
    private var headerView: some View {
        HStack {
            Text("Today's personalised items")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var mainCardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("product_image") // Replace with your product image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 300)
                .clipped()
                .cornerRadius(20)
            
            Button(action: {
                isARViewActive = true
            }) {
                Text("View your items in AR")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding(.horizontal)
    }
    
}

struct ARViewContainer: UIViewControllerRepresentable {
    @Binding var selectedModelName: String?
    var shouldLoadModels: Bool

    func makeUIViewController(context: Context) -> ARViewController {
        let viewController = ARViewController()
        viewController.onModelTapped = { modelEntity in
            selectedModelName = modelEntity.name
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        if shouldLoadModels {
            uiViewController.loadModels()
        }
    }

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
    var onModelTapped: ((ModelEntity) -> Void)?
    private var focusedEntity: ModelEntity?
    private var originalPositions: [ModelEntity: SIMD3<Float>] = [:]
    private let assetNames = ["dior", "gucci", "fila", "goose"]
    private var modelsLoaded = false  // Add this line

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
    }

    private func setupARView() {
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
    }

    func loadModels() {
        guard !modelsLoaded else { return }  // Add this line

        let radius: Float = 0.5
        let modelScale: Float = 0.5
        let initialYOffset: Float = -0.5
        let centerZOffset: Float = -2.0
        let angleIncrement = (2 * .pi) / Float(assetNames.count)

        for (index, assetName) in assetNames.enumerated() {
            let modelName = "\(assetName).usdz"
            guard let modelEntity = try? ModelEntity.loadModel(named: modelName) else {
                print("Failed to load model: \(modelName)")
                continue
            }

            modelEntity.name = modelName
            modelEntity.scale = SIMD3<Float>(repeating: modelScale)
            modelEntity.generateCollisionShapes(recursive: true)

            let angle = angleIncrement * Float(index)
            let xPosition = radius * cos(angle)
            let zPosition = centerZOffset + radius * sin(angle)
            let position = SIMD3<Float>(xPosition, initialYOffset, zPosition)

            let anchor = AnchorEntity(world: position)
            anchor.addChild(modelEntity)
            arView.scene.addAnchor(anchor)
            originalPositions[modelEntity] = modelEntity.position(relativeTo: nil)
        }
        modelsLoaded = true  // Add this line
        print("Models loaded")
    }

    @objc func handleTap(gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)

        if let tappedEntity = arView.entity(at: location) as? ModelEntity {
            if let currentFocusedEntity = focusedEntity, currentFocusedEntity != tappedEntity {
                resetEntityPosition(entity: currentFocusedEntity)
            }

            if tappedEntity == focusedEntity {
                resetEntityPosition(entity: tappedEntity)
                focusedEntity = nil
            } else {
                moveToCameraFocalPoint(entity: tappedEntity)
                focusedEntity = tappedEntity
            }
            onModelTapped?(tappedEntity)
        }
    }

    func moveToCameraFocalPoint(entity: ModelEntity) {
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        let cameraForward = normalize(SIMD3<Float>(cameraTransform.matrix.columns.2.x, cameraTransform.matrix.columns.2.y, cameraTransform.matrix.columns.2.z))
        
        let distanceInFrontOfCamera: Float = 0.5
        let positionInFrontOfCamera = cameraPosition - (cameraForward * distanceInFrontOfCamera)
        
        let yOffset: Float = -0.3
        let newPosition = SIMD3<Float>(
            positionInFrontOfCamera.x,
            cameraPosition.y + yOffset,
            positionInFrontOfCamera.z
        )
        
        let entityToCamera = normalize(cameraPosition - newPosition)
        let rotationAngle = atan2(entityToCamera.x, entityToCamera.z)
        let newRotation = simd_quatf(angle: rotationAngle, axis: SIMD3<Float>(0, 1, 0))

        entity.move(to: Transform(scale: entity.transform.scale, rotation: newRotation, translation: newPosition), relativeTo: nil, duration: 0.5)
    }

    func resetEntityPosition(entity: ModelEntity) {
        if let originalPosition = originalPositions[entity] {
            entity.move(to: Transform(scale: entity.transform.scale, translation: originalPosition), relativeTo: nil, duration: 0.5)
        }
    }
}

struct ARViewWithOverlay: View {
    @Binding var selectedModelName: String?
    @State private var showOverlay = true
    @State private var shouldLoadModels = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            ARViewContainer(selectedModelName: $selectedModelName, shouldLoadModels: shouldLoadModels)
                .edgesIgnoringSafeArea(.all)

            if showOverlay {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack {
                            Text("Your personalised items - just for you. Tap each item and explore their details")
                                .font(.title)
                                .foregroundColor(.white)

                            Text("Tap to begin")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                        }
                    )
                    .onTapGesture {
                        showOverlay = false
                        shouldLoadModels = true
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
        .onAppear {
            // Reset selectedModelName as soon as this view appears
            selectedModelName = nil
        }
    }

    private var backButton: some View {
        Button(action: {
            selectedModelName = nil
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        }
    }
}






#Preview {
    ContentView()
}



