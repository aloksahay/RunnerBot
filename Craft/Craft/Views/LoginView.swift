//
//  LoginView.swift
//  Craft
//
//  Created by Alok Sahay on 05.02.2025.
//

import SwiftUI
import BigInt
import Foundation
import web3

struct LoginView: View {
    @StateObject var vm: Web3AuthViewModel
    @State private var emailInput: String = ""
    
    var body: some View {
        // Main container
        ZStack {
            // Background layer
            Image("splash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            // Content layer
            VStack {
                Spacer() // Push content to bottom
                
                // Login form container
                VStack(spacing: 20) {
                    // Title and description
                    VStack(spacing: 12) {
                        Text("Addy for your ADD")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.horizontal, 40)
                        
                        Text("Let Addy manage your tasks for you and block out the distractions to help you achieve your daily goals.")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                    
                    // Email field
                    TextField("Enter your email", text: $emailInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .frame(height: 50)
                    
                    // Login button
                    Button(action: {
                        vm.loginEmailPasswordless(provider: .EMAIL_PASSWORDLESS, email: emailInput)
                    }) {
                        Text("Login")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            
            // Loading overlay
            if vm.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}


struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = Web3AuthViewModel()
        
        // Initialize preview environment
        return Group {
            LoginView(vm: mockViewModel)
                .onAppear {
                    Task {
                        await mockViewModel.setup()
                    }
                }
                .previewDisplayName("Login Screen")
        }
    }
}
