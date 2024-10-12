//
//  ImageEditorView.swift
//  Cards
//
//  Created by Julien Coquet on [Date].
//

import SwiftUI
import TOCropViewController

struct ImageEditorView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> TOCropViewController {
        let cropViewController = TOCropViewController(image: image ?? UIImage())
        cropViewController.delegate = context.coordinator
        cropViewController.aspectRatioLockEnabled = false
        return cropViewController
    }

    func updateUIViewController(_ uiViewController: TOCropViewController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, TOCropViewControllerDelegate {
        let parent: ImageEditorView

        init(_ parent: ImageEditorView) {
            self.parent = parent
        }

        func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        func cropViewController(_ cropViewController: TOCropViewController, didCrop image: UIImage, with cropRect: CGRect, angle: Int) {
            parent.image = image
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
