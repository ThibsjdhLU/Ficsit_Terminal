//
//  HapticManager.swift
//  FICSIT_Terminal
//
//  Created by Thibault Leray-Beer on 30/11/2025.
//


import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedbackLight = UIImpactFeedbackGenerator(style: .light)
    private let impactFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactFeedbackHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Clic léger (Boutons, Toggles)
    func click() {
        impactFeedbackLight.impactOccurred()
    }
    
    // Validation (Checklist)
    func success() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    // Grosse action (Calcul, Save)
    func thud() {
        impactFeedbackHeavy.impactOccurred()
    }
    
    // Erreur / Alerte (Overload)
    func error() {
        notificationFeedback.notificationOccurred(.error)
    }
}