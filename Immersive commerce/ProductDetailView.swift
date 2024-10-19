import SwiftUI

struct ProductDetailView: View {
    var productName: String
    var productDescription: String

    var body: some View {
        VStack {
            Spacer()  // Pushes content to the bottom
            
            VStack {
                Text(productDescription)
                    .font(.subheadline)
                    .padding(.bottom, 2)
                
                Text(productName)
                    .font(.headline)
                    .padding(.bottom, 2)
                

                
                Button(action: {
                    // Add to basket action
                }) {
                    Text("Add to Basket")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding()
            .cornerRadius(12)
            .frame(maxWidth: 300)  // Control the width of the view
        }
        .background(Color.clear)
        .padding(.bottom, 40)
        .navigationBarTitleDisplayMode(.inline)
    }
}
