import Foundation
import Testing
@testable import MdMCore

@Test
func captureFeedbackKindPrefersClonedWhenCloneHappened() {
    let result = CaptureProcessResult(
        totalCandidates: 2,
        appendedCount: 1,
        attachmentCount: 0,
        clonedCount: 1,
        skippedCount: 1,
        duplicateCount: 1,
        errors: []
    )

    #expect(result.feedbackKind == .cloned)
}

@Test
func captureFeedbackKindUsesCapturedForRecognizedWithoutClone() {
    let result = CaptureProcessResult(
        totalCandidates: 1,
        appendedCount: 1,
        attachmentCount: 0,
        clonedCount: 0,
        skippedCount: 0,
        errors: []
    )

    #expect(result.feedbackKind == .captured)
}

@Test
func captureFeedbackKindUsesDuplicateWhenOnlyDuplicatesRemain() {
    let result = CaptureProcessResult(
        totalCandidates: 1,
        appendedCount: 0,
        attachmentCount: 0,
        clonedCount: 0,
        skippedCount: 1,
        duplicateCount: 1,
        errors: []
    )

    #expect(result.feedbackKind == .duplicate)
}

@Test
func captureFeedbackKindUsesBlockedWhenOnlyBlockedItemsRemain() {
    let result = CaptureProcessResult(
        totalCandidates: 1,
        appendedCount: 0,
        attachmentCount: 0,
        clonedCount: 0,
        skippedCount: 1,
        blockedCount: 1,
        errors: []
    )

    #expect(result.feedbackKind == .blocked)
}

@Test
func captureFeedbackKindUsesFailedWhenOnlyErrorsRemain() {
    let result = CaptureProcessResult(
        totalCandidates: 1,
        appendedCount: 0,
        attachmentCount: 0,
        clonedCount: 0,
        skippedCount: 0,
        errors: ["Clone failed"]
    )

    #expect(result.feedbackKind == .failed)
}

@Test
func captureFeedbackKindUsesFailedWhenAppendSucceededButFollowupActionFailed() {
    let result = CaptureProcessResult(
        totalCandidates: 1,
        appendedCount: 1,
        attachmentCount: 0,
        clonedCount: 0,
        skippedCount: 0,
        errors: ["Clone failed"]
    )

    #expect(result.feedbackKind == .failed)
}
