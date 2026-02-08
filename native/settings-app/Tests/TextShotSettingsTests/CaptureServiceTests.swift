import Testing
@testable import TextShotSettings

@Test
func captureFailureExitCodeOneIsCancellation() {
    let service = CaptureService()
    let result = service.resultForFailure(terminationStatus: 1, stderr: "")

    #expect(result.canceled)
    #expect(result.path == nil)
    #expect(result.error == nil)
    #expect(result.failureReason == nil)
}

@Test
func captureFailureMapsPermissionDeniedFromStderr() {
    let reason = CaptureService.classifyFailure(
        terminationStatus: 2,
        stderr: "Screen Recording permission denied."
    )

    #expect(reason == .permissionDenied)
}

@Test
func captureFailureMapsGenericToolError() {
    let reason = CaptureService.classifyFailure(
        terminationStatus: 2,
        stderr: "screencapture: failed to create image"
    )

    #expect(reason == .toolFailed(message: "screencapture: failed to create image"))
}
