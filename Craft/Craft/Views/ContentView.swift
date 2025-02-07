//
//  ContentView.swift
//  Craft
//
//  Created by Alok Sahay on 05.02.2025.
//

import SwiftUI

//struct ContentView: View {
//    @StateObject var vm: ViewModel
//    @State private var showHandDetection = false
//    
//    var body: some View {
//        NavigationView {
//            VStack {
//                if vm.isLoading {
//                    ProgressView()
//                } else {
//                    if vm.loggedIn, let user = vm.user, let web3rpc = Web3RPC(user: user) {
//                        // Add a button to show HandDetectionView
//                        Button("Hand Detection") {
//                            showHandDetection = true
//                        }
//                        .sheet(isPresented: $showHandDetection) {
//                            HandDetectionView()
//                        }
//                    } else {
//                        LoginView(vm: vm)
//                    }
//                }
//                Spacer()
//            }
//        }
//        .onAppear {
//            Task {
//                await vm.setup()
//            }
//        }
//    }
//}
