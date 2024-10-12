//
//  ContentView.swift
//  Cards
//
//  Created by Julien Coquet on [Date].
//

import SwiftUI
import UIKit

struct ContentView: View {

    @Environment(\.managedObjectContext) var moc
    @StateObject var model = CardsListViewModel()
    @FetchRequest(sortDescriptors: [SortDescriptor(\.creationDate)]) var cards: FetchedResults<Card>

    @State private var showAdd: Bool = false
    @State private var showStats: Bool = false
    @State private var showHint: Bool = true
    @State private var showSettings: Bool = false

    @State private var frontText: String = ""
    @State private var backText: String = ""

    @AppStorage("leftOptionIcon") var leftOptionIcon: String = "hand.thumbsdown.circle"
    @AppStorage("leftOptionTitle") var leftOptionTitle: String = "Forgot"

    @AppStorage("rightOptionIcon") var rightOptionIcon: String = "hand.thumbsup.circle"
    @AppStorage("rightOptionTitle") var rightOptionTitle: String = "Knew"

    // State variables for image selection and processing
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    
    @State private var isShowingImageEditor = false


    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                #if os(macOS)
                VisualEffectBlur(
                    material: .popover,
                    blendingMode: .behindWindow
                )
                .edgesIgnoringSafeArea(.all)
                #elseif os(iOS)
                Color.background
                    .edgesIgnoringSafeArea(.all)
                #endif

                content
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // Add Card button
                    Button(action: { showAdd.toggle() }) {
                        Image(systemName: "plus")
                            .font(.title3) // Slightly smaller for sleek look
                            .foregroundColor(.white)
                    }

                    // Camera button next to the + button
                    Button(action: {
                        isShowingCamera = true
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.title3) // Slightly smaller
                            .foregroundColor(.white)
                    }

                    // Photo Library button next to the + button
                    Button(action: {
                        isShowingImagePicker = true
                    }) {
                        Image(systemName: "photo.fill")
                            .font(.title3) // Slightly smaller
                            .foregroundColor(.white)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Reloading Cards
                    Button(action: reload) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3) // Slightly smaller for consistency
                            .foregroundColor(.white)
                    }

                    // Show Stats of Cards
                    Button(action: {
                        showStats.toggle()
                    }) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title3) // Slightly smaller for consistency
                            .foregroundColor(.white)
                    }

                    // Settings
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                            .font(.title3) // Slightly smaller for consistency
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddCardView(
                    frontText: $frontText,
                    backText: $backText,
                    saveAction: addCard
                )
            }
            .sheet(isPresented: $showStats) {
                StatsView()
                    .environmentObject(model)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    #if os(macOS)
                    .frame(minWidth: 350, minHeight: 450)
                    #endif
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraCaptureView(capturedImage: $selectedImage)
            }
            .sheet(isPresented: $isShowingImageEditor) {
                ImageEditorView(image: $selectedImage)
                    .onDisappear {
                        if let editedImage = selectedImage {
                            // Proceed with LLM processing
                            LLMClient.shared.processImage(editedImage) { flashcards in
                                if let flashcards = flashcards {
                                    DispatchQueue.main.async {
                                        saveFlashcards(flashcards)
                                    }
                                } else {
                                    print("Failed to process image with LLMClient.")
                                }
                            }
                        }
                    }
            }

            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NewCard"))) { _ in
                showAdd.toggle()
            }
        }
        .onChange(of: selectedImage) { image in
            if let image = image {
                // Present the Image Editor
                self.isShowingImageEditor = true
            }
        }
    }

    var content: some View {
        ZStack {
            // Base content
            ZStack {
                // Empty State
                if cards.isEmpty {
                    ContentUnavailableView(
                        "Cards list is empty, add cards!",
                        systemImage: "rectangle.stack.fill.badge.plus"
                    )
                } else {
                    ContentUnavailableView(
                        "Finally, the list is empty. You can check the stats or reload cards.",
                        systemImage: "app.badge.checkmark.fill"
                    )
                }

                // Cards
                CardStack(
                    direction: LeftRight.direction,
                    data: cards.reversed(),
                    id: \.id
                ) { card, direction in
                    switch direction {
                    case .left:
                        model.addForgotCard(card)
                    case .right:
                        model.addKnewCard(card)
                    }
                } content: { card, direction, isOnTop in
                    CardContentView(
                        frontText: card.front ?? "",
                        backText: card.back ?? "",
                        direction: direction,
                        deleteAction: { removeCard(card) }
                    )
                }
                .id(model.reloadToken)
                #if !os(visionOS)
                .sensoryFeedback(.levelChange, trigger: model.reloadToken)
                .sensoryFeedback(.success, trigger: model.knewCards)
                .sensoryFeedback(.error, trigger: model.forgotCards)
                #endif
            }
            .frame(maxWidth: 300, maxHeight: 400)
            .padding()

            // Hints
            HStack {
                if showHint {
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: leftOptionIcon)
                            .font(.title2)
                        Text("Swipe left for \(leftOptionTitle)")
                            .font(.callout)
                    }
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: rightOptionIcon)
                            .font(.title2)
                        Text("Swipe right for \(rightOptionTitle)")
                            .font(.callout)
                    }
                    Spacer()
                }
            }
            .foregroundStyle(.secondary)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding()
            .animation(.easeIn, value: showHint)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        self.showHint.toggle()
                    }
                }
            }
        }
    }

    func reload() {
        withAnimation {
            model.reloadToken = UUID()
            model.resetStats()
        }
    }

    func addCard() {
        let card = Card(context: moc)
        card.id = UUID()
        card.front = frontText
        card.back = backText
        card.creationDate = Date()

        try? moc.save()
        moc.refresh(card, mergeChanges: true)
        reload()
    }

    func removeCard(_ card: Card) {
        moc.delete(card)
        reload()
        try? moc.save()
    }

    func saveFlashcards(_ flashcards: [Flashcard]) {
        for flashcard in flashcards {
            let card = Card(context: moc)
            card.id = UUID()
            card.front = flashcard.front
            card.back = flashcard.back
            card.creationDate = Date()
        }
        try? moc.save()
        DispatchQueue.main.async {
            self.reload()
        }
    }
}

#Preview {
    @StateObject var dataController = DataController()

    return ContentView()
        .environment(\.managedObjectContext, dataController.container.viewContext)
}
