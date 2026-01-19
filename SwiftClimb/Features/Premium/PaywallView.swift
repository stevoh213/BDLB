import SwiftUI

@MainActor
struct PaywallView: View {
    @Environment(\.premiumService) private var premiumService
    @Environment(\.dismiss) private var dismiss

    @State private var products: [SubscriptionProduct] = []
    @State private var selectedProduct: SubscriptionProduct?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SCSpacing.xl) {
                    headerSection
                    featuresSection

                    if isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        pricingSection
                        purchaseButton
                    }

                    restoreButton
                    termsSection
                }
                .padding()
            }
            .navigationTitle("SwiftClimb Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadProducts()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: SCSpacing.sm) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Unlock Your Full Potential")
                .font(SCTypography.screenHeader)
                .multilineTextAlignment(.center)

            Text("Get the most out of your climbing with Premium")
                .font(SCTypography.body)
                .foregroundStyle(SCColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: SCSpacing.md) {
            PremiumFeatureRow(
                icon: "chart.xyaxis.line",
                title: "Advanced Insights",
                description: "Track progression, identify patterns, and optimize your training"
            )

            PremiumFeatureRow(
                icon: "clock.arrow.circlepath",
                title: "Complete History",
                description: "Access your entire climbing logbook, not just the last 30 days"
            )

            PremiumFeatureRow(
                icon: "map",
                title: "Outdoor Routes",
                description: "Search and sync climbs from OpenBeta's outdoor database"
            )
        }
        .padding()
        .background(SCColors.surfaceSecondary)
        .cornerRadius(SCCornerRadius.card)
    }

    @ViewBuilder
    private var pricingSection: some View {
        VStack(spacing: SCSpacing.sm) {
            ForEach(products) { product in
                PricingOptionCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    onSelect: { selectedProduct = product }
                )
            }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        SCPrimaryButton(
            title: isPurchasing ? "Processing..." : "Subscribe Now",
            action: { Task { await purchase() } },
            isLoading: isPurchasing,
            isFullWidth: true
        )
        .disabled(selectedProduct == nil || isPurchasing)
    }

    @ViewBuilder
    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await restorePurchases() }
        }
        .font(SCTypography.secondary)
        .foregroundStyle(SCColors.textSecondary)
    }

    @ViewBuilder
    private var termsSection: some View {
        VStack(spacing: SCSpacing.xs) {
            Text("Subscription renews automatically. Cancel anytime in Settings.")
                .font(SCTypography.metadata)
                .foregroundStyle(SCColors.textSecondary)

            HStack(spacing: SCSpacing.sm) {
                Link("Terms of Service", destination: URL(string: "https://swiftclimb.app/terms")!)
                Text("|")
                Link("Privacy Policy", destination: URL(string: "https://swiftclimb.app/privacy")!)
            }
            .font(SCTypography.metadata)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await premiumService?.fetchProducts() ?? []
            // Default to annual if available
            selectedProduct = products.first { $0.subscriptionPeriod == .annual }
                ?? products.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await premiumService?.purchase(product)
            switch result {
            case .success:
                dismiss()
            case .pending:
                errorMessage = "Purchase is pending approval"
            case .cancelled:
                break // User cancelled, no action needed
            case .failed(let error):
                errorMessage = error.localizedDescription
            case .none:
                errorMessage = "Premium service not available"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let status = try await premiumService?.restorePurchases()
            if status?.isPremium == true {
                dismiss()
            } else {
                errorMessage = "No active subscription found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting Views

private struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: SCSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: SCSpacing.xxs) {
                Text(title)
                    .font(SCTypography.body.weight(.semibold))

                Text(description)
                    .font(SCTypography.secondary)
                    .foregroundStyle(SCColors.textSecondary)
            }
        }
    }
}

private struct PricingOptionCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let onSelect: () -> Void

    private var savingsText: String? {
        if product.subscriptionPeriod == .annual {
            return "Save 17%"
        }
        return nil
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: SCSpacing.xxs) {
                    HStack {
                        Text(product.displayName)
                            .font(SCTypography.body.weight(.semibold))

                        if let savings = savingsText {
                            Text(savings)
                                .font(SCTypography.metadata)
                                .fontWeight(.medium)
                                .padding(.horizontal, SCSpacing.xs)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.2))
                                .foregroundStyle(.tint)
                                .cornerRadius(4)
                        }
                    }

                    Text(product.description)
                        .font(SCTypography.secondary)
                        .foregroundStyle(SCColors.textSecondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(SCTypography.body.weight(.semibold))

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : SCColors.textSecondary)
            }
            .padding()
            .background(isSelected ? SCColors.surfaceSecondary : .clear)
            .cornerRadius(SCCornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: SCCornerRadius.card)
                    .stroke(isSelected ? Color.accentColor : SCColors.textSecondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
