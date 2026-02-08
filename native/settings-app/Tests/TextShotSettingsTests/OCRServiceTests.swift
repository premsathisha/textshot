import Testing
@testable import TextShotSettings

@Test
func ocrCleanupTrimsWhitespaceAndExcessNewlines() {
    let service = OCRService()
    let input = "Hello   \n\n\nWorld   \n"
    #expect(service.cleanupOcrText(input) == "Hello\n\nWorld")
}

@Test
func ocrCleanupDropsPunctuationArtifacts() {
    let service = OCRService()
    let input = "Actual\n....\n|\nText"
    #expect(service.cleanupOcrText(input) == "Actual\nText")
}
