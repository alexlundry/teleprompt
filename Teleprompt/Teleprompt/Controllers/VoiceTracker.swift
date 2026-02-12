import Foundation
import Speech
import AVFoundation
import AVFAudio
import Combine

class VoiceTracker: ObservableObject {
    @Published var currentWordIndex: Int = 0
    @Published var isListening: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var micPermissionGranted: Bool = false
    @Published var errorMessage: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Script data
    private var scriptWords: [String] = []
    private var scriptJoined: String = ""
    private var scriptWordBoundaries: [Int] = []  // char offset of each word in scriptJoined

    // Matching state
    private var confirmedWordIndex: Int = 0
    private var tentativeWordIndex: Int = 0
    private var previousTranscription: [String] = []
    private var pendingLargeJump: Int? = nil
    private var largeJumpConfirmations: Int = 0

    // Tuning parameters
    private let phraseMatchLength = 6
    private let forwardWindowWords = 30
    private let maxJumpPerUpdate = 10
    private let largeJumpConfirmThreshold = 3
    private let maxDistanceRatio: Double = 0.4
    private let minConfidenceThreshold: Float = 0.5
    private let lookAheadWords = 4  // offset to compensate for recognition latency

    private static let fillerWords: Set<String> = [
        "um", "uh", "like", "so", "actually", "basically", "right", "well", "okay", "hmm", "ah", "er"
    ]
    // Bigram fillers checked separately
    private static let fillerBigrams: Set<String> = [
        "you know"
    ]

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        checkPermissions()
    }

    // MARK: - Permissions

    func checkPermissions() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        micPermissionGranted = AVAudioApplication.shared.recordPermission == .granted
        print("[VoiceTracker] Permissions — speech: \(authorizationStatus.rawValue), mic: \(micPermissionGranted)")
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        var speechGranted = false
        var micGranted = false
        let group = DispatchGroup()

        group.enter()
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                speechGranted = (status == .authorized)
                print("[VoiceTracker] Speech authorization: \(status.rawValue)")
                group.leave()
            }
        }

        group.enter()
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.micPermissionGranted = granted
                micGranted = granted
                print("[VoiceTracker] Mic permission: \(granted)")
                group.leave()
            }
        }

        group.notify(queue: .main) {
            print("[VoiceTracker] All permissions — speech: \(speechGranted), mic: \(micGranted)")
            completion(speechGranted && micGranted)
        }
    }

    var hasAllPermissions: Bool {
        authorizationStatus == .authorized && micPermissionGranted
    }

    // MARK: - Script Preparation

    func prepareScript(_ scriptContent: String) {
        scriptWords = tokenizeScript(scriptContent)
        confirmedWordIndex = 0
        tentativeWordIndex = 0
        previousTranscription = []
        pendingLargeJump = nil
        largeJumpConfirmations = 0

        // Build joined string and word boundaries for efficient substring extraction
        var joined = ""
        var boundaries: [Int] = []
        for (i, word) in scriptWords.enumerated() {
            boundaries.append(joined.count)
            joined += word
            if i < scriptWords.count - 1 {
                joined += " "
            }
        }
        scriptJoined = joined
        scriptWordBoundaries = boundaries

        print("[VoiceTracker] Prepared script with \(scriptWords.count) words")
        DispatchQueue.main.async {
            self.currentWordIndex = 0
        }
    }

    private func tokenizeScript(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { normalizeWord($0) }
    }

    private func normalizeWord(_ word: String) -> String {
        word.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
    }

    // MARK: - Start / Stop Listening

    func startListening() {
        guard let speechRecognizer = speechRecognizer else {
            let msg = "Speech recognizer could not be created"
            print("[VoiceTracker] ERROR: \(msg)")
            DispatchQueue.main.async { self.errorMessage = msg }
            return
        }

        guard speechRecognizer.isAvailable else {
            let msg = "Speech recognition is not available on this device"
            print("[VoiceTracker] ERROR: \(msg)")
            DispatchQueue.main.async { self.errorMessage = msg }
            return
        }

        // Re-check permissions right before starting
        checkPermissions()

        if !hasAllPermissions {
            let msg = "Missing permissions — speech: \(authorizationStatus == .authorized), mic: \(micPermissionGranted)"
            print("[VoiceTracker] WARNING: \(msg) — attempting to start anyway")
        }

        guard !isListening else { return }

        // Cancel any previous task
        stopListening()

        print("[VoiceTracker] Starting audio engine and recognition...")
        startRecognitionSession(speechRecognizer: speechRecognizer, isInitial: true)
    }

    private func startRecognitionSession(speechRecognizer: SFSpeechRecognizer, isInitial: Bool) {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("[VoiceTracker] ERROR: Failed to create recognition request")
            DispatchQueue.main.async { self.errorMessage = "Failed to create recognition request" }
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Try on-device first, fall back to server-based if unavailable
        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
            print("[VoiceTracker] Using on-device recognition")
        } else {
            recognitionRequest.requiresOnDeviceRecognition = false
            print("[VoiceTracker] On-device not available, using server-based recognition")
        }

        // Feed script words as contextual strings to bias recognition
        if !scriptWords.isEmpty {
            let uniqueWords = Array(Set(scriptWords.prefix(1000)))
            recognitionRequest.contextualStrings = uniqueWords
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.processRecognitionResult(result)
            }

            if let error = error {
                let nsError = error as NSError
                print("[VoiceTracker] Recognition callback error: \(nsError.domain) code=\(nsError.code) — \(error.localizedDescription)")

                // Code 216 = canceled, 1110 = no speech detected — both normal, restart
                if nsError.domain == "kAFAssistantErrorDomain" && (nsError.code == 216 || nsError.code == 1110) {
                    if self.isListening {
                        self.restartRecognition()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.stopListening()
                    }
                }
            }
        }

        // Install audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("[VoiceTracker] Audio format: \(recordingFormat)")

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("[VoiceTracker] Audio engine started successfully")
            DispatchQueue.main.async {
                self.isListening = true
                self.errorMessage = nil
            }
        } catch {
            let msg = "Audio engine failed to start: \(error.localizedDescription)"
            print("[VoiceTracker] ERROR: \(msg)")
            DispatchQueue.main.async {
                self.errorMessage = msg
                self.isListening = false
            }
        }
    }

    func stopListening() {
        print("[VoiceTracker] Stopping...")
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    private func restartRecognition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isListening else { return }
            print("[VoiceTracker] Restarting recognition session...")

            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest?.endAudio()
            self.recognitionRequest = nil
            self.audioEngine.inputNode.removeTap(onBus: 0)
            if self.audioEngine.isRunning {
                self.audioEngine.stop()
            }

            // Reset transcription state for new session
            self.previousTranscription = []
            self.pendingLargeJump = nil
            self.largeJumpConfirmations = 0

            if let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable {
                self.startRecognitionSession(speechRecognizer: speechRecognizer, isInitial: false)
            }
        }
    }

    // MARK: - Phrase Matching Algorithm

    private func processRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let segments = result.bestTranscription.segments

        // Step 1: Filter by confidence and normalize
        let filteredWords = segments.compactMap { segment -> String? in
            // confidence == 0 means not computed (on-device), so accept it
            if segment.confidence > 0 && segment.confidence < minConfidenceThreshold {
                return nil
            }
            return normalizeWord(segment.substring)
        }

        // Step 2: Strip filler words
        let cleanWords = filterFillerWords(filteredWords)

        guard !cleanWords.isEmpty else { return }

        // Step 3: Detect stable prefix
        let stableCount = computeStablePrefixLength(previous: previousTranscription, current: cleanWords)
        previousTranscription = cleanWords

        // Need enough stable words to form a phrase
        guard stableCount >= 2 else { return }

        // Step 4: Build match phrase from last N stable words
        let phraseEnd = stableCount
        let phraseStart = max(0, phraseEnd - phraseMatchLength)
        let matchPhrase = Array(cleanWords[phraseStart..<phraseEnd])

        guard matchPhrase.count >= 2 else { return }

        // Step 5: Find best match in script
        let searchFrom = confirmedWordIndex
        if let matchEndIndex = findBestPhraseMatch(phrase: matchPhrase, searchFrom: searchFrom) {
            let candidateIndex = matchEndIndex

            // Step 6: Forward-only constraint
            guard candidateIndex >= confirmedWordIndex else { return }

            let jump = candidateIndex - confirmedWordIndex

            // Step 7: Jump limiting
            if jump <= maxJumpPerUpdate {
                // Small jump — accept immediately
                confirmedWordIndex = candidateIndex
                pendingLargeJump = nil
                largeJumpConfirmations = 0

                // Apply look-ahead to compensate for recognition latency
                let displayIndex = min(candidateIndex + lookAheadWords, scriptWords.count - 1)
                print("[VoiceTracker] Matched at word \(candidateIndex), display at \(displayIndex) (jump=\(jump))")
                DispatchQueue.main.async {
                    self.currentWordIndex = displayIndex
                }
            } else {
                // Large jump — require consecutive confirmations
                if pendingLargeJump == candidateIndex || (pendingLargeJump != nil && abs(candidateIndex - pendingLargeJump!) <= 3) {
                    largeJumpConfirmations += 1
                    print("[VoiceTracker] Large jump confirmation \(largeJumpConfirmations)/\(largeJumpConfirmThreshold) to word \(candidateIndex)")

                    if largeJumpConfirmations >= largeJumpConfirmThreshold {
                        confirmedWordIndex = candidateIndex
                        pendingLargeJump = nil
                        largeJumpConfirmations = 0

                        let displayIndex = min(candidateIndex + lookAheadWords, scriptWords.count - 1)
                        print("[VoiceTracker] Large jump confirmed to word \(candidateIndex), display at \(displayIndex)")
                        DispatchQueue.main.async {
                            self.currentWordIndex = displayIndex
                        }
                    }
                } else {
                    // New large jump target — start confirmation counter
                    pendingLargeJump = candidateIndex
                    largeJumpConfirmations = 1
                    print("[VoiceTracker] Large jump pending to word \(candidateIndex) (jump=\(jump))")
                }
            }
        }
    }

    private func computeStablePrefixLength(previous: [String], current: [String]) -> Int {
        // Find how many words from the start of `current` match `previous`
        // These words are "stable" — the recognizer hasn't revised them
        let minCount = min(previous.count, current.count)
        var stableCount = 0
        for i in 0..<minCount {
            if previous[i] == current[i] {
                stableCount = i + 1
            } else {
                break
            }
        }
        // If current is longer than previous and all of previous matched,
        // the new words at the end are also considered stable-ish
        // But we only trust the prefix that hasn't been revised
        return stableCount
    }

    private func findBestPhraseMatch(phrase: [String], searchFrom: Int) -> Int? {
        guard !phrase.isEmpty, !scriptWords.isEmpty else { return nil }

        let phraseString = phrase.joined(separator: " ")
        let phraseWordCount = phrase.count

        let searchEnd = min(searchFrom + forwardWindowWords, scriptWords.count)
        guard searchFrom < searchEnd else { return nil }

        var bestMatchEndIndex: Int? = nil
        var bestScore = Double.greatestFiniteMagnitude
        let maxAcceptableDistance = Int(Double(phraseString.count) * maxDistanceRatio)

        // Slide across the script window, trying substrings of varying word counts
        let minWords = max(1, phraseWordCount - 2)
        let maxWords = phraseWordCount + 2

        for startWord in searchFrom..<searchEnd {
            for wordCount in minWords...maxWords {
                let endWord = startWord + wordCount
                guard endWord <= scriptWords.count else { continue }
                guard endWord <= searchEnd + maxWords else { continue }

                // Build candidate substring from script words
                let candidateWords = scriptWords[startWord..<endWord]
                let candidateString = candidateWords.joined(separator: " ")

                let distance = levenshteinDistance(phraseString, candidateString)

                guard distance <= maxAcceptableDistance else { continue }

                // Score combines edit distance with a proximity penalty:
                // each word of distance from the cursor adds 0.3 to the score,
                // so nearby matches are strongly preferred.
                let proximityPenalty = Double(startWord - searchFrom) * 0.3
                let score = Double(distance) + proximityPenalty

                if score < bestScore {
                    bestScore = score
                    bestMatchEndIndex = endWord - 1
                }
            }
        }

        return bestMatchEndIndex
    }

    private func filterFillerWords(_ words: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < words.count {
            // Check bigram fillers
            if i + 1 < words.count {
                let bigram = words[i] + " " + words[i + 1]
                if VoiceTracker.fillerBigrams.contains(bigram) {
                    i += 2
                    continue
                }
            }
            // Check single-word fillers
            if !VoiceTracker.fillerWords.contains(words[i]) {
                result.append(words[i])
            }
            i += 1
        }
        return result
    }

    // MARK: - Levenshtein Distance

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var previousRow = Array(0...n)
        var currentRow = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            currentRow[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }
            previousRow = currentRow
        }

        return currentRow[n]
    }

    // MARK: - Position Sync

    /// Called when the user manually scrolls — resets tracking state to resume
    /// from the given word index instead of snapping back to the old position.
    func syncPosition(to wordIndex: Int) {
        confirmedWordIndex = max(0, wordIndex)
        tentativeWordIndex = confirmedWordIndex
        // Reset transcription state so the stable prefix starts fresh;
        // this prevents stale phrases from immediately re-matching the old position.
        previousTranscription = []
        pendingLargeJump = nil
        largeJumpConfirmations = 0
        print("[VoiceTracker] Position synced to word \(confirmedWordIndex)")
    }

    // MARK: - Reset

    func reset() {
        confirmedWordIndex = 0
        tentativeWordIndex = 0
        previousTranscription = []
        pendingLargeJump = nil
        largeJumpConfirmations = 0
        DispatchQueue.main.async {
            self.currentWordIndex = 0
        }
    }
}
