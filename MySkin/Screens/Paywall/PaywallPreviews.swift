import SwiftUI

// Previews live apart from the views: the preview thunk of PaywallContent.swift fails
// with "ambiguous use of __designTimeSelection" (same as OnboardingFlow).
#if DEBUG
#Preview("Hard paywall") {
    @Previewable @State var selected = PaywallPlan.preselected
    PaywallContent(options: PreviewData.paywallOptions, selected: $selected)
        .previewSetup()
}

#Preview("With close · weekly") {
    @Previewable @State var selected = PaywallPlan.weekly
    PaywallContent(options: PreviewData.paywallOptions, selected: $selected, onClose: {})
        .previewSetup()
}
#endif
